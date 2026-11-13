import Foundation
import Network

enum TransferError: Error { case invalidPairing, invalidPayload }
final class Events: @unchecked Sendable {
  private let lock = NSLock()
  private var values: [String] = []
  func append(_ value: String) {
    lock.lock()
    defer { lock.unlock() }
    values.append(value)
  }
  var text: String {
    lock.lock()
    defer { lock.unlock() }
    return values.joined(separator: "\n")
  }
}
final class Peer: @unchecked Sendable {
  let listener: NWListener
  let queue = DispatchQueue(label: "pairing-test-peer")
  var clients: [NWConnection] = []
  init(parts: [Data]?, close: Bool = false) throws {
    listener = try NWListener(using: .tcp, on: .any)
    let ready = DispatchSemaphore(value: 0)
    listener.stateUpdateHandler = { state in if case .ready = state { ready.signal() } }
    listener.newConnectionHandler = { [weak self] connection in
      guard let self else { return }
      self.clients.append(connection)
      connection.stateUpdateHandler = { state in
        if case .ready = state {
          connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { _, _, _, _ in
            guard let parts else { return }
            for (i, part) in parts.enumerated() {
              self.queue.asyncAfter(deadline: .now() + Double(i) * 0.025) {
                connection.send(
                  content: part,
                  completion: .contentProcessed { _ in
                    if close && i == parts.count - 1 { connection.cancel() }
                  })
              }
            }
          }
        }
      }
      connection.start(queue: self.queue)
    }
    listener.start(queue: queue)
    precondition(ready.wait(timeout: .now() + 3) == .success)
  }
  var endpoint: NWEndpoint { .hostPort(host: "127.0.0.1", port: listener.port!) }
  func stop() {
    queue.sync {
      listener.cancel()
      clients.forEach { $0.cancel() }
    }
  }
}
@main struct Tests {
  static func main() async throws {
    let events = Events()
    let peer = try Peer(parts: [Data("{\"type\":".utf8), Data("\"pair-challenge\"}\n".utf8)])
    defer { peer.stop() }
    let start = Date()
    let response = try await PairingTransport.exchange(
      routes: [peer.endpoint],
      payload: Data("DO_NOT_LOG_PIN_123456_OR_PRIVATE_KEY".utf8), allowCellular: false,
      context: "prepare", timeout: 2, log: { events.append($0) })
    precondition(String(decoding: response, as: UTF8.self) == "{\"type\":\"pair-challenge\"}")
    precondition(Date().timeIntervalSince(start) < 1, "Complete newline frame waited for EOF")
    precondition(events.text.contains("connected") && events.text.contains("request sent"))
    precondition(!events.text.contains("123456") && !events.text.contains("PRIVATE_KEY"))
    let silent = try Peer(parts: nil)
    defer { silent.stop() }
    do {
      _ = try await PairingTransport.exchange(
        routes: [silent.endpoint], payload: Data("{}".utf8),
        allowCellular: false, timeout: 0.15, log: { events.append($0) })
      preconditionFailure("Silent peer did not time out")
    } catch { precondition((error as NSError).code == -1001) }
    precondition(events.text.contains("phase=waiting-for-response"))
    let task = Task {
      try await PairingTransport.exchange(
        routes: [silent.endpoint],
        payload: Data("{}".utf8), allowCellular: false, timeout: 10, log: { events.append($0) })
    }
    try await Task.sleep(for: .milliseconds(50))
    task.cancel()
    do {
      _ = try await task.value
      preconditionFailure("Cancellation ignored")
    } catch { precondition(error is CancellationError) }
    let fallback = try await PairingTransport.exchange(
      routes: [silent.endpoint, peer.endpoint],
      payload: Data("{}".utf8), allowCellular: false, timeout: 0.15, log: { events.append($0) })
    precondition(fallback == response && events.text.contains("route=2/2"))
    let truncated = try Peer(parts: [Data("{\"incomplete\":".utf8)], close: true)
    defer { truncated.stop() }
    do {
      _ = try await PairingTransport.exchange(
        routes: [truncated.endpoint], payload: Data("{}".utf8), allowCellular: false, timeout: 1)
      preconditionFailure("Truncated frame accepted")
    } catch { guard case TransferError.invalidPairing = error else { throw error } }
    let oversized = try Peer(parts: [Data(repeating: 65, count: 17_000)])
    defer { oversized.stop() }
    do {
      _ = try await PairingTransport.exchange(
        routes: [oversized.endpoint], payload: Data("{}".utf8), allowCellular: false, timeout: 1)
      preconditionFailure("Oversized response accepted")
    } catch { guard case TransferError.invalidPayload = error else { throw error } }
    print(
      "PASS: fragmented newline response without EOF, timeout phase, route fallback, cancellation, output bounds and secret-free logs"
    )
  }
}
