import Combine
import CryptoKit
import Foundation
import Network
import UIKit

struct LiveBatteryReading: Equatable {
  let values: [String: Int]
  let charging: Bool?
  let revision: String
  let acquiredAt: Date
}

/// Foreground-only, session-only current values. No record or iCloud writes.
@available(iOS 27, *)
@MainActor
final class LiveBatteryManager: ObservableObject {
  static let shared = LiveBatteryManager()
  @Published private(set) var readings: [UUID: LiveBatteryReading] = [:]
  @Published private(set) var states: [UUID: String] = [:]
  @Published private(set) var busy = false
  private var browser: NWBrowser?
  private var monitor: NWPathMonitor?
  private var discovered: [UUID: [NWEndpoint]] = [:]
  private var path: NWPath?
  private var task: Task<Void, Never>?
  private var active = false
  private var pairingObserver: AnyCancellable?
  var activePairings: [MacTransferPairing] {
    #if DEBUG
    if let text = ProcessInfo.processInfo.environment["MOCHI_LIVE_BATTERY_PORT"],
      let port = UInt16(text), port != 0 {
      return [MacTransferPairing(hostID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        physicalDeviceID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        model: "iPhone Test", secret: Data(repeating: 7, count: 32),
        lanAddresses: ["127.0.0.1"], lanPort: port, requiresSecureTransfer: true)]
    }
    #endif
    return MacTransferManager.shared.pairings
  }

  private init() {
    pairingObserver = MacTransferManager.shared.$pairings.sink { [weak self] pairings in
      Task { @MainActor in
        guard let self else { return }
        let hosts = Set(self.activePairings.map(\.hostID))
        self.readings = self.readings.filter { hosts.contains($0.key) }
        self.states = self.states.filter { hosts.contains($0.key) }
      }
    }
  }

  func updateActivity() {
    let shouldRun = AppSettings.shared.liveBatteryEnabled && !ProcessInfo.processInfo.isiOSAppOnMac
      && UIApplication.shared.connectedScenes.contains { $0.activationState == .foregroundActive }
    guard shouldRun != active else { return }
    if shouldRun { start() } else { stop() }
  }

  private func start() {
    active = true
    #if DEBUG
    if ProcessInfo.processInfo.environment["MOCHI_LIVE_BATTERY_TEST"] == "1" {
      // Synthetic display fixture, never a persisted pairing or battery record.
      let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
      readings[id] = LiveBatteryReading(values: ["CycleCount": 245, "DesignCapacity": 4000,
        "NominalChargeCapacity": 3820, "AppleRawMaxCapacity": 3850,
        "FullChargeCapacity": 3800, "CurrentCapacity": 67], charging: false,
        revision: String(repeating: "a", count: 64), acquiredAt: Date())
      states[id] = "current"
      return
    }
    #endif
    let parameters = NWParameters.tcp
    let browser = NWBrowser(for: .bonjour(type: "_mochilog._tcp", domain: nil), using: parameters)
    browser.browseResultsChangedHandler = { [weak self] results, _ in
      Task { @MainActor in
        guard let self, self.active else { return }
        var routes: [UUID: [NWEndpoint]] = [:]
        for result in results {
          guard case .service(let name, _, _, _) = result.endpoint,
            let host = UUID(uuidString: name) else { continue }
          if case .bonjour(let txt) = result.metadata,
            let rawPort = txt["port"].flatMap(UInt16.init), rawPort != 0,
            let port = NWEndpoint.Port(rawValue: rawPort) {
            routes[host] = (txt["ipv4"] ?? "").split(separator: ",").prefix(4).compactMap {
              IPv4Address(String($0)).map { .hostPort(host: .ipv4($0), port: port) }
            }
            if let address = txt["tailnet"], let ip = IPv4Address(address),
              let value = (txt["tailnetPort"] ?? txt["port"]).flatMap(UInt16.init),
              let tailPort = NWEndpoint.Port(rawValue: value), Self.isTailnet(address) {
              routes[host, default: []].append(.hostPort(host: .ipv4(ip), port: tailPort))
            }
          }
          routes[host, default: []].append(result.endpoint)
        }
        self.discovered = routes
      }
    }
    self.browser = browser
    browser.start(queue: .global(qos: .utility))
    let monitor = NWPathMonitor()
    monitor.pathUpdateHandler = { [weak self] path in
      Task { @MainActor in self?.path = path }
    }
    self.monitor = monitor
    monitor.start(queue: .global(qos: .utility))
    task = Task { [weak self] in
      while !Task.isCancelled {
        await self?.receiveNow()
        try? await Task.sleep(for: .seconds(15))
      }
    }
  }

  func stop() {
    active = false
    task?.cancel(); task = nil
    browser?.cancel(); browser = nil
    monitor?.cancel(); monitor = nil
    discovered = [:]
    if !AppSettings.shared.liveBatteryEnabled { readings = [:]; states = [:] }
  }

  static func isTailnet(_ address: String) -> Bool {
    let parts = address.split(separator: ".").compactMap { Int($0) }
    return parts.count == 4 && parts[0] == 100 && (64...127).contains(parts[1])
  }

  private func routes(for pairing: MacTransferPairing) -> [NWEndpoint] {
    var routes = discovered[pairing.hostID] ?? []
    func add(_ address: String?, _ port: UInt16?) {
      guard let address, let ip = IPv4Address(address), let port, port != 0,
        let endpointPort = NWEndpoint.Port(rawValue: port) else { return }
      let route: NWEndpoint = .hostPort(host: .ipv4(ip), port: endpointPort)
      if !routes.contains(route) { routes.append(route) }
    }
    add(pairing.manualHostAddress, pairing.lanPort ?? (pairing.platform == "windows" ? 54556 : 54555))
    for address in pairing.lanAddresses ?? [] { add(address, pairing.lanPort) }
    add(pairing.tailnetAddress, pairing.tailnetPort)
    #if DEBUG
    if ProcessInfo.processInfo.environment["MOCHI_LIVE_BATTERY_PORT"] != nil { return routes }
    #endif
    let wifi = path?.usesInterfaceType(.wifi) == true || path?.usesInterfaceType(.wiredEthernet) == true
    if !wifi {
      guard MacTransferManager.shared.allowsCellularTransfer else { return [] }
      return routes.filter {
        guard case .hostPort(let host, _) = $0 else { return false }
        return Self.isTailnet(String(describing: host))
      }
    }
    return routes
  }

  func receiveNow(refresh: Bool = false) async {
    guard active, !busy else { return }
    busy = true
    defer { busy = false }
    let pairings = activePairings
    for pairing in pairings {
      guard !Task.isCancelled, active else { return }
      let candidates = routes(for: pairing)
      if candidates.isEmpty { states[pairing.hostID] = "network"; continue }
      var received = false
      for route in candidates.prefix(6) {
        guard !Task.isCancelled, active else { return }
        do {
          let nonce = UUID()
          let message = "v2|\(pairing.hostID.uuidString)|\(pairing.physicalDeviceID.uuidString)|\(nonce.uuidString)|"
          let mac = HMAC<SHA256>.authenticationCode(for: Data(message.utf8),
            using: SymmetricKey(data: pairing.secret)).map { String(format: "%02x", $0) }.joined()
          let request: [String: String] = ["hostID": pairing.hostID.uuidString,
            "physicalDeviceID": pairing.physicalDeviceID.uuidString, "nonce": nonce.uuidString,
            "ack": "", "mac": mac, "version": "2", "liveBatteryVersion": "1",
            "liveBatteryRevision": readings[pairing.hostID]?.revision ?? "",
            "liveBatteryRefresh": refresh ? "1" : "0"]
          let issuedAt = Int64(Date().timeIntervalSince1970)
          let aad = Data("v3|request|\(pairing.hostID.uuidString)|\(pairing.physicalDeviceID.uuidString)|\(nonce.uuidString)|\(issuedAt)".utf8)
          let inner = try JSONSerialization.data(withJSONObject: request)
          let box = try AES.GCM.seal(inner, using: SymmetricKey(data: pairing.secret), authenticating: aad)
          let payload = try JSONSerialization.data(withJSONObject: ["version": "3",
            "hostID": pairing.hostID.uuidString, "physicalDeviceID": pairing.physicalDeviceID.uuidString,
            "nonce": nonce.uuidString, "issuedAt": issuedAt, "box": box.combined!.base64EncodedString()] as [String: Any]) + Data([10])
          let encrypted = try await LiveBatteryTransport.exchange(route, payload: payload)
          let responseAAD = Data("v2|response|\(pairing.hostID.uuidString)|\(pairing.physicalDeviceID.uuidString)|\(nonce.uuidString)".utf8)
          let plain = try AES.GCM.open(AES.GCM.SealedBox(combined: encrypted),
            using: SymmetricKey(data: pairing.secret), authenticating: responseAAD)
          guard plain.count >= 2, plain[0] == 0, plain[1] == 0 else { throw LiveBatteryTransport.Failure.unsupported }
          let json = try JSONSerialization.jsonObject(with: plain.dropFirst(2)) as? [String: Any]
          guard json?["type"] as? String == "live-battery", json?["version"] as? Int == 1,
            let state = json?["state"] as? String,
            ["waiting", "unavailable", "stale", "current"].contains(state) else { throw LiveBatteryTransport.Failure.unsupported }
          if let json, let reading = try Self.reading(json, previous: readings[pairing.hostID]) {
            guard active, activePairings.contains(where: {
              $0.hostID == pairing.hostID && $0.physicalDeviceID == pairing.physicalDeviceID
            }) else { return }
            readings[pairing.hostID] = reading
          }
          guard active, !Task.isCancelled else { return }
          states[pairing.hostID] = state
          received = true
          break
        } catch LiveBatteryTransport.Failure.unsupported {
          states[pairing.hostID] = "update"
          received = true; break
        } catch { states[pairing.hostID] = "offline" }
      }
      if !received { states[pairing.hostID] = "offline" }
    }
  }

  static func reading(_ object: [String: Any], previous: LiveBatteryReading?) throws -> LiveBatteryReading? {
    guard let revision = object["revision"] as? String else { return nil }
    guard revision.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
      let timestamp = object["acquiredAt"] as? String,
      let date = Self.date(timestamp) else { throw LiveBatteryTransport.Failure.invalid }
    guard let raw = object["values"] as? [String: Any] else {
      guard let previous, previous.revision == revision else { throw LiveBatteryTransport.Failure.invalid }
      return LiveBatteryReading(values: previous.values, charging: previous.charging,
        revision: revision, acquiredAt: date)
    }
    let limits = ["CycleCount": 0...100000, "DesignCapacity": 1...200000,
      "FullChargeCapacity": 1...200000, "NominalChargeCapacity": 1...200000,
      "AppleRawMaxCapacity": 1...200000, "CurrentCapacity": 0...100]
    var values: [String: Int] = [:]
    for (key, range) in limits {
      if let number = raw[key] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
        number.doubleValue.isFinite, number.doubleValue == Double(number.intValue),
        range.contains(number.intValue) { values[key] = number.intValue }
    }
    guard !values.filter({ $0.key != "CurrentCapacity" }).isEmpty else { throw LiveBatteryTransport.Failure.invalid }
    let charging = (object["charging"] as? NSNumber).flatMap {
      CFGetTypeID($0) == CFBooleanGetTypeID() ? $0.boolValue : nil
    }
    var canonical: [String: Any] = values
    if let charging { canonical["IsCharging"] = charging }
    let digest = SHA256.hash(data: try JSONSerialization.data(withJSONObject: canonical, options: [.sortedKeys]))
      .map { String(format: "%02x", $0) }.joined()
    guard digest == revision else { throw LiveBatteryTransport.Failure.invalid }
    return LiveBatteryReading(values: values, charging: charging, revision: revision, acquiredAt: date)
  }

  static func date(_ text: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
  }
}

@available(iOS 27, *)
private final class LiveBatteryTransport: @unchecked Sendable {
  enum Failure: Error { case unavailable, invalid, unsupported }
  private let connection: NWConnection
  private let queue = DispatchQueue(label: "net.ryuya-dev.MochiLog.live-battery")
  private var completion: CheckedContinuation<Data, Error>?
  private var buffer = Data()
  private var timeout: DispatchWorkItem?
  private init(_ endpoint: NWEndpoint, allowsCellular: Bool) {
    let parameters = NWParameters.tcp
    parameters.prohibitExpensivePaths = !allowsCellular
    connection = NWConnection(to: endpoint, using: parameters)
  }
  static func exchange(_ endpoint: NWEndpoint, payload: Data) async throws -> Data {
    let transport = LiveBatteryTransport(endpoint, allowsCellular: MacTransferManager.shared.allowsCellularTransfer)
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        transport.queue.async { transport.begin(payload, continuation) }
      }
    } onCancel: {
      transport.queue.async { transport.finish(.failure(CancellationError())) }
    }
  }
  private func begin(_ payload: Data, _ continuation: CheckedContinuation<Data, Error>) {
    completion = continuation
    let deadline = DispatchWorkItem { [weak self] in self?.finish(.failure(Failure.unavailable)) }
    timeout = deadline
    queue.asyncAfter(deadline: .now() + 8, execute: deadline)
    connection.stateUpdateHandler = { [weak self] state in
      guard let self else { return }
      switch state {
      case .ready:
        self.connection.send(content: payload, completion: .contentProcessed { error in
          if let error { self.finish(.failure(error)) } else { self.receive() }
        })
      case .failed(let error): self.finish(.failure(error))
      case .cancelled: self.finish(.failure(Failure.unavailable))
      default: break
      }
    }
    connection.start(queue: queue)
  }
  private func receive() {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, complete, error in
      guard let self, self.completion != nil else { return }
      if let data { self.buffer.append(data) }
      guard self.buffer.count <= 8196 else { self.finish(.failure(Failure.unsupported)); return }
      if self.buffer.count >= 4 {
        let length = self.buffer.prefix(4).reduce(0) { ($0 << 8) | Int($1) }
        guard (28...8192).contains(length) else { self.finish(.failure(Failure.unsupported)); return }
        if self.buffer.count == length + 4 { self.finish(.success(self.buffer.dropFirst(4))); return }
        if self.buffer.count > length + 4 { self.finish(.failure(Failure.invalid)); return }
      }
      if let error { self.finish(.failure(error)) }
      else if complete { self.finish(.failure(Failure.invalid)) }
      else { self.receive() }
    }
  }
  private func finish(_ result: Result<Data, Error>) {
    guard let completion else { return }
    self.completion = nil
    timeout?.cancel(); timeout = nil
    connection.cancel()
    completion.resume(with: result)
  }
}
