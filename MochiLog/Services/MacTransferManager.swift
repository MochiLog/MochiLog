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
  var platform: String? = nil
  var lanAddresses: [String]? = nil
  var lanPort: UInt16? = nil
  var manualHostAddress: String? = nil
}

private struct DailyTransferReceipt: Codable {
  var day: String
  var hostReceived = false
  var watchSources: Set<String> = []
  var terminalHosts: Set<String> = []
  var pausedHosts: Set<String> = []
}

@available(iOS 27, *)
struct SecureMacPairingCandidate: Identifiable {
  let pairing: MacTransferPairing
  let sessionID: UUID
  let clientPublicKey: Data
  let routes: [NWEndpoint]
  let relinkLocalRecords: Bool
  let protocolVersion: String
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
  @Published private(set) var pairings: [MacTransferPairing] = []
  @Published private(set) var pendingRevocations: [MacTransferPairing] = []
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
  private var revocationTimer: Timer?
  private var isSendingRevocations = false
  private var retryDelay: UInt64 = 5
  private var isRunning = false
  private var connection: NWConnection?
  private var activeRequestNonce: UUID?
  private var activePauseUntil: String?
  private var activeResume = false
  private var manualReceive = false
  private var debugSyncBurst = 0
  private var debugManifestSnapshot: [String: Int]?
  private var debugManifestCapturedAt: Date?
  private var lastAutomaticHold: String?
  private var skippedHostKeys: Set<String> = []
  private var watchRegistration: AnyCancellable?
  private var watchOSPairing: AnyCancellable?
  private var endpoint: NWEndpoint?
  private var directRoutes: [NWEndpoint] = []
  private var routeIndex = 0
  private var accumulated = Data()
  private var pendingAck: String?
  private var unconfirmedKey: String { scopedKey("MacTransferUnconfirmedFiles") }
  private var confirmedKey: String { scopedKey("MacTransferConfirmedFiles") }
  private var macDiagnosticsKey: String { scopedKey("MacTransferLastMacDiagnostics") }
  private var pendingAckKey: String { scopedKey("MacTransferPendingAck") }
  private static let debugEventsKey = "MacTransferDebugEvents"
  private static let debugRetentionKey = "MacTransferDebugRetentionDays"
  private static let debugMigratedKey = "MacTransferDebugArchiveMigrated"
  private static let dailyReceiptKey = "MacTransferDailyReceipt"

  private init() {
    pairings = Self.loadPairings()
    pendingRevocations = Self.loadStoredPairings(account: "revoked-hosts")
    pairing = pairings.first
    status = MacTransferStatus.text(pairing == nil ? "mt_s_00" : "mt_s_01")
    connectionPhase = pairing == nil ? .needsPairing : .checkingNetwork
    pendingAck = UserDefaults.standard.string(forKey: pendingAckKey)
    watchRegistration = AppSettings.shared.$registeredWatches.dropFirst().sink { [weak self] watches in
      Task { @MainActor [weak self] in
        guard let self, self.isRunning else { return }
        Self.appendDebugEvent("Watch registration changed: \(watches.count) model(s); daily collection reevaluated")
        self.beginDiscovery()
      }
    }
    watchOSPairing = WatchConnectivityManager.shared.$isWatchPaired.dropFirst().sink {
      [weak self] isPaired in
      Task { @MainActor [weak self] in
        guard let self, self.isRunning else { return }
        Self.appendDebugEvent("OS Watch pairing changed: \(isPaired.map { String(describing: $0) } ?? "unknown"); daily collection reevaluated")
        self.beginDiscovery()
      }
    }
  }

  private static func japanCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return calendar
  }

  private static func japanDay(_ date: Date = Date()) -> String {
    let parts = japanCalendar().dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0,
      parts.month ?? 0, parts.day ?? 0)
  }

  private static func nextCollectionWindow(_ date: Date = Date()) -> Date {
    japanCalendar().nextDate(after: date, matching: DateComponents(hour: 9),
      matchingPolicy: .nextTime) ?? date.addingTimeInterval(24 * 60 * 60)
  }

  private static func localTime(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = .autoupdatingCurrent
    return formatter.string(from: date)
  }

  private var dailyReceipt: DailyTransferReceipt {
    get {
      let day = Self.japanDay()
      guard let data = UserDefaults.standard.data(forKey: Self.dailyReceiptKey),
        let receipt = try? JSONDecoder().decode(DailyTransferReceipt.self, from: data),
        receipt.day == day else { return DailyTransferReceipt(day: day) }
      return receipt
    }
    set {
      if let data = try? JSONEncoder().encode(newValue) {
        UserDefaults.standard.set(data, forKey: Self.dailyReceiptKey)
      }
    }
  }

  private func expectedWatchCount() -> Int? {
    // OS pairing and MochiLog registration are different. An unregistered
    // paired Watch may still produce a log that needs to reach the import flow.
    // Wait for WatchConnectivity to finish activation before deciding that
    // an iPhone has no Watch. iPad never expects a Watch log.
    if UIDevice.current.userInterfaceIdiom == .pad {
      return 0
    }
    guard let isPaired = WatchConnectivityManager.shared.isWatchPaired else { return nil }
    return isPaired ? max(1, AppSettings.shared.registeredWatches.count) : 0
  }

  private func dailyComplete(_ receipt: DailyTransferReceipt) -> Bool {
    guard let expectedWatches = expectedWatchCount() else { return false }
    return receipt.hostReceived && receipt.watchSources.count >= expectedWatches
  }

  private func automaticWait() -> UInt64? {
    let now = Date()
    if Self.japanCalendar().component(.hour, from: now) < 9 {
      return UInt64(max(1, Self.nextCollectionWindow(now).timeIntervalSince(now).rounded(.up)))
    }
    let receipt = dailyReceipt
    if dailyComplete(receipt) && pairings.allSatisfy({
      receipt.pausedHosts.contains($0.hostID.uuidString)
    }) {
      return UInt64(max(1, Self.nextCollectionWindow(now).timeIntervalSince(now).rounded(.up)))
    }
    return nil
  }

  private func recordConfirmedFiles(for pairing: MacTransferPairing) {
    let day = Self.japanDay()
    let identifiers = Self.storedFileIDs(for: unconfirmedKey, pairing: pairing)
    var receipt = dailyReceipt
    let previous = receipt
    for identifier in identifiers {
      let parts = identifier.split(separator: "/").map(String.init)
      guard let filename = parts.last, filename.hasPrefix("Analytics-\(day)-") else {
        continue
      }
      if parts.first == "Host" || parts.count == 1 {
        receipt.hostReceived = true
      } else if parts.first == "Watch" {
        receipt.watchSources.insert(parts.count == 3 ? parts[1] : "legacy-watch")
      }
    }
    receipt.terminalHosts.insert(pairing.hostID.uuidString)
    dailyReceipt = receipt
    if !previous.hostReceived && receipt.hostReceived {
      Self.appendDebugEvent("Daily receipt: own-device log confirmed for \(day)")
    }
    if receipt.watchSources.count > previous.watchSources.count {
      Self.appendDebugEvent("Daily receipt: Watch sources \(receipt.watchSources.count) for \(day)")
    }
    if !previous.terminalHosts.contains(pairing.hostID.uuidString) {
      Self.appendDebugEvent("Transfer queue drained and confirmed by computer \(pairing.hostID.uuidString)")
    }
    if !dailyComplete(previous) && dailyComplete(receipt) {
      Self.appendDebugEvent("Daily collection condition met for \(day): own-device log and \(receipt.watchSources.count) Watch source(s)")
    } else if receipt.hostReceived,
      (!previous.hostReceived || receipt.watchSources.count > previous.watchSources.count) {
      let expected = expectedWatchCount().map(String.init) ?? "unknown"
      Self.appendDebugEvent("Daily collection continues for \(day): Watch sources \(receipt.watchSources.count)/\(expected)")
    }
  }

  func observeSavedRecords(_ records: [BatteryRecord]) {
    guard !dailyReceipt.hostReceived, let physicalID = pairing?.physicalDeviceID else {
      return
    }
    let day = Self.japanDay()
    guard records.contains(where: {
      $0.physicalDeviceID == physicalID && Self.japanDay($0.logDate) == day &&
        !($0.osVersion?.lowercased().contains("watch") ?? false)
    }) else { return }
    var receipt = dailyReceipt
    receipt.hostReceived = true
    dailyReceipt = receipt
    Self.appendDebugEvent("Daily receipt: today's own-device log was already saved for \(day)")
    if isRunning, connection == nil, networkPermitsTransfer { beginDiscovery() }
  }

  private func scopedKey(_ base: String) -> String {
    guard let pairing else { return base }
    // Keep the original Mac beta's saved inbox and acknowledgements intact.
    if UserDefaults.standard.string(forKey: "MacTransferLegacyHostID") == pairing.hostID.uuidString {
      return base
    }
    return "\(base).\(pairing.hostID.uuidString)"
  }

  func selectPairing(_ hostID: UUID) {
    guard let selected = pairings.first(where: { $0.hostID == hostID }),
      pairing?.hostID != hostID else { return }
    stop()
    pairing = selected
    pendingAck = UserDefaults.standard.string(forKey: pendingAckKey)
    lastAuthenticatedContactAt = nil
    status = MacTransferStatus.text("mt_s_01")
    start()
  }

  func unpair(_ hostID: UUID) throws {
    guard let removed = pairings.first(where: { $0.hostID == hostID }) else { return }
    let oldPending = pendingRevocations
    let pending = oldPending.filter { $0.hostID != hostID } + [removed]
    try Self.saveStoredPairings(pending, account: "revoked-hosts")
    let remaining = pairings.filter { $0.hostID != hostID }
    do { try Self.savePairings(remaining) }
    catch {
      try? Self.saveStoredPairings(oldPending, account: "revoked-hosts")
      throw error
    }
    let wasSelected = pairing?.hostID == hostID
    if wasSelected { stop() }
    pairings = remaining
    pendingRevocations = pending
    if wasSelected {
      pairing = remaining.first
      pendingAck = UserDefaults.standard.string(forKey: pendingAckKey)
      lastAuthenticatedContactAt = nil
      status = MacTransferStatus.text(pairing == nil ? "mt_s_00" : "mt_s_01")
      if pairing != nil { start() }
      else { connectionPhase = .needsPairing }
    }
    Self.appendDebugEvent("MochiLog pairing removed locally; notifying computer when reachable")
    Task { await retryPendingRevocations() }
    startRevocationTimer()
  }

  private func startRevocationTimer() {
    guard revocationTimer == nil, !pendingRevocations.isEmpty else { return }
    revocationTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) {
      [weak self] _ in
      Task { @MainActor in await self?.retryPendingRevocations() }
    }
  }

  private func retryPendingRevocations() async {
    guard !isSendingRevocations, !pendingRevocations.isEmpty else { return }
    isSendingRevocations = true
    defer { isSendingRevocations = false }
    for removed in pendingRevocations {
      // A new QR pairing has a different key; an old tombstone may never
      // revoke it. Only notify the computer for the original secret.
      guard !pairings.contains(where: { $0.hostID == removed.hostID }) else { continue }
      let port = NWEndpoint.Port(rawValue: removed.lanPort ??
        (removed.platform == "windows" ? 54556 : 54555))
      var routes: [NWEndpoint] = []
      if let address = removed.manualHostAddress,
        let ip = IPv4Address(address), let port {
        routes.append(.hostPort(host: .ipv4(ip), port: port))
      }
      if let port {
        for address in removed.lanAddresses ?? [] {
          if let ip = IPv4Address(address) {
            routes.append(.hostPort(host: .ipv4(ip), port: port))
          }
        }
      }
      if let route = Self.tailnetRoute(address: removed.tailnetAddress,
        port: removed.tailnetPort) { routes.append(route) }
      // Resolve the current LAN address even when the last pairing was
      // removed and there is no active transfer browser anymore.
      routes.append(.service(name: removed.hostID.uuidString,
        type: "_mochilog._tcp", domain: "local.", interface: nil))
      guard !routes.isEmpty else { continue }
      let nonce = UUID()
      let identity = "\(removed.hostID.uuidString)|\(removed.physicalDeviceID.uuidString)|\(nonce.uuidString)"
      let proof = Self.authenticationCode("unpair|v1|\(identity)", secret: removed.secret)
      let request: [String: String] = [
        "type": "unpair", "version": "1", "hostID": removed.hostID.uuidString,
        "physicalDeviceID": removed.physicalDeviceID.uuidString,
        "nonce": nonce.uuidString, "proof": proof
      ]
      guard let payload = try? JSONSerialization.data(withJSONObject: request),
        let response = try? await PairingTransport.exchange(routes: routes,
          payload: payload, allowCellular: allowsCellularTransfer,
          continueOnInvalidResponse: true),
        let answer = try? JSONSerialization.jsonObject(with: response) as? [String: String],
        answer["type"] == "unpair-ack", answer["nonce"] == nonce.uuidString,
        answer["proof"] == Self.authenticationCode("unpair-ack|v1|\(identity)",
          secret: removed.secret) else { continue }
      let updated = pendingRevocations.filter { $0.hostID != removed.hostID }
      guard (try? Self.saveStoredPairings(updated, account: "revoked-hosts")) != nil
      else { continue }
      pendingRevocations = updated
      Self.appendDebugEvent("Computer confirmed MochiLog pairing removal")
    }
    if pendingRevocations.isEmpty {
      revocationTimer?.invalidate()
      revocationTimer = nil
    }
  }

  private func advancePairing() {
    guard let current = pairing,
      let index = pairings.firstIndex(where: { $0.hostID == current.hostID }),
      pairings.count > 1 else {
      scheduleReconnect(after: 60)
      return
    }
    let next = pairings[(index + 1) % pairings.count]
    Self.appendDebugEvent("Connection: switching computer to \(next.hostID.uuidString)")
    selectPairing(next.hostID)
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

  func setManualHostAddress(_ address: String?) throws {
    guard var current = pairing,
      let index = pairings.firstIndex(where: { $0.hostID == current.hostID }) else { return }
    let value = address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !value.isEmpty {
      guard IPv4Address(value) != nil, value != "0.0.0.0",
        !value.hasPrefix("127.") else { throw TransferError.invalidPairing }
    }
    current.manualHostAddress = value.isEmpty ? nil : value
    var updated = pairings
    updated[index] = current
    try Self.savePairings(updated)
    pairings = updated
    pairing = current
    Self.appendDebugEvent(current.manualHostAddress == nil
      ? "Manual computer address cleared" : "Manual computer address set")
    if isRunning, networkPermitsTransfer { beginDiscovery() }
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
    activePauseUntil = nil
    activeResume = false
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
    guard let version = values["v"], ["2", "3"].contains(version),
      let host = values["host"].flatMap(UUID.init(uuidString:)),
      let session = values["session"].flatMap(UUID.init(uuidString:)),
      let model = values["model"],
      let macPublicBytes = values["public"].flatMap({ Data(base64Encoded: $0) }),
      macPublicBytes.count == 32,
      let macPublic = try? Curve25519.KeyAgreement.PublicKey(
        rawRepresentation: macPublicBytes),
      let port = values["port"].flatMap(UInt16.init), port != 0,
      let endpointPort = NWEndpoint.Port(rawValue: port)
    else { throw TransferError.invalidPairing }
    guard model == DeviceLibrary.localModelIdentifier() else {
      throw TransferError.wrongDevice
    }
    let storedID = PhysicalDeviceIdentityStore.stored()
    let previousID = storedID ?? PhysicalDeviceIdentityStore.current()
    let device: UUID
    if version == "3" {
      let invited = values["device"].flatMap(UUID.init(uuidString:))
      if let invited, storedID != nil, invited != previousID && !relinkLocalRecords {
        throw TransferError.identityConflict
      }
      device = storedID == nil ? (invited ?? previousID) :
        (relinkLocalRecords ? (invited ?? previousID) : previousID)
    }
    else if let invited = values["device"].flatMap(UUID.init(uuidString:)) {
      device = invited
    } else { throw TransferError.invalidPairing }
    if version == "2", previousID != device && !relinkLocalRecords &&
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
      sharedInfo: Data("MochiLog pair v\(version)|\(host.uuidString)|\(device.uuidString)".utf8),
      outputByteCount: 32)
    let secret = derived.withUnsafeBytes { Data($0) }
    let initiation = try JSONSerialization.data(withJSONObject: [
      "type": "pair-init", "sessionID": session.uuidString,
      "version": version,
      "clientPublicKey": clientPublic.base64EncodedString(),
      "physicalDeviceID": device.uuidString
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
    var pair = MacTransferPairing(hostID: host, physicalDeviceID: device,
      model: model, secret: secret,
      tailnetAddress: values["tailnet"], tailnetPort: tailnetPort)
    pair.platform = values["platform"] == "windows" ? "windows" : "macOS"
    pair.lanAddresses = (values["ipv4"] ?? "").split(separator: ",")
      .map(String.init).filter(Self.isPrivateLANAddress)
    pair.lanPort = port
    return SecureMacPairingCandidate(pairing: pair, sessionID: session,
      clientPublicKey: clientPublic, routes: routes,
      relinkLocalRecords: relinkLocalRecords, protocolVersion: version)
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
      "version": candidate.protocolVersion,
      "clientPublicKey": candidate.clientPublicKey.base64EncodedString(),
      "physicalDeviceID": candidate.pairing.physicalDeviceID.uuidString,
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
    if pairings.isEmpty {
      UserDefaults.standard.set(pair.hostID.uuidString, forKey: "MacTransferLegacyHostID")
    }
    var updated = pairings.filter { $0.hostID != pair.hostID }
    updated.append(pair)
    let revoked = pendingRevocations.filter { $0.hostID != pair.hostID }
    try Self.saveStoredPairings(revoked, account: "revoked-hosts")
    try Self.savePairings(updated)
    pendingRevocations = revoked
    pairings = updated
    pairing = pair
    pendingAck = UserDefaults.standard.string(forKey: pendingAckKey)
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
    startRevocationTimer()
    Task { await retryPendingRevocations() }
    guard pairing != nil else { return }
    guard !isRunning else { return }
    isRunning = true
    Self.appendDebugEvent("Automatic receive started: app active; waiting for network path")
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
        Self.appendDebugEvent("Network path changed: Wi-Fi \(self.networkUsesWiFiOrEthernet), cellular \(path.usesInterfaceType(.cellular)); automatic reconnect triggered")
        self.retryDelay = 5
        self.beginDiscovery()
      }
    }
    monitor.start(queue: queue)
  }

  func receiveNow() {
    guard pairing != nil, !isReceiving else { return }
    manualReceive = true
    debugSyncBurst = 0
    debugManifestSnapshot = nil
    debugManifestCapturedAt = nil
    Self.appendDebugEvent("Manual receive triggered; automatic daily hold bypassed")
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
    if !manualReceive {
      if let wait = automaticWait() {
        let reason = Self.japanCalendar().component(.hour, from: Date()) < 9
          ? "waiting for the daily collection window" : "all required logs received and computers acknowledged"
        let key = "\(Self.japanDay())|\(reason)"
        if lastAutomaticHold != key {
          Self.appendDebugEvent("Automatic receive stopped: \(reason); resumes \(Self.localTime(Self.nextCollectionWindow()))")
          lastAutomaticHold = key
        }
        browser?.cancel(); browser = nil
        connection?.cancel(); connection = nil
        isReceiving = false
        scheduleReconnect(after: wait, interruptActive: true)
        return
      }
      if dailyComplete(dailyReceipt),
        dailyReceipt.pausedHosts.contains(pairing.hostID.uuidString) {
        let key = "\(Self.japanDay())|\(pairing.hostID.uuidString)"
        if skippedHostKeys.insert(key).inserted {
          Self.appendDebugEvent("Automatic receive skipped for computer \(pairing.hostID.uuidString): daily pause acknowledged")
        }
        advancePairing()
        return
      }
    }
    if !manualReceive, lastAutomaticHold != nil {
      Self.appendDebugEvent("Automatic receive resumed: daily hold ended or requirements changed")
      lastAutomaticHold = nil
    }
    reconnectTask?.cancel()
    reconnectTask = nil
    browser?.cancel()
    browser = nil
    connection?.cancel()
    connection = nil
    activeRequestNonce = nil
    activePauseUntil = nil
    activeResume = false
    accumulated = Data()
    endpoint = nil
    directRoutes = []
    routeIndex = 0
    isReceiving = false
    connectionPhase = .searching
    requeueConfirmedFiles(for: pairing)
    if let address = pairing.manualHostAddress,
      let ipv4 = IPv4Address(address),
      let port = NWEndpoint.Port(rawValue: pairing.lanPort ??
        (pairing.platform == "windows" ? 54556 : 54555)) {
      directRoutes.append(.hostPort(host: .ipv4(ipv4), port: port))
    }
    if let lanPort = pairing.lanPort,
      let endpointPort = NWEndpoint.Port(rawValue: lanPort) {
      directRoutes += (pairing.lanAddresses ?? []).compactMap { address in
        guard let ipv4 = IPv4Address(address), Self.isPrivateLANAddress(address) else {
          return nil
        }
        return .hostPort(host: .ipv4(ipv4), port: endpointPort)
      }
    }
    if let route = Self.tailnetRoute(address: pairing.tailnetAddress,
      port: pairing.tailnetPort) {
      directRoutes.append(route)
    }
    routeIndex = 0
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
          var all = self.pairings
          if let index = all.firstIndex(where: { $0.hostID == updated.hostID }) {
            all[index] = updated
            if (try? Self.savePairings(all)) != nil {
              self.pairings = all
              self.pairing = updated
            }
          }
        }
        var newRoutes = Self.routes(from: result.metadata)
        if let address = self.pairing?.manualHostAddress,
          let ipv4 = IPv4Address(address),
          let port = NWEndpoint.Port(rawValue: self.pairing?.lanPort ??
            (self.pairing?.platform == "windows" ? 54556 : 54555)) {
          newRoutes.insert(.hostPort(host: .ipv4(ipv4), port: port), at: 0)
        }
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
    if seconds > 300 {
      Self.appendDebugEvent("Automatic reconnect scheduled for \(Self.localTime(Date().addingTimeInterval(TimeInterval(seconds))))")
    }
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
    if pairings.count > 1 {
      reconnectTask?.cancel()
      let delay = retryDelay
      reconnectTask = Task { [weak self] in
        do { try await Task.sleep(nanoseconds: delay * 1_000_000_000) }
        catch { return }
        guard let self, self.isRunning, self.connection == nil else { return }
        self.advancePairing()
      }
    } else { scheduleReconnect(after: retryDelay) }
    retryDelay = min(retryDelay * 2, 60)
  }

  func stop() {
    isRunning = false
    revocationTimer?.invalidate()
    revocationTimer = nil
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
    Self.appendDebugEvent("Automatic receive stopped: app entered background; collection state rechecked when active")
    let shouldSendPresence = automaticWait() == nil
    let pairing = pairing
    let route = routeIndex < directRoutes.count ? directRoutes[routeIndex]
      : (endpoint ?? Self.tailnetRoute(
        address: pairing?.tailnetAddress, port: pairing?.tailnetPort))
    let mayUseCellular = allowsCellularTransfer
    let wasRunning = isRunning
    stop()
    guard shouldSendPresence, wasRunning, let pairing, let route else { return }
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
    var request: [String: String] = [
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
    let receipt = dailyReceipt
    let pauseUntil: String? = !manualReceive && pendingAck == nil &&
      !debugArchiveNeedsSync() &&
      dailyComplete(receipt) &&
      receipt.terminalHosts.contains(pairing.hostID.uuidString) &&
      !receipt.pausedHosts.contains(pairing.hostID.uuidString)
      ? String(Int(Self.nextCollectionWindow().timeIntervalSince1970)) : nil
    if let pauseUntil {
      Self.appendDebugEvent("Requesting daily pause from computer \(pairing.hostID.uuidString) until \(Self.localTime(Date(timeIntervalSince1970: TimeInterval(pauseUntil) ?? 0)))")
      request["dailyPauseUntil"] = pauseUntil
      request["dailyPauseMAC"] = Self.authenticationCode(
        "daily-pause|v1|\(pairing.hostID.uuidString)|\(pairing.physicalDeviceID.uuidString)|\(nonce.uuidString)|\(pauseUntil)",
        secret: pairing.secret)
    }
    let resume = !dailyComplete(receipt) &&
      receipt.pausedHosts.contains(pairing.hostID.uuidString)
    if resume {
      Self.appendDebugEvent("Requesting daily collection resume from computer \(pairing.hostID.uuidString): required logs changed")
      request["dailyResumeMAC"] = Self.authenticationCode(
        "daily-resume|v1|\(pairing.hostID.uuidString)|\(pairing.physicalDeviceID.uuidString)|\(nonce.uuidString)",
        secret: pairing.secret)
    }
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
    activePauseUntil = pauseUntil
    activeResume = resume
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
    defer {
      connection.cancel(); self.connection = nil
      activeRequestNonce = nil; activePauseUntil = nil; activeResume = false
    }
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
        if let control = try? JSONSerialization.jsonObject(with: report) as? [String: String],
          control["type"] == "unpair" {
          do { try unpair(pairing.hostID) }
          catch { Self.appendDebugEvent("Pairing removal could not be saved: \(error.localizedDescription)") }
          isReceiving = false
          return
        }
        if let control = try? JSONSerialization.jsonObject(with: report) as? [String: String],
          control["type"] == "daily-pause-ack",
          control["until"] == activePauseUntil {
          var receipt = dailyReceipt
          receipt.pausedHosts.insert(pairing.hostID.uuidString)
          dailyReceipt = receipt
          manualReceive = false
          isReceiving = false
          connectionPhase = .available
          Self.appendDebugEvent("Automatic collection paused by computer \(pairing.hostID.uuidString) until \(Self.localTime(Date(timeIntervalSince1970: TimeInterval(control["until"] ?? "") ?? 0))); receipt confirmed")
          if let wait = automaticWait() { scheduleReconnect(after: wait) }
          else { advancePairing() }
          return
        }
        if let control = try? JSONSerialization.jsonObject(with: report) as? [String: String],
          control["type"] == "daily-resume-ack", activeResume {
          var receipt = dailyReceipt
          receipt.pausedHosts.remove(pairing.hostID.uuidString)
          dailyReceipt = receipt
          isReceiving = false
          Self.appendDebugEvent("Automatic collection resumed by computer \(pairing.hostID.uuidString): required logs changed")
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.isRunning,
              self.pairing?.hostID == pairing.hostID else { return }
            self.pull()
          }
          return
        }
        if !report.isEmpty, report.count <= 16_384,
          let object = try? JSONSerialization.jsonObject(with: report) as? [String: Any],
          object["schema"] as? Int == 1,
          ["macOS", "Windows"].contains(object["platform"] as? String ?? "") {
          if let chunk = object["archiveChunk"] as? [String: Any] {
            Self.receiveArchiveChunk(chunk, from: pairing.hostID)
          }
          var saved = object
          saved.removeValue(forKey: "archiveChunk")
          if let data = try? JSONSerialization.data(withJSONObject: saved) {
            UserDefaults.standard.set(data, forKey: macDiagnosticsKey)
          }
        }
        recordConfirmedFiles(for: pairing)
        let confirmedCount = confirmReceivedFiles(for: pairing)
        Self.appendDebugEvent("Transfer: confirmed \(confirmedCount) received file(s)")
        if pendingAck != nil {
          pendingAck = nil
          UserDefaults.standard.removeObject(forKey: pendingAckKey)
        }
        status = confirmedCount == 0 ? MacTransferStatus.text("mt_s_08")
          : MacTransferStatus.text("mt_s_09", confirmedCount)
        isReceiving = false
        manualReceive = false
        connectionPhase = .available
        retryDelay = 5
        if debugArchiveNeedsSync() {
          debugSyncBurst += 1
          if debugSyncBurst == 1 || debugSyncBurst % 25 == 0 {
            Self.appendDebugEvent("Debug archive sync: continuing with computer \(pairing.hostID.uuidString), batch \(debugSyncBurst)")
          }
          let delay: TimeInterval = debugSyncBurst % 25 == 0 ? 10 : 0.3
          DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.isRunning,
              self.pairing?.hostID == pairing.hostID else { return }
            self.pull()
          }
          return
        }
        debugSyncBurst = 0
        if activePauseUntil != nil {
          Self.appendDebugEvent("Computer did not acknowledge automatic pause")
        } else if dailyComplete(dailyReceipt),
          !dailyReceipt.pausedHosts.contains(pairing.hostID.uuidString) {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.isRunning,
              self.pairing?.hostID == pairing.hostID else { return }
            self.pull()
          }
          return
        }
        if let wait = automaticWait() {
          scheduleReconnect(after: wait)
          return
        }
        if pairings.count > 1 {
          // Poll the next computer after an idle interval. Without this delay,
          // two paired computers with empty queues cause a request loop.
          DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            guard let self, self.isRunning,
              self.pairing?.hostID == pairing.hostID else { return }
            self.advancePairing()
          }
        } else { scheduleReconnect(after: 60) }
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
        UserDefaults.standard.set(name, forKey: pendingAckKey)
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
      UserDefaults.standard.set(name, forKey: pendingAckKey)
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
      UserDefaults.standard.set(token, forKey: pendingAckKey)
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
    object["lastAppDiagnostic"] = CrashDiagnostics.shared.summary()
    if debugManifestSnapshot == nil ||
      Date().timeIntervalSince(debugManifestCapturedAt ?? .distantPast) > 600 {
      debugManifestSnapshot = Self.archiveManifest(in: Self.debugArchiveDirectory)
      debugManifestCapturedAt = Date()
    }
    object["archiveManifest"] = debugManifestSnapshot ?? [:]
    if manualReceive && debugSyncBurst == 0 { object["archiveRefresh"] = true }
    if let pairing,
      let report = latestMacDiagnosticsData(),
      let remote = try? JSONSerialization.jsonObject(with: report) as? [String: Any] {
      if let manifest = remote["archiveManifest"] as? [String: Int],
        let request = Self.archiveRequest(manifest: manifest,
          directory: Self.computerArchiveDirectory(for: pairing.hostID)) {
        object["archiveRequest"] = request
      }
      if let request = remote["archiveRequest"] as? [String: Any],
        let chunk = Self.archiveChunk(request: request,
          directory: Self.debugArchiveDirectory, limit: 3_072) {
        object["archiveChunk"] = chunk
      }
    }
    while true {
      let data = (try? JSONSerialization.data(withJSONObject: object,
        options: [.sortedKeys])) ?? Data("{}".utf8)
      if data.count <= 8_192 { return data }
      if !recentEvents.isEmpty {
        recentEvents.removeFirst()
        object["recentEvents"] = recentEvents
      } else if var chunk = object["archiveChunk"] as? [String: Any],
        let encoded = chunk["data"] as? String,
        let bytes = Data(base64Encoded: encoded), bytes.count > 128 {
        chunk["data"] = Data(bytes.prefix(bytes.count / 2)).base64EncodedString()
        object["archiveChunk"] = chunk
      } else {
        object.removeValue(forKey: "archiveChunk")
        object.removeValue(forKey: "lastAppDiagnostic")
        // Keep the complete day manifest so older retained days can catch up.
        return (try? JSONSerialization.data(withJSONObject: object,
          options: [.sortedKeys])) ?? Data("{}".utf8)
      }
    }
  }

  private func debugArchiveNeedsSync() -> Bool {
    guard let pairing,
      let report = latestMacDiagnosticsData(),
      let remote = try? JSONSerialization.jsonObject(with: report) as? [String: Any]
    else { return false }
    if let manifest = remote["archiveManifest"] as? [String: Int],
      Self.archiveRequest(manifest: manifest,
        directory: Self.computerArchiveDirectory(for: pairing.hostID)) != nil {
      return true
    }
    if let request = remote["archiveRequest"] as? [String: Any] {
      return Self.archiveChunk(request: request,
        directory: Self.debugArchiveDirectory, limit: 1) != nil
    }
    return false
  }

  func latestMacDiagnosticsData() -> Data? {
    UserDefaults.standard.data(forKey: macDiagnosticsKey)
  }

  func debugLogText() -> String {
    ([CrashDiagnostics.shared.summary()].compactMap { $0 } + Self.debugEvents())
      .joined(separator: "\n")
  }

  var debugRetentionDays: Int {
    get {
      let saved = UserDefaults.standard.integer(forKey: Self.debugRetentionKey)
      return saved == 0 ? 30 : min(365, max(7, saved))
    }
    set {
      UserDefaults.standard.set(min(365, max(7, newValue)), forKey: Self.debugRetentionKey)
      Self.pruneDebugArchive()
      debugManifestSnapshot = nil
      debugManifestCapturedAt = nil
      for computer in pairings {
        Self.pruneComputerArchive(for: computer.hostID)
      }
    }
  }

  func debugLogDays() -> [String] {
    Self.migrateDebugEvents()
    return Self.archiveDays()
  }

  func debugLogText(for day: String) -> String {
    Self.migrateDebugEvents()
    guard Self.validArchiveDay(day) else { return "" }
    return (try? String(contentsOf: Self.debugArchiveURL(for: day), encoding: .utf8)) ?? ""
  }

  func computerDebugLogDays(for hostID: UUID) -> [String] {
    Self.archiveDays(in: Self.computerArchiveDirectory(for: hostID))
  }

  func computerDebugLogText(for hostID: UUID, day: String) -> String {
    guard Self.validArchiveDay(day) else { return "" }
    let url = Self.computerArchiveDirectory(for: hostID)
      .appendingPathComponent("\(day).log")
    return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
  }

  func recordImportOutcome(filename: String, status: String, logDate: Date?,
    detail: String?) {
    let date = logDate.map(Self.localTime) ?? "unknown"
    let message = "Import: \(filename); result=\(status); logDate=\(date)" +
      (detail.map { "; detail=\($0)" } ?? "")
    Self.appendDebugEvent(message)
  }

  func clearDebugLogs() {
    debugManifestSnapshot = nil
    debugManifestCapturedAt = nil
    if let files = try? FileManager.default.contentsOfDirectory(at: Self.debugArchiveDirectory,
      includingPropertiesForKeys: nil) {
      for file in files where Self.validArchiveDay(file.deletingPathExtension().lastPathComponent) {
        try? FileManager.default.removeItem(at: file)
      }
    }
    UserDefaults.standard.removeObject(forKey: Self.debugEventsKey)
    UserDefaults.standard.set(true, forKey: Self.debugMigratedKey)
  }

  func macDebugLogText() -> String {
    guard let report = latestMacDiagnosticsData(),
      let object = try? JSONSerialization.jsonObject(with: report) as? [String: Any],
      let events = object["recentEvents"] as? [String] else { return "" }
    return events.joined(separator: "\n")
  }

  private static func debugEvents() -> [String] {
    UserDefaults.standard.stringArray(forKey: debugEventsKey) ?? []
  }

  private static var debugArchiveDirectory: URL {
    let root = FileManager.default.urls(for: .applicationSupportDirectory,
      in: .userDomainMask)[0]
    return root.appendingPathComponent("MochiLog/MacTransferDebugLogs", isDirectory: true)
  }

  private static func computerArchiveDirectory(for hostID: UUID) -> URL {
    let root = FileManager.default.urls(for: .applicationSupportDirectory,
      in: .userDomainMask)[0]
    return root.appendingPathComponent("MochiLog/ComputerDebugLogs", isDirectory: true)
      .appendingPathComponent(hostID.uuidString, isDirectory: true)
  }

  private static func validArchiveDay(_ day: String) -> Bool {
    day.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#,
      options: .regularExpression) != nil
  }

  private static func debugArchiveURL(for day: String) -> URL {
    debugArchiveDirectory.appendingPathComponent("\(day).log")
  }

  private static func archiveDays() -> [String] {
    archiveDays(in: debugArchiveDirectory)
  }

  private static func archiveDays(in directory: URL) -> [String] {
    let files = (try? FileManager.default.contentsOfDirectory(at: directory,
      includingPropertiesForKeys: nil)) ?? []
    return files.compactMap { file in
      guard file.pathExtension == "log" else { return nil }
      let day = file.deletingPathExtension().lastPathComponent
      return validArchiveDay(day) ? day : nil
    }.sorted(by: >)
  }

  private static func compactDay(_ day: String) -> String {
    day.replacingOccurrences(of: "-", with: "")
  }

  private static func expandedDay(_ compact: String) -> String? {
    guard compact.range(of: #"^[0-9]{8}$"#,
      options: .regularExpression) != nil else { return nil }
    let day = String(compact.prefix(4)) + "-" +
      String(compact.dropFirst(4).prefix(2)) + "-" + String(compact.suffix(2))
    return validArchiveDay(day) ? day : nil
  }

  private static func archiveManifest(in directory: URL) -> [String: Int] {
    Dictionary(uniqueKeysWithValues: archiveDays(in: directory).compactMap { day in
      let url = directory.appendingPathComponent("\(day).log")
      guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize,
        (0...64_000_000).contains(size) else { return nil }
      return (compactDay(day), size)
    })
  }

  private static func archiveRequest(manifest: [String: Int], directory: URL)
    -> [String: Any]? {
    let days = UserDefaults.standard.integer(forKey: debugRetentionKey)
    let retention = days == 0 ? 30 : min(365, max(7, days))
    let cutoff = archiveDayString(Calendar.current.date(byAdding: .day,
      value: 1 - retention, to: Date()) ?? Date())
    for compact in manifest.keys.sorted(by: >) {
      guard let day = expandedDay(compact), let size = manifest[compact],
        day >= cutoff, (0...64_000_000).contains(size) else { continue }
      let url = directory.appendingPathComponent("\(day).log")
      let current = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
      if current < size { return ["day": compact, "offset": current] }
    }
    return nil
  }

  private static func archiveChunk(request: [String: Any], directory: URL,
    limit: Int) -> [String: Any]? {
    guard let compact = request["day"] as? String,
      let day = expandedDay(compact), let offset = request["offset"] as? Int,
      offset >= 0, offset <= 64_000_000 else { return nil }
    let url = directory.appendingPathComponent("\(day).log")
    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? handle.close() }
    guard (try? handle.seek(toOffset: UInt64(offset))) != nil,
      let bytes = try? handle.read(upToCount: limit), !bytes.isEmpty else { return nil }
    return ["day": compact, "offset": offset,
      "data": bytes.base64EncodedString()]
  }

  private static func receiveArchiveChunk(_ chunk: [String: Any], from hostID: UUID) {
    guard let compact = chunk["day"] as? String,
      let day = expandedDay(compact), let offset = chunk["offset"] as? Int,
      let encoded = chunk["data"] as? String,
      let bytes = Data(base64Encoded: encoded), !bytes.isEmpty,
      bytes.count <= 8_192, offset >= 0,
      offset + bytes.count <= 64_000_000 else { return }
    let directory = computerArchiveDirectory(for: hostID)
    do {
      try FileManager.default.createDirectory(at: directory,
        withIntermediateDirectories: true)
      let url = directory.appendingPathComponent("\(day).log")
      if !FileManager.default.fileExists(atPath: url.path) {
        FileManager.default.createFile(atPath: url.path, contents: nil)
      }
      let handle = try FileHandle(forUpdating: url)
      defer { try? handle.close() }
      let size = try handle.seekToEnd()
      guard size == UInt64(offset) else { return }
      try handle.write(contentsOf: bytes)
      try FileManager.default.setAttributes([.posixPermissions: 0o600],
        ofItemAtPath: url.path)
      appendDebugEvent("Debug archive sync: received \(day) from computer \(hostID.uuidString), offset \(offset), \(bytes.count) bytes")
      pruneComputerArchive(for: hostID)
    } catch { return }
  }

  private static func pruneComputerArchive(for hostID: UUID) {
    let directory = computerArchiveDirectory(for: hostID)
    let days = UserDefaults.standard.integer(forKey: debugRetentionKey)
    let retention = days == 0 ? 30 : min(365, max(7, days))
    let cutoff = archiveDayString(Calendar.current.date(byAdding: .day,
      value: 1 - retention, to: Date()) ?? Date())
    for old in archiveDays(in: directory) where old < cutoff {
      try? FileManager.default.removeItem(at:
        directory.appendingPathComponent("\(old).log"))
    }
  }

  private static func archiveDayString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  @discardableResult
  private static func appendToArchive(_ event: String) -> Bool {
    let day = String(event.prefix(10))
    guard validArchiveDay(day) else { return false }
    do {
      try FileManager.default.createDirectory(at: debugArchiveDirectory,
        withIntermediateDirectories: true)
      let url = debugArchiveURL(for: day)
      if !FileManager.default.fileExists(atPath: url.path) {
        FileManager.default.createFile(atPath: url.path, contents: nil)
      }
      try FileManager.default.setAttributes([.posixPermissions: 0o600],
        ofItemAtPath: url.path)
      let handle = try FileHandle(forWritingTo: url)
      defer { try? handle.close() }
      try handle.seekToEnd()
      try handle.write(contentsOf: Data((event + "\n").utf8))
      return true
    } catch { return false }
  }

  private static func migrateDebugEvents() {
    guard !UserDefaults.standard.bool(forKey: debugMigratedKey) else { return }
    let events = debugEvents()
    guard events.allSatisfy({ appendToArchive($0) }) else { return }
    UserDefaults.standard.set(true, forKey: debugMigratedKey)
    pruneDebugArchive()
  }

  private static func pruneDebugArchive() {
    let days = UserDefaults.standard.integer(forKey: debugRetentionKey)
    let retention = days == 0 ? 30 : min(365, max(7, days))
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = "yyyy-MM-dd"
    let cutoff = formatter.string(from: Calendar.current.date(byAdding: .day,
      value: 1 - retention, to: Date()) ?? Date())
    for day in archiveDays() where day < cutoff {
      try? FileManager.default.removeItem(at: debugArchiveURL(for: day))
    }
  }

  private static func appendDebugEvent(_ message: String) {
    migrateDebugEvents()
    let normalized = String(message.replacingOccurrences(of: "\n", with: " ").prefix(240))
    var events = debugEvents()
    guard events.last?.hasSuffix(" | \(normalized)") != true else { return }
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = .autoupdatingCurrent
    let event = "\(formatter.string(from: Date())) | \(normalized)"
    events.append(event)
    if events.count > 300 { events.removeFirst(events.count - 300) }
    UserDefaults.standard.set(events, forKey: debugEventsKey)
    if appendToArchive(event) { pruneDebugArchive() }
  }

  static func inbox(for pairing: MacTransferPairing) throws -> URL {
    var base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("MacTransferInbox", isDirectory: true)
      .appendingPathComponent(pairing.physicalDeviceID.uuidString, isDirectory: true)
    if UserDefaults.standard.string(forKey: "MacTransferLegacyHostID") != pairing.hostID.uuidString {
      base.appendPathComponent(pairing.hostID.uuidString, isDirectory: true)
    }
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    return base
  }

  private static func loadPairings() -> [MacTransferPairing] {
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "net.ryuya-dev.MochiLog.mac-pairing",
      kSecAttrAccount as String: "hosts", kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne]
    var item: CFTypeRef?
    if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data,
      let saved = try? JSONDecoder().decode([MacTransferPairing].self, from: data) {
      return saved
    }
    var old = query
    old[kSecAttrAccount as String] = "active"
    item = nil
    guard SecItemCopyMatching(old as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data,
      let legacy = try? JSONDecoder().decode(MacTransferPairing.self, from: data) else { return [] }
    UserDefaults.standard.set(legacy.hostID.uuidString, forKey: "MacTransferLegacyHostID")
    try? savePairings([legacy])
    return [legacy]
  }

  private static func loadStoredPairings(account: String) -> [MacTransferPairing] {
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "net.ryuya-dev.MochiLog.mac-pairing",
      kSecAttrAccount as String: account, kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data else { return [] }
    return (try? JSONDecoder().decode([MacTransferPairing].self, from: data)) ?? []
  }

  private static func savePairings(_ pairings: [MacTransferPairing]) throws {
    try saveStoredPairings(pairings, account: "hosts")
  }

  private static func saveStoredPairings(_ pairings: [MacTransferPairing],
    account: String) throws {
    let data = try JSONEncoder().encode(pairings)
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "net.ryuya-dev.MochiLog.mac-pairing",
      kSecAttrAccount as String: account]
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
    allowCellular: Bool, continueOnInvalidResponse: Bool = false) async throws -> Data {
    try await Task.detached(priority: .userInitiated) {
      var lastError: Error = TransferError.invalidPairing
      for route in routes {
        do { return try exchange(on: route, payload: payload, allowCellular: allowCellular) }
        catch TransferError.invalidPairing {
          if !continueOnInvalidResponse { throw TransferError.invalidPairing }
          lastError = TransferError.invalidPairing
        }
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
