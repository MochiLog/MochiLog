import Foundation
import Network

/// The pairing protocol is newline framed. A valid response must not wait for
/// the peer to close its TCP connection. Never log payloads, PINs or keys.
@available(iOS 17, *)
enum PairingTransport {
  typealias Logger = @Sendable (String) -> Void

  nonisolated static func errorSummary(_ error: Error) -> String {
    if let transfer = error as? TransferError { return "reason=\(transfer)" }
    let value = error as NSError
    let domain = String(
      value.domain.filter { $0.isLetter || $0.isNumber || ".-_".contains($0) }.prefix(80))
    return "domain=\(domain), code=\(value.code)"
  }

  nonisolated static func exchange(
    routes: [NWEndpoint], payload: Data, allowCellular: Bool,
    continueOnInvalidResponse: Bool = false,
    context: String = "control", timeout: TimeInterval = 10,
    log: @escaping Logger = { _ in }
  ) async throws -> Data {
    let attempt = UUID().uuidString
    let started = ProcessInfo.processInfo.systemUptime
    log(
      "PC pairing: exchange started; attempt=\(attempt), stage=\(context), routes=\(routes.count), cellular=\(allowCellular)"
    )
    var lastError: Error = TransferError.invalidPairing
    for (index, route) in routes.enumerated() {
      try Task.checkCancellation()
      let prefix =
        "PC pairing: attempt=\(attempt), stage=\(context), route=\(index + 1)/\(routes.count)"
      do {
        let operation = Exchange(
          route: route, payload: payload, allowCellular: allowCellular,
          timeout: timeout, prefix: prefix, log: log)
        let reply = try await withTaskCancellationHandler {
          try await withCheckedThrowingContinuation { operation.start($0) }
        } onCancel: {
          operation.cancel()
        }
        log(
          "\(prefix); response framed; bytes=\(reply.count), elapsedMs=\(Int((ProcessInfo.processInfo.systemUptime - started) * 1000))"
        )
        return reply
      } catch is CancellationError {
        log("\(prefix); cancelled")
        throw CancellationError()
      } catch {
        log("\(prefix); failed; \(errorSummary(error))")
        if case TransferError.invalidPairing = error, !continueOnInvalidResponse { throw error }
        lastError = error
      }
    }
    log(
      "PC pairing: exchange exhausted; attempt=\(attempt), stage=\(context); \(errorSummary(lastError))"
    )
    throw lastError
  }

  private final class Exchange: @unchecked Sendable {
    private let queue = DispatchQueue(label: "net.ryuya-dev.MochiLog.pairing")
    private let route: NWEndpoint
    private let payload: Data
    private let allowCellular: Bool
    private let timeout: TimeInterval
    private let prefix: String
    private let log: Logger
    // All mutable state belongs to queue, including cancellation before start.
    private var continuation: CheckedContinuation<Data, Error>?
    private var cancelled = false
    private var connection: NWConnection?
    private var deadline: DispatchWorkItem?
    private var response = Data()
    private var phase = "connecting"

    init(
      route: NWEndpoint, payload: Data, allowCellular: Bool, timeout: TimeInterval,
      prefix: String, log: @escaping Logger
    ) {
      self.route = route
      self.payload = payload
      self.allowCellular = allowCellular
      self.timeout = timeout
      self.prefix = prefix
      self.log = log
    }

    func start(_ continuation: CheckedContinuation<Data, Error>) {
      queue.async { [self] in
        if self.cancelled {
          continuation.resume(throwing: CancellationError())
          return
        }
        self.continuation = continuation
        let parameters = NWParameters.tcp
        if !self.allowCellular { parameters.prohibitedInterfaceTypes = [.cellular] }
        let connection = NWConnection(to: self.route, using: parameters)
        self.connection = connection
        connection.pathUpdateHandler = { [weak self] path in
          guard let self, self.continuation != nil else { return }
          self.log(
            "\(self.prefix); path=\(path.status), wifi=\(path.usesInterfaceType(.wifi)), cellular=\(path.usesInterfaceType(.cellular)), unsatisfied=\(path.unsatisfiedReason)"
          )
        }
        connection.stateUpdateHandler = { [weak self] state in
          guard let self, self.continuation != nil else { return }
          switch state {
          case .ready:
            self.log("\(self.prefix); connected")
            self.phase = "sending"
            connection.send(
              content: self.payload + Data([10]),
              completion: .contentProcessed { [weak self] error in
                guard let self, self.continuation != nil else { return }
                if let error {
                  self.finish(.failure(error))
                  return
                }
                self.phase = "waiting-for-response"
                self.log("\(self.prefix); request sent")
                self.receive()
              })
          case .preparing: self.log("\(self.prefix); preparing")
          case .waiting(let error):
            self.log("\(self.prefix); waiting; \(PairingTransport.errorSummary(error))")
          case .failed(let error): self.finish(.failure(error))
          case .cancelled: self.finish(.failure(CancellationError()))
          default: break
          }
        }
        let deadline = DispatchWorkItem { [weak self] in
          guard let self, self.continuation != nil else { return }
          self.log(
            "\(self.prefix); timeout; phase=\(self.phase), receivedBytes=\(self.response.count)")
          self.finish(.failure(URLError(.timedOut)))
        }
        self.deadline = deadline
        self.queue.asyncAfter(deadline: .now() + self.timeout, execute: deadline)
        connection.start(queue: self.queue)
      }
    }

    func cancel() {
      queue.async {
        self.cancelled = true
        self.finish(.failure(CancellationError()))
      }
    }

    private func receive() {
      connection?.receive(minimumIncompleteLength: 1, maximumLength: 8192) {
        [weak self] data, _, complete, error in
        guard let self, self.continuation != nil else { return }
        if let data { self.response.append(data) }
        if let end = self.response.firstIndex(of: 10) {
          guard end <= 16_384 else {
            self.finish(.failure(TransferError.invalidPayload))
            return
          }
          self.finish(.success(Data(self.response[..<end])))
        } else if self.response.count > 16_384 {
          self.finish(.failure(TransferError.invalidPayload))
        } else if let error {
          self.finish(.failure(error))
        } else if complete {
          self.finish(.failure(TransferError.invalidPairing))
        } else {
          self.receive()
        }
      }
    }

    private func finish(_ result: Result<Data, Error>) {
      guard let continuation else { return }
      self.continuation = nil
      deadline?.cancel()
      deadline = nil
      connection?.stateUpdateHandler = nil
      connection?.pathUpdateHandler = nil
      connection?.cancel()
      connection = nil
      continuation.resume(with: result)
    }
  }
}
