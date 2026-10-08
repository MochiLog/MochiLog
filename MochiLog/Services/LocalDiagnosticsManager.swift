import Combine
import CryptoKit
import Foundation
import Network
import Security
import UIKit

@available(iOS 27, *)
@MainActor
final class LocalDiagnosticsManager: ObservableObject {
  static let shared = LocalDiagnosticsManager()
  @Published private(set) var configured = false
  @Published private(set) var busy = false
  @Published private(set) var batteryBusy = false
  @Published private(set) var reading: LiveBatteryReading?
  @Published private(set) var state = "waiting"
  @Published private(set) var message = ""
  private var credential: LocalDiagnosticsCredential?
  private var loop: Task<Void, Never>?
  private var batteryLoop: Task<Void, Never>?
  private var generation = 0
  @Published var address = UserDefaults.standard.string(forKey: "LocalDiagnosticsAddress") ?? "10.7.0.1" {
    didSet { UserDefaults.standard.set(address, forKey: "LocalDiagnosticsAddress") }
  }
  private static let service = "net.ryuya-dev.MochiLog.local-diagnostics"
  private var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: Self.service, kSecAttrAccount as String: "own-device"] }
  private init() {
    var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    if SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data,
      let saved = try? JSONDecoder().decode(LocalDiagnosticsCredential.self, from: data),
      let verified = try? LocalDiagnosticsCredential.validate(saved.pairing, expectedUDID: saved.expectedUDID, physicalDeviceID: saved.physicalDeviceID) {
      credential = verified; configured = true
    }
  }
  private func save(_ value: LocalDiagnosticsCredential) throws {
    let bytes = try JSONEncoder().encode(value)
    let update: [String: Any] = [kSecValueData as String: bytes]
    var result = SecItemUpdate(query as CFDictionary, update as CFDictionary)
    if result == errSecItemNotFound {
      var item = query; item[kSecValueData as String] = bytes
      item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
      result = SecItemAdd(item as CFDictionary, nil)
    }
    guard result == errSecSuccess else { throw LocalDiagnosticsTransport.Failure.invalid }
    stop(); credential = value; configured = true; message = text("local_configured"); updateActivity()
  }
  func forget() {
    stop(); SecItemDelete(query as CFDictionary); credential = nil; configured = false
    reading = nil; state = "waiting"; message = ""
    AppSettings.shared.localAutomaticCollectionEnabled = false
  }
  func importPairing(_ data: Data, expectedUDID: String) throws {
    let value = try LocalDiagnosticsCredential.validate(data, expectedUDID: expectedUDID,
      physicalDeviceID: PhysicalDeviceIdentityStore.current())
    try save(value)
  }
  func reuse(_ pair: MacTransferPairing) async {
    guard !busy else { return }; busy = true; defer { busy = false }
    do {
      var routes: [NWEndpoint] = []
      let port = pair.lanPort ?? (pair.platform == "windows" ? 54556 : 54555)
      for host in ([pair.manualHostAddress].compactMap { $0 } + (pair.lanAddresses ?? []) + [pair.tailnetAddress].compactMap { $0 }) {
        let routePort = host == pair.tailnetAddress ? pair.tailnetPort ?? port : port
        if let ip = IPv4Address(host), let endpointPort = NWEndpoint.Port(rawValue: routePort) {
          routes.append(.hostPort(host: .ipv4(ip), port: endpointPort))
        }
      }
      var reply: [String: Any]?
      for route in routes.prefix(8) {
        do {
          let nonce = UUID(); let issued = Int64(Date().timeIntervalSince1970)
          let mac = HMAC<SHA256>.authenticationCode(for: Data("v2|\(pair.hostID.uuidString)|\(pair.physicalDeviceID.uuidString)|\(nonce.uuidString)|".utf8), using: SymmetricKey(data: pair.secret))
            .map { String(format: "%02x", $0) }.joined()
          let inner = try JSONSerialization.data(withJSONObject: ["hostID": pair.hostID.uuidString,
            "physicalDeviceID": pair.physicalDeviceID.uuidString, "nonce": nonce.uuidString, "ack": "", "mac": mac,
            "version": "2", "localDiagnosticsPairing": "1"])
          let aad = Data("v3|request|\(pair.hostID.uuidString)|\(pair.physicalDeviceID.uuidString)|\(nonce.uuidString)|\(issued)".utf8)
          let sealed = try AES.GCM.seal(inner, using: SymmetricKey(data: pair.secret), authenticating: aad)
          let payload = try JSONSerialization.data(withJSONObject: ["version": "3", "hostID": pair.hostID.uuidString,
            "physicalDeviceID": pair.physicalDeviceID.uuidString, "nonce": nonce.uuidString,
            "issuedAt": issued, "box": sealed.combined!.base64EncodedString()] as [String: Any]) + Data([10])
          let box = try await LiveBatteryTransport.exchange(route, payload: payload, timeoutSeconds: 8)
          let plain = try AES.GCM.open(AES.GCM.SealedBox(combined: box), using: SymmetricKey(data: pair.secret),
            authenticating: Data("v2|response|\(pair.hostID.uuidString)|\(pair.physicalDeviceID.uuidString)|\(nonce.uuidString)".utf8))
          guard plain.count > 2, plain[0] == 0, plain[1] == 0,
            let json = try JSONSerialization.jsonObject(with: plain.dropFirst(2)) as? [String: Any],
            json["type"] as? String == "local-diagnostics-pairing", json["version"] as? Int == 1 else { continue }
          reply = json; break
        } catch { continue }
      }
      guard let reply, let udid = reply["expectedUDID"] as? String,
        reply["physicalDeviceID"] as? String == pair.physicalDeviceID.uuidString,
        let encoded = reply["pairing"] as? String, encoded.utf8.count <= 100000,
        let data = Data(base64Encoded: encoded),
        MacTransferManager.shared.pairings.contains(where: { $0.hostID == pair.hostID && $0.secret == pair.secret }) else {
        message = text("local_reuse_failed"); return
      }
      try save(LocalDiagnosticsCredential.validate(data, expectedUDID: udid, physicalDeviceID: pair.physicalDeviceID))
      MacTransferManager.appendDebugEvent("Local diagnostics: own-device OS pairing reused over authenticated v3; keys stored in device-only Keychain")
    } catch { message = text("local_reuse_failed") }
  }
  #if DEBUG
  private var probeStarted = false
  /// Read-only real-device probe: never imports records or changes opt-in settings.
  func debugProbeIfRequested() {
    guard !probeStarted, ProcessInfo.processInfo.environment["MOCHI_LOCAL_DIAGNOSTICS_TEST"] == "1",
      !ProcessInfo.processInfo.isiOSAppOnMac else { return }
    probeStarted = true
    Task {
      let alreadyConfigured = configured
      let previousOptIn = AppSettings.shared.localAutomaticCollectionEnabled
      defer {
        if !alreadyConfigured { forget(); AppSettings.shared.localAutomaticCollectionEnabled = previousOptIn }
      }
      if !alreadyConfigured {
        for pair in MacTransferManager.shared.pairings {
          await reuse(pair)
          if configured { break }
        }
      }
      guard let credential, let address = safeAddress else {
        MacTransferManager.appendDebugEvent("Local diagnostics probe: OS credential reuse unavailable"); return
      }
      stop()
      do {
        let value = try await Task.detached { try LocalDiagnosticsTransport.battery(credential, address: address) }.value
        let count = (try? RawBatteryField.decode(value.detailsJSON ?? "[]", revision: value.detailsRevision ?? String(repeating: "0", count: 64)).count) ?? 0
        MacTransferManager.appendDebugEvent("Local diagnostics probe: native battery success; coreFields=\(value.values.count), detailedFields=\(count); values not logged")
      } catch { MacTransferManager.appendDebugEvent("Local diagnostics probe: native battery failure=\(error)") }
      do {
        let logs = try await Task.detached { try LocalDiagnosticsTransport.logs(credential, address: address, alreadyReceived: []) }.value
        let host = logs.filter { $0.source == nil && MacTransferManager.looksLikeBatteryLog($0.bytes) }.count
        let watch = logs.filter { $0.source != nil && MacTransferManager.looksLikeBatteryLog($0.bytes) }.count
        MacTransferManager.appendDebugEvent("Local diagnostics probe: native file read success; hostBatteryFiles=\(host), watchBatteryFiles=\(watch); no records imported")
      } catch { MacTransferManager.appendDebugEvent("Local diagnostics probe: native file read failure=\(error)") }
      updateActivity()
    }
  }
  #endif
  func updateActivity() {
    guard AppSettings.shared.localAutomaticCollectionEnabled, !ProcessInfo.processInfo.isiOSAppOnMac,
      configured, UIApplication.shared.connectedScenes.contains(where: { $0.activationState == .foregroundActive }) else { stop(); return }
    if loop == nil {
      restoreStagedFiles() 
      let epoch = generation
      loop = Task { [weak self] in
        while !Task.isCancelled, self?.generation == epoch {
          await self?.collectNow(manual: false)
          do { try await Task.sleep(for: .seconds(300)) } catch { return }
        }
      }
    }
    if AppSettings.shared.liveBatteryEnabled && batteryLoop == nil {
      batteryLoop = Task { [weak self] in
        while !Task.isCancelled {
          await self?.receiveBatteryNow()
          do { try await Task.sleep(for: .seconds(15)) } catch { return }
        }
      }
    } else if !AppSettings.shared.liveBatteryEnabled { batteryLoop?.cancel(); batteryLoop = nil; reading = nil }
  }
  func stop() { generation += 1; loop?.cancel(); loop = nil; batteryLoop?.cancel(); batteryLoop = nil }
  private var safeAddress: String? {
    let parts = address.split(separator: ".").compactMap { Int($0) }
    guard parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }),
      parts[0] == 10 || parts[0] == 127 || (parts[0] == 192 && parts[1] == 168) ||
      (parts[0] == 172 && (16...31).contains(parts[1])) || LiveBatteryManager.isTailnet(address) else { return nil }
    return address
  }
  func receiveBatteryNow() async {
    guard !batteryBusy, let credential, let address = safeAddress,
      AppSettings.shared.localAutomaticCollectionEnabled, AppSettings.shared.liveBatteryEnabled else { return }
    batteryBusy = true; defer { batteryBusy = false }; let epoch = generation
    do {
      let value = try await Task.detached(priority: .utility) { try LocalDiagnosticsTransport.battery(credential, address: address) }.value
      guard generation == epoch, !Task.isCancelled else { return }
      reading = value; state = "current"
    } catch { if generation == epoch { state = reading == nil ? "unavailable" : "stale" } }
  }
  private static func japanDay(_ date: Date = Date()) -> String {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "Asia/Tokyo"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
  }
  private func importedBases(_ id: UUID) -> Set<String> {
    Set(UserDefaults.standard.stringArray(forKey: "LocalDiagnosticsImported." + id.uuidString) ?? [])
  }
  func collectNow(manual: Bool = true) async {
    guard !busy, let credential, let address = safeAddress, AppSettings.shared.localAutomaticCollectionEnabled else { return }
    let day = Self.japanDay()
    let imported = importedBases(credential.physicalDeviceID)
    if !manual {
      var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
      let watches = Set(imported.filter { $0.hasPrefix("Watch::") && $0.contains("::Analytics-" + day + "-") }.compactMap { $0.components(separatedBy: "::").dropFirst().first })
      let expected = MacTransferManager.shared.expectedWatchCount()
      let complete = imported.contains(where: { $0.hasPrefix("Host::Analytics-" + day + "-") }) && expected.map { watches.count >= $0 } == true
      if calendar.component(.hour, from: Date()) < 9 || complete {
        message = text("local_daily_wait"); return
      }
    }
    let skippedBases = skipped()
    busy = true; defer { busy = false }; let epoch = generation
    MacTransferManager.appendDebugEvent("Local diagnostics: collection started; trigger=\(manual ? "manual" : "automatic"), ownDevice=\(credential.physicalDeviceID), dailyDate=\(day)")
    do {
      let logs = try await Task.detached(priority: .utility) { try LocalDiagnosticsTransport.logs(credential, address: address, alreadyReceived: imported.union(skippedBases)) }.value
      guard generation == epoch, !Task.isCancelled, AppSettings.shared.localAutomaticCollectionEnabled else { return }
      var batch: [(url: URL, physicalDeviceID: UUID?)] = []
      let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MacTransferInbox/LocalDevice/" + credential.physicalDeviceID.uuidString, isDirectory: true)
      for log in logs {
        guard MacTransferManager.looksLikeBatteryLog(log.bytes), let origin = CloudSharedLogToken.measurementOrigin(base: log.base, origin: credential.physicalDeviceID) else {
          skip(log.base); continue
        }
        let firstLine = log.bytes.prefix { $0 != 10 }
        let header = (try? JSONSerialization.jsonObject(with: Data(firstLine))) as? [String: Any]
        let os = (header?["os_version"] as? String ?? "").lowercased().filter { !$0.isWhitespace }
        guard log.source == nil ? os.hasPrefix("iphoneos") : os.hasPrefix("watchos") else { skip(log.base); continue }
        let digest = SHA256.hash(data: log.bytes).map { String(format: "%02x", $0) }.joined()
        if let existing = MacTransferManager.shared.receivedLocalDigestState(digest, parentID: credential.physicalDeviceID, recordOrigin: origin) {
          if existing != "inbox" { markImported(log.base, parentID: credential.physicalDeviceID) }
          MacTransferManager.appendDebugEvent("Local diagnostics: duplicate withheld; source=\(existing), SHA256=\(digest.prefix(12))")
          continue
        }
        var url = root
        for component in log.base.components(separatedBy: "::") { url.appendPathComponent(component) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try log.bytes.write(to: url, options: [.atomic, .completeFileProtection])
        batch.append((url, origin))
        MacTransferManager.appendDebugEvent("Local diagnostics: staged \(log.source == nil ? "Host" : "Watch"), date=\(log.name.prefix(20)), bytes=\(log.bytes.count), SHA256=\(digest.prefix(12)); shared import queue")
      }
      SharedImportQueue.shared.enqueueBatch(batch)
      message = String(format: text("local_received"), batch.count)
    } catch {
      message = text("local_connection_failed")
      MacTransferManager.appendDebugEvent("Local diagnostics: collection failed; stage=authenticated own-device read, errorType=\(String(describing: error)); no credential logged")
    }
  }
  private func skipped() -> Set<String> {
    let dates = UserDefaults.standard.dictionary(forKey: "LocalDiagnosticsExcluded") as? [String: Double] ?? [:]
    return Set(dates.filter { Date().timeIntervalSince1970 - $0.value < 1800 }.keys)
  }
  private func skip(_ base: String) {
    var dates = UserDefaults.standard.dictionary(forKey: "LocalDiagnosticsExcluded") as? [String: Double] ?? [:]
    dates = dates.filter { Date().timeIntervalSince1970 - $0.value < 1800 }
    dates[base] = Date().timeIntervalSince1970
    UserDefaults.standard.set(dates, forKey: "LocalDiagnosticsExcluded")
    MacTransferManager.appendDebugEvent("Local diagnostics: non-battery/short log excluded for 30 minutes; file=\(base)")
  }
  private func restoreStagedFiles() {
    guard let credential else { return }
    let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("MacTransferInbox/LocalDevice/" + credential.physicalDeviceID.uuidString)
    let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])?.allObjects.compactMap { $0 as? URL } ?? []
    let imported = importedBases(credential.physicalDeviceID)
    let batch = files.compactMap { url -> (url: URL, physicalDeviceID: UUID?)? in
      let base = url.path.dropFirst(root.path.count + 1).components(separatedBy: "/").joined(separator: "::")
      guard !imported.contains(base), CloudSharedLogToken.validBase(base),
        let origin = CloudSharedLogToken.measurementOrigin(base: base, origin: credential.physicalDeviceID) else { return nil }
      return (url, origin)
    }
    if !batch.isEmpty {
      SharedImportQueue.shared.enqueueBatch(batch)
      MacTransferManager.appendDebugEvent("Local diagnostics: recovered \(batch.count) staged file(s); shared import queue")
    }
  }
  private func markImported(_ base: String, parentID: UUID) {
    var values = importedBases(parentID); values.insert(base)
    UserDefaults.standard.set(Array(values.sorted().suffix(10000)), forKey: "LocalDiagnosticsImported." + parentID.uuidString)
  }
  func imported(_ url: URL, success: Bool) {
    guard success, let local = url.pathComponents.firstIndex(of: "LocalDevice"),
      local + 2 < url.pathComponents.count, let parent = UUID(uuidString: url.pathComponents[local + 1]) else { return }
    let base = url.pathComponents.dropFirst(local + 2).joined(separator: "::")
    guard CloudSharedLogToken.validBase(base) else { return }
    markImported(base, parentID: parent)
    MacTransferManager.shared.rememberLocalDigest(url, parentID: parent)
    // The record/digest are committed; raw local staging is only for recovery.
    try? FileManager.default.removeItem(at: url)
  }
  private func text(_ key: String) -> String { L10n.text(key, table: "MacTransfer") }
}
