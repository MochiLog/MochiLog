import Combine
import CryptoKit
import Foundation
import Network
import Security
import UIKit

struct MacTransferPairing: Codable {
  let hostID: UUID
  let physicalDeviceID: UUID
  let model: String
  let secret: Data
  var tailnetAddress: String?
  var tailnetPort: UInt16?
}

@available(iOS 27, *)
struct SecureMacPairingCandidate: Identifiable {
  let pairing: MacTransferPairing
  let sessionID: UUID
  let clientPublicKey: Data
  let routes: [NWEndpoint]
  let relinkLocalRecords: Bool
  var id: UUID { sessionID }
}

@available(iOS 27, *)
enum MacTransferConnectionPhase {
  case needsPairing, checkingNetwork, offline, waitingForWiFi
  case searching, connecting, receiving, available, retrying
}

@available(iOS 27, *)
@MainActor
final class MacTransferManager: ObservableObject {
  static let shared = MacTransferManager()
  @Published private(set) var pairing: MacTransferPairing?
  @Published private(set) var status = MacTransferStatus.text("mt_s_00") {
    didSet { if status != oldValue { Self.appendDebugEvent(status) } }
  }
  @Published private(set) var isReceiving = false
  @Published private(set) var connectionPhase: MacTransferConnectionPhase = .needsPairing
  @Published private(set) var lastAuthenticatedContactAt: Date?
  @Published private(set) var allowsCellularTransfer = UserDefaults.standard.bool(
    forKey: "MacTransferAllowsCellularData")
  private let queue = DispatchQueue(label: "net.ryuya-dev.MochiLog.mac-transfer")
  private var browser: NWBrowser?
  private var pathMonitor: NWPathMonitor?
  private var pathSignature: String?
  private var hasNetworkPath = false
  private var networkIsAvailable = false
  private var networkUsesWiFiOrEthernet = false
  private var reconnectTask: Task<Void, Never>?
  private var retryDelay: UInt64 = 5
  private var isRunning = false
  private var connection: NWConnection?
  private var activeRequestNonce: UUID?
  private var endpoint: NWEndpoint?
  private var directRoutes: [NWEndpoint] = []
  private var routeIndex = 0
  private var accumulated = Data()
  private var pendingAck: String?
  private let unconfirmedKey = "MacTransferUnconfirmedFiles"
  private let confirmedKey = "MacTransferConfirmedFiles"
  private let macDiagnosticsKey = "MacTransferLastMacDiagnostics"
  private static let debugEventsKey = "MacTransferDebugEvents"

  private init() {
    pairing = Self.loadPairing()
    status = MacTransferStatus.text(pairing == nil ? "mt_s_00" : "mt_s_01")
    connectionPhase = pairing == nil ? .needsPairing : .checkingNetwork
    pendingAck = UserDefaults.standard.string(forKey: "MacTransferPendingAck")
  }

  func setAllowsCellularTransfer(_ allowed: Bool) {
    guard allowsCellularTransfer != allowed else { return }
    allowsCellularTransfer = allowed
    UserDefaults.standard.set(allowed, forKey: "MacTransferAllowsCellularData")
    Self.appendDebugEvent("Cellular transfer: \(allowed ? "enabled" : "disabled")")
    guard isRunning, hasNetworkPath else { return }
    if networkPermitsTransfer {
      retryDelay = 5
      beginDiscovery() // Recreate connections with the new interface policy.
    } else {
      pauseForNetwork()
    }
  }

  private var networkPermitsTransfer: Bool {
    hasNetworkPath && networkIsAvailable &&
      (allowsCellularTransfer || networkUsesWiFiOrEthernet)
  }

  private func pauseForNetwork() {
    reconnectTask?.cancel()
    reconnectTask = nil
    browser?.cancel()
    browser = nil
    connection?.cancel()
    connection = nil
    activeRequestNonce = nil
    endpoint = nil
    directRoutes = []
    accumulated = Data()
    isReceiving = false
    connectionPhase = networkIsAvailable ? .waitingForWiFi : .offline
    status = MacTransferStatus.text(networkIsAvailable ? "mt_s_18" : "mt_s_19")
  }

  func prepareSecurePairing(from text: String, dataStore: DataStore,
    relinkLocalRecords: Bool = false) async throws -> SecureMacPairingCandidate {
    guard let components = URLComponents(string: text),
      components.scheme == "mochilog-mac", components.host == "pair" else {
      throw TransferError.invalidPairing
    }
    var values: [String: String] = [:]
    for item in components.queryItems ?? [] {
      guard let value = item.value, values[item.name] == nil else {
        throw TransferError.invalidPairing
      }
      values[item.name] = value
    }
    guard values["v"] == "2",
      let host = values["host"].flatMap(UUID.init(uuidString:)),
      let device = values["device"].flatMap(UUID.init(uuidString:)),
      let session = values["session"].flatMap(UUID.init(uuidString:)),
      let model = values["model"], model == DeviceLibrary.localModelIdentifier(),
      let macPublicBytes = values["public"].flatMap({ Data(base64Encoded: $0) }),
      macPublicBytes.count == 32,
      let macPublic = try? Curve25519.KeyAgreement.PublicKey(
        rawRepresentation: macPublicBytes),
      let port = values["port"].flatMap(UInt16.init), port != 0,
      let endpointPort = NWEndpoint.Port(rawValue: port)
    else { throw TransferError.invalidPairing }
    let previousID = PhysicalDeviceIdentityStore.current()
    if previousID != device && !relinkLocalRecords &&
      dataStore.recordsDescending.contains(where: {
        $0.physicalDeviceID == previousID && $0.deviceModelCode == model
      }) { throw TransferError.identityConflict }
    var routes: [NWEndpoint] = (values["ipv4"] ?? "").split(separator: ",")
      .prefix(4).compactMap { text in
        guard let address = IPv4Address(String(text)),
          Self.isPrivateLANAddress(String(text)) else { return nil }
        return .hostPort(host: .ipv4(address), port: endpointPort)
      }
    let tailnetPort = values["tailnetPort"].flatMap(UInt16.init)
    if let tailnet = Self.tailnetRoute(address: values["tailnet"], port: tailnetPort) {
      routes.append(tailnet)
    }
    guard !routes.isEmpty else { throw TransferError.invalidPairing }
    let clientPrivate = Curve25519.KeyAgreement.PrivateKey()
    let clientPublic = clientPrivate.publicKey.rawRepresentation
    let shared = try clientPrivate.sharedSecretFromKeyAgreement(with: macPublic)
    let derived = shared.hkdfDerivedSymmetricKey(using: SHA256.self,
      salt: Data(session.uuidString.utf8),
      sharedInfo: Data("MochiLog pair v2|\(host.uuidString)|\(device.uuidString)".utf8),
      outputByteCount: 32)
    let secret = derived.withUnsafeBytes { Data($0) }
    let initiation = try JSONSerialization.data(withJSONObject: [
      "type": "pair-init", "sessionID": session.uuidString,
      "clientPublicKey": clientPublic.base64EncodedString()
    ])
    let reply = try await PairingTransport.exchange(routes: routes,
      payload: initiation, allowCellular: allowsCellularTransfer)
    guard let object = try JSONSerialization.jsonObject(with: reply) as? [String: String],
      object["type"] == "pair-challenge", object["sessionID"] == session.uuidString,
      let supplied = object["proof"] else { throw TransferError.invalidPairing }
    let expected = Self.authenticationCode("pair-challenge|\(session.uuidString)",
      secret: secret)
    guard supplied == expected
    else { throw TransferError.invalidPairing }
    let pair = MacTransferPairing(hostID: host, physicalDeviceID: device,
      model: model, secret: secret,
      tailnetAddress: values["tailnet"], tailnetPort: tailnetPort)
    return SecureMacPairingCandidate(pairing: pair, sessionID: session,
      clientPublicKey: clientPublic, routes: routes,
      relinkLocalRecords: relinkLocalRecords)
  }

  func confirmSecurePairing(_ candidate: SecureMacPairingCandidate,
    enteredCode: String, dataStore: DataStore) async throws {
    let code = enteredCode.trimmingCharacters(in: .whitespacesAndNewlines)
    guard code.count == 6, code.allSatisfy({ $0 >= "0" && $0 <= "9" }) else {
      throw TransferError.invalidPairingCode
    }
    let key = SymmetricKey(data: candidate.pairing.secret)
    let confirmationMAC = HMAC<SHA256>.authenticationCode(
      for: Data("pair-confirm|\(candidate.sessionID.uuidString)|\(code)".utf8),
      using: key).map { String(format: "%02x", $0) }.joined()
    let request = try JSONSerialization.data(withJSONObject: [
      "type": "pair-confirm", "sessionID": candidate.sessionID.uuidString,
      "clientPublicKey": candidate.clientPublicKey.base64EncodedString(),
      "confirmationMAC": confirmationMAC
    ])
    let reply = try await PairingTransport.exchange(routes: candidate.routes,
      payload: request, allowCellular: allowsCellularTransfer)
    guard let object = try JSONSerialization.jsonObject(with: reply) as? [String: String],
      object["type"] == "pair-complete",
      object["sessionID"] == candidate.sessionID.uuidString,
      let supplied = object["proof"] else { throw TransferError.invalidPairing }
    let expected = HMAC<SHA256>.authenticationCode(
      for: Data("pair-complete|\(candidate.sessionID.uuidString)".utf8),
      using: key).map { String(format: "%02x", $0) }.joined()
    guard supplied == expected else { throw TransferError.invalidPairing }
    let pair = candidate.pairing
    let previousID = PhysicalDeviceIdentityStore.current()
    if previousID != pair.physicalDeviceID && candidate.relinkLocalRecords {
      _ = try dataStore.reassignPhysicalDeviceID(from: previousID,
        to: pair.physicalDeviceID, matchingModelCode: pair.model)
    }
    if pairing?.hostID != pair.hostID || pairing?.physicalDeviceID != pair.physicalDeviceID {
      UserDefaults.standard.removeObject(forKey: macDiagnosticsKey)
    }
    try Self.savePairing(pair)
    pairing = pair
    PhysicalDeviceIdentityStore.replace(with: pair.physicalDeviceID)
    status = MacTransferStatus.text("mt_s_01")
    stop()
    start()
  }

  private static func isPrivateLANAddress(_ address: String) -> Bool {
    let parts = address.split(separator: ".").compactMap { Int($0) }
    guard parts.count == 4 else { return false }
    return parts[0] == 10 || (parts[0] == 172 && (16...31).contains(parts[1])) ||
      (parts[0] == 192 && parts[1] == 168)
  }

  func start() {
    guard pairing != nil else { return }
    guard !isRunning else { return }
    isRunning = true
    retryDelay = 5
    hasNetworkPath = false
    connectionPhase = .checkingNetwork
    let monitor = NWPathMonitor()
    pathMonitor = monitor
    monitor.pathUpdateHandler = { [weak self, weak monitor] path in
      let signature = "\(path.status)|\(path.usesInterfaceType(.wifi))|\(path.usesInterfaceType(.cellular))|\(path.usesInterfaceType(.wiredEthernet))|\(path.availableInterfaces.map(\.name).sorted())"
      Task { @MainActor in
        guard let self, self.pathMonitor === monitor, self.isRunning else { return }
        let previous = self.pathSignature
        self.pathSignature = signature
        self.hasNetworkPath = true
        self.networkIsAvailable = path.status == .satisfied
        self.networkUsesWiFiOrEthernet = path.usesInterfaceType(.wifi) ||
          path.usesInterfaceType(.wiredEthernet)
        guard self.networkPermitsTransfer else {
          self.pauseForNetwork()
          return
        }
        guard previous != signature else { return }
        Self.appendDebugEvent("Network changed: scheduling automatic reconnect")
        self.retryDelay = 5
        self.beginDiscovery()
      }
    }
    monitor.start(queue: queue)
  }

  func receiveNow() {
    guard pairing != nil, !isReceiving else { return }
    status = MacTransferStatus.text("mt_s_20")
    retryDelay = 5
    if isRunning, hasNetworkPath {
      beginDiscovery()
    } else if !isRunning {
      start()
    }
  }

  private func beginDiscovery() {
    guard isRunning, let pairing else { return }
    guard networkPermitsTransfer else { pauseForNetwork(); return }
    reconnectTask?.cancel()
    reconnectTask = nil
    browser?.cancel()
    browser = nil
    connection?.cancel()
    connection = nil
    activeRequestNonce = nil
    accumulated = Data()
    endpoint = nil
    directRoutes = []
    routeIndex = 0
    isReceiving = false
    connectionPhase = .searching
    requeueConfirmedFiles(for: pairing)
    if let route = Self.tailnetRoute(address: pairing.tailnetAddress,
      port: pairing.tailnetPort) {
      directRoutes = [route]
      routeIndex = 0
    }
    let browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_mochilog._tcp", domain: nil), using: .tcp)
    self.browser = browser
    browser.browseResultsChangedHandler = { [weak self, weak browser] results, _ in
      guard let self else { return }
      let result = results.first(where: { result in
        if case .service(let name, _, _, _) = result.endpoint {
          return name == pairing.hostID.uuidString
        }
        return false
      })
      Task { @MainActor in
        guard self.isRunning, self.browser === browser else { return }
        Self.appendDebugEvent("Bonjour: \(results.count) service(s), paired Mac \(result == nil ? "not found" : "found")")
        guard let result else { return }
        Self.appendDebugEvent("Bonjour interfaces: \(result.interfaces.map(\.name).joined(separator: ", "))")
        self.endpoint = result.endpoint
        self.connectionPhase = .connecting
        if case .bonjour(let record) = result.metadata,
          let tailnet = record["tailnet"],
          let port = (record["tailnetPort"] ?? record["port"]).flatMap(UInt16.init),
          Self.tailnetRoute(address: tailnet, port: port) != nil,
          (self.pairing?.tailnetAddress != tailnet || self.pairing?.tailnetPort != port),
          var updated = self.pairing {
          updated.tailnetAddress = tailnet
          updated.tailnetPort = port
          if (try? Self.savePairing(updated)) != nil { self.pairing = updated }
        }
        let newRoutes = Self.routes(from: result.metadata)
        if newRoutes != self.directRoutes {
          self.directRoutes = newRoutes
          self.routeIndex = 0
          Self.appendDebugEvent("Bonjour: \(newRoutes.count) direct route(s) advertised")
          if let active = self.connection, case .preparing = active.state {
            active.cancel()
            self.connection = nil
            self.isReceiving = false
          }
        }
        self.pull()
      }
    }
    browser.stateUpdateHandler = { [weak self, weak browser] state in
      Task { @MainActor [weak self] in
        guard let self, self.isRunning, self.browser === browser else { return }
        switch state {
        case .ready:
          Self.appendDebugEvent("Bonjour: ready")
        case .waiting(let error):
          Self.appendDebugEvent("Bonjour: waiting (\(error.localizedDescription))")
        case .failed(let error):
          self.connectionPhase = .retrying
          self.status = MacTransferStatus.text("mt_s_02", error.localizedDescription)
          self.scheduleRetry()
        default: break
        }
      }
    }
    browser.start(queue: queue)
    if !directRoutes.isEmpty {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
        guard let self, self.isRunning, self.browser === browser,
          self.endpoint == nil else { return }
        self.pull()
      }
    }
  }

  private func scheduleReconnect(after seconds: UInt64, interruptActive: Bool = false) {
    guard isRunning else { return }
    reconnectTask?.cancel()
    reconnectTask = Task { [weak self] in
      do { try await Task.sleep(nanoseconds: seconds * 1_000_000_000) }
      catch { return }
      guard let self, self.isRunning else { return }
      // A discovery failure must not interrupt a transfer already using a
      // saved direct route. Only an actual path change invalidates that route.
      guard interruptActive || self.connection == nil else { return }
      Self.appendDebugEvent("Connection: automatic reconnect")
      self.beginDiscovery()
    }
  }

  private func scheduleRetry() {
    scheduleReconnect(after: retryDelay)
    retryDelay = min(retryDelay * 2, 60)
  }

  func stop() {
    isRunning = false
    reconnectTask?.cancel()
    reconnectTask = nil
    pathMonitor?.cancel()
    pathMonitor = nil
    pathSignature = nil
    hasNetworkPath = false
    Self.appendDebugEvent("Connection: stopped")
    browser?.cancel()
    browser = nil
    connection?.cancel()
    connection = nil
    activeRequestNonce = nil
    endpoint = nil
    directRoutes = []
    routeIndex = 0
    isReceiving = false
    connectionPhase = pairing == nil ? .needsPairing : .checkingNetwork
  }

  func stopForBackground() {
    let pairing = pairing
    let route = routeIndex < directRoutes.count ? directRoutes[routeIndex]
      : (endpoint ?? Self.tailnetRoute(
        address: pairing?.tailnetAddress, port: pairing?.tailnetPort))
    let mayUseCellular = allowsCellularTransfer
    let wasRunning = isRunning
    stop()
    guard wasRunning, let pairing, let route else { return }
    let nonce = UUID()
    let presence = "background"
    let message = "v2|background|\(pairing.hostID.uuidString)|\(pairing.physicalDeviceID.uuidString)|\(nonce.uuidString)"
    let request: [String: String] = [
      "hostID": pairing.hostID.uuidString,
      "physicalDeviceID": pairing.physicalDeviceID.uuidString,
      "nonce": nonce.uuidString,
      "ack": "",
      "mac": Self.authenticationCode(message, secret: pairing.secret),
      "version": "2",
      "presence": presence
    ]
    guard let payload = try? JSONSerialization.data(withJSONObject: request) else { return }
    let parameters = NWParameters.tcp
    if !mayUseCellular { parameters.prohibitedInterfaceTypes = [.cellular] }
    let connection = NWConnection(to: route, using: parameters)
    let transferQueue = queue
    var finished = false
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    let finish = {
      guard !finished else { return }
      finished = true
      connection.cancel()
      let task = backgroundTask
      DispatchQueue.main.async {
        if task != .invalid { UIApplication.shared.endBackgroundTask(task) }
      }
    }
    backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "MochiLog Mac presence") {
      transferQueue.async { finish() }
    }
    connection.stateUpdateHandler = { state in
      switch state {
      case .ready:
        connection.send(content: payload + Data([10]), completion: .contentProcessed { error in
          if error != nil { finish(); return }
          connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { _, _, _, _ in
            finish()
          }
        })
      case .failed, .cancelled: finish()
      default: break
      }
    }
    connection.start(queue: transferQueue)
    transferQueue.asyncAfter(deadline: .now() + 5) { finish() }
  }

  private static func authenticationCode(_ message: String, secret: Data) -> String {
    HMAC<SHA256>.authenticationCode(for: Data(message.utf8),
      using: SymmetricKey(data: secret))
      .map { String(format: "%02x", $0) }.joined()
  }

  private static func routes(from metadata: NWBrowser.Result.Metadata) -> [NWEndpoint] {
    guard case .bonjour(let record) = metadata,
      let portText = record["port"], let portValue = UInt16(portText),
      let port = NWEndpoint.Port(rawValue: portValue), portValue != 0 else { return [] }
    var routes: [NWEndpoint] = Array((record["ipv4"] ?? "")
      .split(separator: ",").prefix(4)).compactMap { text in
      guard let address = IPv4Address(String(text)) else { return nil }
      return .hostPort(host: .ipv4(address), port: port)
    }
    let tailnetPort = (record["tailnetPort"] ?? record["port"]).flatMap(UInt16.init)
    if let tailnet = tailnetRoute(address: record["tailnet"], port: tailnetPort) {
      #if DEBUG
      if ProcessInfo.processInfo.environment["MOCHILOG_FORCE_TAILNET"] == "1" {
        return [tailnet]
      }
      #endif
      routes.append(tailnet)
    }
    return routes
  }

  private static func tailnetRoute(address: String?, port: UInt16?) -> NWEndpoint? {
    guard let address, let port, port != 0,
      let ipv4 = IPv4Address(address) else { return nil }
    let parts = address.split(separator: ".").compactMap { Int($0) }
    guard
      parts.count == 4, parts[0] == 100,
      (64...127).contains(parts[1]),
      let endpointPort = NWEndpoint.Port(rawValue: port) else { return nil }
    return .hostPort(host: .ipv4(ipv4), port: endpointPort)
  }

  private func routeFailed(_ failed: NWConnection, error: String) {
    guard connection === failed else { return }
    failed.cancel()
    connection = nil
    activeRequestNonce = nil
    isReceiving = false
    if routeIndex < directRoutes.count &&
      (routeIndex + 1 < directRoutes.count || endpoint != nil) {
      routeIndex += 1
      Self.appendDebugEvent("Connection: trying next route (\(routeIndex + 1))")
      pull()
    } else {
      connectionPhase = .retrying
      status = MacTransferStatus.text("mt_s_03", error)
      scheduleRetry()
    }
  }

  private func pull() {
    guard isRunning, let pairing, networkPermitsTransfer,
      endpoint != nil || routeIndex < directRoutes.count else {
      Self.appendDebugEvent("Connection: waiting for pairing or Mac endpoint")
      return
    }
    guard connection == nil else {
      Self.appendDebugEvent("Connection: previous attempt still active")
      return
    }
    Self.appendDebugEvent("Connection: starting")
    isReceiving = true
    connectionPhase = .connecting
    let nonce = UUID()
    let ack = pendingAck ?? ""
    let message = "v2|\(pairing.hostID.uuidString)|\(pairing.physicalDeviceID.uuidString)|\(nonce.uuidString)|\(ack)"
    let mac = Self.authenticationCode(message, secret: pairing.secret)
    let presence = "foreground"
    let presenceMAC = Self.authenticationCode("presence|\(nonce.uuidString)|\(presence)",
      secret: pairing.secret)
    let diagnostics = supportDiagnosticsData()
    let diagnosticsContext = Data("v2|diagnostics|\(pairing.hostID.uuidString)|\(pairing.physicalDeviceID.uuidString)|\(nonce.uuidString)".utf8)
    guard let diagnosticsBox = try? AES.GCM.seal(diagnostics,
      using: SymmetricKey(data: pairing.secret), authenticating: diagnosticsContext).combined
    else { return }
    let request: [String: String] = [
      "hostID": pairing.hostID.uuidString,
      "physicalDeviceID": pairing.physicalDeviceID.uuidString,
      "nonce": nonce.uuidString,
      "ack": ack,
      "mac": mac,
      "version": "2",
      "presence": presence,
      "presenceMAC": presenceMAC,
      "clientDiagnosticsBox": diagnosticsBox.base64EncodedString()
    ]
    guard let payload = try? JSONSerialization.data(withJSONObject: request) else { return }
    guard let route = routeIndex < directRoutes.count
      ? directRoutes[routeIndex] : endpoint else { return }
    let parameters = NWParameters.tcp
    if !allowsCellularTransfer {
      parameters.prohibitedInterfaceTypes = [.cellular]
    }
    let connection = NWConnection(to: route, using: parameters)
    self.connection = connection
    activeRequestNonce = nonce
    accumulated = Data()
    connection.pathUpdateHandler = { [weak self, weak connection] path in
      Task { @MainActor in
        Self.appendDebugEvent("Path: \(path.status), Wi-Fi \(path.usesInterfaceType(.wifi)), reason \(String(describing: path.unsatisfiedReason))")
        guard let self, let connection, self.connection === connection,
          !self.allowsCellularTransfer,
          !path.usesInterfaceType(.wifi), !path.usesInterfaceType(.wiredEthernet) else { return }
        self.pauseForNetwork()
      }
    }
    connection.stateUpdateHandler = { [weak self] state in
      guard let self else { return }
      switch state {
      case .preparing:
        Task { @MainActor in Self.appendDebugEvent("Connection: preparing") }
      case .ready:
        Task { @MainActor in Self.appendDebugEvent("Connection: ready") }
        connection.send(content: payload + Data([10]), completion: .contentProcessed { error in
          Task { @MainActor in
            guard self.isRunning, self.connection === connection else { return }
            if let error {
              self.routeFailed(connection, error: error.localizedDescription)
            } else {
              Self.appendDebugEvent("Connection: request sent")
              self.receive(on: connection)
            }
          }
        })
      case .waiting(let error):
        Task { @MainActor in Self.appendDebugEvent("Connection: waiting (\(error.localizedDescription))") }
      case .failed(let error):
        Task { @MainActor in
          Self.appendDebugEvent("Connection: failed (\(error.localizedDescription))")
          self.routeFailed(connection, error: error.localizedDescription)
        }
      case .cancelled:
        Task { @MainActor in Self.appendDebugEvent("Connection: cancelled") }
      default: break
      }
    }
    connection.start(queue: queue)
    let timeout: TimeInterval = routeIndex < directRoutes.count ? 6 : 20
    DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self, weak connection] in
      guard let self, let connection, self.connection === connection else { return }
      switch connection.state {
      case .ready, .failed, .cancelled: return
      default: break
      }
      self.routeFailed(connection, error: URLError(.timedOut).localizedDescription)
    }
  }

  private func receive(on connection: NWConnection) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, complete, error in
      guard let self else { return }
      Task { @MainActor in
        guard self.isRunning, self.connection === connection else { return }
        if let data { self.accumulated.append(data) }
        if let data, !data.isEmpty { self.connectionPhase = .receiving }
        if self.accumulated.count > 64 * 1024 * 1024 + 1_024 {
          connection.cancel()
          self.status = MacTransferStatus.text("mt_s_04")
          self.isReceiving = false
          self.connectionPhase = .retrying
          return
        }
        if let error {
          self.routeFailed(connection, error: error.localizedDescription)
        } else if complete {
          let bytes = self.accumulated
          self.accumulated = Data()
          self.finish(bytes, connection: connection)
        } else {
          self.receive(on: connection)
        }
      }
    }
  }

  private func finish(_ bytes: Data, connection: NWConnection) {
    defer { connection.cancel(); self.connection = nil; activeRequestNonce = nil }
    guard let pairing, let requestNonce = activeRequestNonce, bytes.count >= 4 else {
      status = MacTransferStatus.text("mt_s_06"); isReceiving = false
      connectionPhase = .retrying
      scheduleRetry()
      return
    }
    let length = bytes.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    guard length == bytes.count - 4 else {
      Self.appendDebugEvent("Transfer: frame length \(length), received \(bytes.count - 4)")
      status = MacTransferStatus.text("mt_s_07"); isReceiving = false
      connectionPhase = .retrying
      scheduleRetry()
      return
    }
    do {
      let box = try AES.GCM.SealedBox(combined: bytes.dropFirst(4))
      let responseContext = Data("v2|response|\(pairing.hostID.uuidString)|\(pairing.physicalDeviceID.uuidString)|\(requestNonce.uuidString)".utf8)
      let plain = try AES.GCM.open(box, using: SymmetricKey(data: pairing.secret),
        authenticating: responseContext)
      guard plain.count >= 2 else { throw TransferError.invalidPayload }
      let nameLength = Int(plain[0]) * 256 + Int(plain[1])
      guard nameLength <= 1024, plain.count >= 2 + nameLength,
        let name = String(data: plain.subdata(in: 2..<(2 + nameLength)), encoding: .utf8)
      else { throw TransferError.invalidPayload }
      lastAuthenticatedContactAt = Date()
      if name.isEmpty {
        // The Mac has processed the final file acknowledgement and returned
        // an authenticated terminal reply. Only now may imports begin.
        let report = plain.dropFirst(2)
        if !report.isEmpty, report.count <= 16_384,
          let object = try? JSONSerialization.jsonObject(with: report) as? [String: Any],
          object["schema"] as? Int == 1,
          object["platform"] as? String == "macOS" {
          UserDefaults.standard.set(Data(report), forKey: macDiagnosticsKey)
        }
        let confirmedCount = confirmReceivedFiles(for: pairing)
        Self.appendDebugEvent("Transfer: confirmed \(confirmedCount) received file(s)")
        if pendingAck != nil {
          pendingAck = nil
          UserDefaults.standard.removeObject(forKey: "MacTransferPendingAck")
        }
        status = confirmedCount == 0 ? MacTransferStatus.text("mt_s_08")
          : MacTransferStatus.text("mt_s_09", confirmedCount)
        isReceiving = false
        connectionPhase = .available
        retryDelay = 5
        scheduleReconnect(after: 60)
        return
      }
      let token = name.components(separatedBy: "::")
      let kind: String
      let filename: String
      let source: String?
      if token.count == 1 {
        kind = "Host" // flat queue from the first beta
        filename = token[0]
        source = nil
      } else if token.count == 2, ["Host", "Watch"].contains(token[0]) {
        kind = token[0]
        filename = token[1]
        source = nil
      } else if token.count == 3, ["Host", "Watch"].contains(token[0]),
        token[1].range(of: #"^ProxiedDevice-[a-fA-F0-9]+$"#,
          options: .regularExpression) != nil {
        kind = token[0]
        source = token[1]
        filename = token[2]
      } else { throw TransferError.invalidPayload }
      guard filename == URL(fileURLWithPath: filename).lastPathComponent,
        filename.hasPrefix("Analytics-"), filename.hasSuffix(".ips.ca.synced") else {
        throw TransferError.invalidPayload
      }
      if filename.localizedCaseInsensitiveContains("session") ||
        !Self.looksLikeBatteryLog(plain.dropFirst(2 + nameLength)) {
        Self.appendDebugEvent("Transfer: ignored \(filename), \(plain.count - 2 - nameLength) bytes")
        pendingAck = name
        UserDefaults.standard.set(name, forKey: "MacTransferPendingAck")
        status = MacTransferStatus.text("mt_s_10")
        isReceiving = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.pull() }
        return
      }
      let content = plain.dropFirst(2 + nameLength)
      var folder = try Self.inbox(for: pairing).appendingPathComponent(kind,
        isDirectory: true)
      if let source { folder.appendPathComponent(source, isDirectory: true) }
      try FileManager.default.createDirectory(at: folder,
        withIntermediateDirectories: true)
      let destination = folder.appendingPathComponent(filename)
      if !FileManager.default.fileExists(atPath: destination.path) {
        try Data(content).write(to: destination, options: .atomic)
      }
      Self.appendDebugEvent("Transfer: saved \(filename), \(content.count) bytes")
      var unconfirmed = Self.storedFileIDs(for: unconfirmedKey, pairing: pairing)
      guard let identifier = Self.storedFileID(for: destination, pairing: pairing) else {
        throw TransferError.invalidPayload
      }
      unconfirmed.insert(identifier)
      UserDefaults.standard.set(unconfirmed.sorted(), forKey: unconfirmedKey)
      pendingAck = name
      UserDefaults.standard.set(name, forKey: "MacTransferPendingAck")
      status = MacTransferStatus.text("mt_s_11", kind, filename)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.pull() }
    } catch {
      status = MacTransferStatus.text("mt_s_12", error.localizedDescription)
      isReceiving = false
      connectionPhase = .retrying
      scheduleRetry()
    }
  }

  private func requeueConfirmedFiles(for pairing: MacTransferPairing) {
    var confirmed = Self.storedFileIDs(for: confirmedKey, pairing: pairing)
    var unconfirmed = Self.storedFileIDs(for: unconfirmedKey, pairing: pairing)
    // Files received by the previous beta were already offered for import.
    if UserDefaults.standard.object(forKey: confirmedKey) == nil {
      confirmed.formUnion(allInboxFiles(for: pairing).compactMap {
        Self.storedFileID(for: $0, pairing: pairing)
      }.filter { !unconfirmed.contains($0) })
    }
    // A previous app run can save a file just before its acknowledgement state
    // is persisted. Keep it behind the authenticated terminal reply instead of
    // silently abandoning the file or importing it before the Mac confirms.
    let orphaned = allInboxFiles(for: pairing).filter {
      guard let identifier = Self.storedFileID(for: $0, pairing: pairing) else { return false }
      return !confirmed.contains(identifier) && !unconfirmed.contains(identifier)
    }
    if !orphaned.isEmpty {
      unconfirmed.formUnion(orphaned.compactMap {
        Self.storedFileID(for: $0, pairing: pairing)
      })
      Self.appendDebugEvent("Transfer: recovered \(orphaned.count) saved file(s) awaiting confirmation")
    }
    UserDefaults.standard.set(confirmed.sorted(), forKey: confirmedKey)
    UserDefaults.standard.set(unconfirmed.sorted(), forKey: unconfirmedKey)
    if pendingAck == nil,
      let token = unconfirmed.sorted()
        .compactMap({ Self.fileURL(for: $0, pairing: pairing) })
        .compactMap({ Self.queueToken(for: $0, pairing: pairing) }).first {
      pendingAck = token
      UserDefaults.standard.set(token, forKey: "MacTransferPendingAck")
    }
    enqueueFiles(confirmed.compactMap { Self.fileURL(for: $0, pairing: pairing) },
      for: pairing)
  }

  private static func storedFileIDs(for key: String, pairing: MacTransferPairing) -> Set<String> {
    // Older builds stored absolute sandbox paths. The container UUID may change
    // when the app is updated, so retain only paths found in the current inbox.
    Set((UserDefaults.standard.stringArray(forKey: key) ?? []).compactMap { value in
      let marker = "/MacTransferInbox/\(pairing.physicalDeviceID.uuidString)/"
      let relative: String
      if value.hasPrefix("/") {
        guard let range = value.range(of: marker, options: .caseInsensitive) else { return nil }
        relative = String(value[range.upperBound...])
      } else {
        relative = value
      }
      guard let file = fileURL(for: relative, pairing: pairing) else { return nil }
      return storedFileID(for: file, pairing: pairing)
    })
  }

  private static func fileURL(for identifier: String, pairing: MacTransferPairing) -> URL? {
    guard let folder = try? inbox(for: pairing), !identifier.hasPrefix("/") else { return nil }
    let file = folder.appendingPathComponent(identifier).standardizedFileURL
    guard queueToken(for: file, pairing: pairing) != nil,
      FileManager.default.fileExists(atPath: file.path) else { return nil }
    return file
  }

  private static func storedFileID(for file: URL, pairing: MacTransferPairing) -> String? {
    guard queueToken(for: file, pairing: pairing) != nil,
      let folder = try? inbox(for: pairing) else { return nil }
    let prefix = folder.standardizedFileURL.path + "/"
    return String(file.standardizedFileURL.path.dropFirst(prefix.count))
  }

  private static func queueToken(for file: URL, pairing: MacTransferPairing) -> String? {
    guard let folder = try? inbox(for: pairing) else { return nil }
    let prefix = folder.standardizedFileURL.path + "/"
    guard file.standardizedFileURL.path.hasPrefix(prefix) else { return nil }
    let parts = file.standardizedFileURL.path.dropFirst(prefix.count).split(separator: "/")
    guard let filename = parts.last.map(String.init),
      filename.hasPrefix("Analytics-"), filename.hasSuffix(".ips.ca.synced") else { return nil }
    if parts.count == 1 { return filename }
    if parts.count == 2, ["Host", "Watch"].contains(String(parts[0])) {
      return "\(parts[0])::\(filename)"
    }
    if parts.count == 3, ["Host", "Watch"].contains(String(parts[0])),
      String(parts[1]).range(of: #"^ProxiedDevice-[a-fA-F0-9]+$"#,
        options: .regularExpression) != nil {
      return "\(parts[0])::\(parts[1])::\(filename)"
    }
    return nil
  }

  private func confirmReceivedFiles(for pairing: MacTransferPairing) -> Int {
    let unconfirmed = Self.storedFileIDs(for: unconfirmedKey, pairing: pairing)
    let files = unconfirmed.compactMap { Self.fileURL(for: $0, pairing: pairing) }
      .sorted { $0.path < $1.path }
    var confirmed = Self.storedFileIDs(for: confirmedKey, pairing: pairing)
    confirmed.formUnion(unconfirmed)
    UserDefaults.standard.set(confirmed.sorted(), forKey: confirmedKey)
    UserDefaults.standard.removeObject(forKey: unconfirmedKey)
    enqueueFiles(files, for: pairing)
    return files.count
  }

  private func allInboxFiles(for pairing: MacTransferPairing) -> [URL] {
    guard let folder = try? Self.inbox(for: pairing),
      let enumerator = FileManager.default.enumerator(at: folder,
        includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
    return enumerator.compactMap { $0 as? URL }.filter {
      $0.lastPathComponent.hasPrefix("Analytics-")
    }
  }

  private func enqueueFiles(_ files: [URL], for pairing: MacTransferPairing) {
    var batch: [(url: URL, physicalDeviceID: UUID?)] = []
    for file in files where file.lastPathComponent.hasPrefix("Analytics-") {
      if file.lastPathComponent.localizedCaseInsensitiveContains("session") ||
        (try? Data(contentsOf: file, options: .mappedIfSafe)).map({ !Self.looksLikeBatteryLog($0) }) == true {
        try? FileManager.default.removeItem(at: file)
        continue
      }
      batch.append((file, Self.sourcePhysicalID(for: file, pairing: pairing)))
    }
    SharedImportQueue.shared.enqueueBatch(batch.sorted { $0.url.path < $1.url.path })
  }

  private static func sourcePhysicalID(for file: URL, pairing: MacTransferPairing) -> UUID? {
    let parts = file.pathComponents
    guard let watchIndex = parts.firstIndex(of: "Watch") else {
      return pairing.physicalDeviceID
    }
    guard parts.indices.contains(watchIndex + 1) else { return nil }
    let source = parts[watchIndex + 1]
    guard source.range(of: #"^ProxiedDevice-[a-fA-F0-9]+$"#,
      options: .regularExpression) != nil else { return nil }
    let digest = SHA256.hash(data: Data("\(pairing.physicalDeviceID.uuidString)|\(source)".utf8))
    var bytes = Array(digest.prefix(16))
    bytes[6] = (bytes[6] & 0x0f) | 0x50
    bytes[8] = (bytes[8] & 0x3f) | 0x80
    return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5],
      bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12],
      bytes[13], bytes[14], bytes[15]))
  }

  private static func looksLikeBatteryLog(_ bytes: Data) -> Bool {
    var lines = 0
    for byte in bytes where byte == 10 {
      lines += 1
      if lines >= 100 { break }
    }
    guard lines >= 100 else { return false }
    return ["last_value_CycleCount", "last_value_NominalChargeCapacity",
      "last_value_AppleRawMaxCapacity"].allSatisfy {
        bytes.range(of: Data($0.utf8)) != nil
      }
  }

  func supportDiagnosticsData() -> Data {
    let defaults = UserDefaults.standard
    var recentEvents = Array(Self.debugEvents().suffix(30))
    var object: [String: Any] = [
      "schema": 1,
      "generatedAt": ISO8601DateFormatter().string(from: Date()),
      "platform": "iOS",
      "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
      "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
      "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
      "deviceModel": DeviceLibrary.localModelIdentifier() ?? "unknown",
      "paired": pairing != nil,
      "receiving": isReceiving,
      "unconfirmedFiles": defaults.stringArray(forKey: unconfirmedKey)?.count ?? 0,
      "confirmedFiles": defaults.stringArray(forKey: confirmedKey)?.count ?? 0,
      "pendingAcknowledgement": pendingAck != nil,
      "recentEvents": recentEvents
    ]
    while true {
      let data = (try? JSONSerialization.data(withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys])) ?? Data("{}".utf8)
      if data.count <= 8_192 || recentEvents.isEmpty { return data }
      recentEvents.removeFirst()
      object["recentEvents"] = recentEvents
    }
  }

  func latestMacDiagnosticsData() -> Data? {
    UserDefaults.standard.data(forKey: macDiagnosticsKey)
  }

  func debugLogText() -> String { Self.debugEvents().joined(separator: "\n") }

  func macDebugLogText() -> String {
    guard let report = latestMacDiagnosticsData(),
      let object = try? JSONSerialization.jsonObject(with: report) as? [String: Any],
      let events = object["recentEvents"] as? [String] else { return "" }
    return events.joined(separator: "\n")
  }

  private static func debugEvents() -> [String] {
    UserDefaults.standard.stringArray(forKey: debugEventsKey) ?? []
  }

  private static func appendDebugEvent(_ message: String) {
    let normalized = String(message.replacingOccurrences(of: "\n", with: " ").prefix(140))
    var events = debugEvents()
    guard events.last?.hasSuffix(" | \(normalized)") != true else { return }
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = .autoupdatingCurrent
    events.append("\(formatter.string(from: Date())) | \(normalized)")
    if events.count > 80 { events.removeFirst(events.count - 80) }
    UserDefaults.standard.set(events, forKey: debugEventsKey)
  }

  static func inbox(for pairing: MacTransferPairing) throws -> URL {
    let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("MacTransferInbox", isDirectory: true)
      .appendingPathComponent(pairing.physicalDeviceID.uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    return base
  }

  private static func loadPairing() -> MacTransferPairing? {
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "net.ryuya-dev.MochiLog.mac-pairing",
      kSecAttrAccount as String: "active", kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data else { return nil }
    return try? JSONDecoder().decode(MacTransferPairing.self, from: data)
  }

  private static func savePairing(_ pair: MacTransferPairing) throws {
    let data = try JSONEncoder().encode(pair)
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "net.ryuya-dev.MochiLog.mac-pairing",
      kSecAttrAccount as String: "active"]
    let update: [String: Any] = [kSecValueData as String: data]
    let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
    if status == errSecItemNotFound {
      var add = query
      add[kSecValueData as String] = data
      add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else {
        throw TransferError.keychain
      }
    } else if status != errSecSuccess {
      throw TransferError.keychain
    }
  }
}

@available(iOS 27, *)
private enum PairingTransport {
  nonisolated static func exchange(routes: [NWEndpoint], payload: Data,
    allowCellular: Bool) async throws -> Data {
    try await Task.detached(priority: .userInitiated) {
      var lastError: Error = TransferError.invalidPairing
      for route in routes {
        do { return try exchange(on: route, payload: payload, allowCellular: allowCellular) }
        catch TransferError.invalidPairing { throw TransferError.invalidPairing }
        catch { lastError = error }
      }
      throw lastError
    }.value
  }

  nonisolated private static func exchange(on route: NWEndpoint, payload: Data,
    allowCellular: Bool) throws -> Data {
    let parameters = NWParameters.tcp
    if !allowCellular { parameters.prohibitedInterfaceTypes = [.cellular] }
    let connection = NWConnection(to: route, using: parameters)
    let queue = DispatchQueue(label: "net.ryuya-dev.MochiLog.pairing")
    let finished = DispatchSemaphore(value: 0)
    var response = Data()
    var failure: Error?
    var completed = false
    func finish(_ error: Error? = nil) {
      guard !completed else { return }
      completed = true
      failure = error
      finished.signal()
    }
    func receive() {
      connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) {
        data, _, complete, error in
        if let data { response.append(data) }
        if response.count > 16_384 { finish(TransferError.invalidPayload); return }
        if let error { finish(error) }
        else if complete { finish() }
        else { receive() }
      }
    }
    connection.stateUpdateHandler = { state in
      switch state {
      case .ready:
        connection.send(content: payload + Data([10]),
          completion: .contentProcessed { error in
            if let error { finish(error) } else { receive() }
          })
      case .failed(let error): finish(error)
      default: break
      }
    }
    connection.start(queue: queue)
    queue.asyncAfter(deadline: .now() + 10) {
      finish(URLError(.timedOut))
      connection.cancel()
    }
    finished.wait()
    connection.cancel()
    if let failure { throw failure }
    guard let newline = response.firstIndex(of: 10) else {
      throw TransferError.invalidPairing
    }
    return Data(response[..<newline])
  }
}

enum TransferError: LocalizedError {
  case invalidPairing, invalidPairingCode, wrongDevice, invalidPayload, keychain, identityConflict
  var errorDescription: String? {
    switch self {
    case .invalidPairing: MacTransferStatus.text("mt_s_13")
    case .invalidPairingCode: MacTransferStatus.text("mt_secure_pair_wrong_code")
    case .wrongDevice: MacTransferStatus.text("mt_s_14")
    case .invalidPayload: MacTransferStatus.text("mt_s_15")
    case .keychain: MacTransferStatus.text("mt_s_16")
    case .identityConflict: MacTransferStatus.text("mt_s_17")
    }
  }
}

private enum MacTransferStatus {
  static func text(_ key: String, _ args: CVarArg...) -> String {
    String(format: L10n.text(key, table: "MacTransfer"), locale: L10n.locale, arguments: args)
  }
}
