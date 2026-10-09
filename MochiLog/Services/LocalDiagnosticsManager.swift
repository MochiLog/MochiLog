import Combine
import CryptoKit
import Foundation
import Network
import Security
import UIKit

@available(iOS 17, *)
@MainActor
final class LocalDiagnosticsManager: ObservableObject {
  static let shared = LocalDiagnosticsManager()
  @Published private(set) var pairingActive = false
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
      noteOSVersion()
    }
    checkInstalledPairingFile(activateAfterImport: false)
  }
  private func save(_ value: LocalDiagnosticsCredential, activate: Bool = true) throws {
    let bytes = try JSONEncoder().encode(value)
    let update: [String: Any] = [kSecValueData as String: bytes]
    var result = SecItemUpdate(query as CFDictionary, update as CFDictionary)
    if result == errSecItemNotFound {
      var item = query; item[kSecValueData as String] = bytes
      item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
      result = SecItemAdd(item as CFDictionary, nil)
    }
    guard result == errSecSuccess else {
      MacTransferManager.appendDebugEvent("Local diagnostics: Keychain save failed; status=\(result); previous credential retained")
      throw LocalDiagnosticsTransport.Failure.invalid
    }
    stop(); credential = value; configured = true; message = text("local_configured"); noteOSVersion()
    if activate { updateActivity() }
  }
  private func noteOSVersion() {
    let key = "LocalDiagnosticsLastObservedOSVersion"
    let current = UIDevice.current.systemVersion
    if let previous = UserDefaults.standard.string(forKey: key), previous != current {
      MacTransferManager.appendDebugEvent("Local diagnostics: OS version changed \(previous) -> \(current); existing credential retained; validate on next read, no automatic re-pairing")
    }
    UserDefaults.standard.set(current, forKey: key)
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
  /// idevice_pair writes into Documents through House Arrest without launching
  /// MochiLog. Adopt it automatically when our process next becomes active.
  func checkInstalledPairingFile(activateAfterImport: Bool = true) {
    guard !busy, !batteryBusy, !pairingActive, !ProcessInfo.processInfo.isiOSAppOnMac else { return }
    let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    for name in ["pairingFile.plist", "rpPairingFile.plist"] {
      let file = root.appendingPathComponent(name)
      guard FileManager.default.fileExists(atPath: file.path) else { continue }
      do {
        let metadata = try file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard metadata.isRegularFile == true, metadata.isSymbolicLink != true,
          let size = metadata.fileSize, size > 0, size <= 65536 else { throw LocalDiagnosticsTransport.Failure.invalid }
        let data = try Data(contentsOf: file)
        guard let raw = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
          let plist = LocalPairingFileFormat.normalized(raw), let udid = plist["UDID"] as? String,
          credential == nil || credential?.expectedUDID == udid else { throw LocalDiagnosticsTransport.Failure.identity }
        let candidate = try LocalDiagnosticsCredential.validate(data, expectedUDID: udid,
          physicalDeviceID: credential?.physicalDeviceID ?? PhysicalDeviceIdentityStore.current())
        try save(candidate, activate: activateAfterImport)
        do {
          try FileManager.default.removeItem(at: file)
          MacTransferManager.appendDebugEvent("Local diagnostics: direct-install file adopted into device-only Keychain; source=\(name); plaintext staging removed; records and PC pairings retained")
        } catch {
          MacTransferManager.appendDebugEvent("Local diagnostics: direct-install credential saved; staging cleanup failed; source=\(name); retry cleanup after next activation")
        }
        return
      } catch {
        message = text("local_direct_import_failed")
        MacTransferManager.appendDebugEvent("Local diagnostics: direct-install file not adopted; source=\(name), error=\(error); previous credential retained; no credential logged")
      }
    }
  }
  func reuse(_ pair: MacTransferPairing) async {
    guard #available(iOS 27, *) else { return }
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
      MacTransferManager.appendDebugEvent("Local diagnostics: own-device OS pairing reused over authenticated v3; source=\(pair.platform ?? "mac"), computer=\(pair.hostID); keys stored in device-only Keychain")
    } catch { message = text("local_reuse_failed") }
  }
  #if DEBUG
  var debugCredentialSnapshot: LocalDiagnosticsCredential? { credential }
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
  func setPairingActive(_ value: Bool) {
    pairingActive = value
    updateActivity()
  }
  func updateActivity() {
    guard !pairingActive, AppSettings.shared.localAutomaticCollectionEnabled, !ProcessInfo.processInfo.isiOSAppOnMac,
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
          await self?.receiveBatteryNow(manual: false)
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
  func receiveBatteryNow(manual: Bool = true) async {
    guard !pairingActive, !batteryBusy, let credential, let address = safeAddress,
      AppSettings.shared.localAutomaticCollectionEnabled, AppSettings.shared.liveBatteryEnabled else { return }
    batteryBusy = true; defer { batteryBusy = false }; let epoch = generation
    do {
      let value = try await Task.detached(priority: .utility) { try LocalDiagnosticsTransport.battery(credential, address: address) }.value
      guard generation == epoch, !Task.isCancelled else { return }
      reading = value; state = "current"
      if manual { MacTransferManager.appendDebugEvent("Local diagnostics: current battery received directly; coreFields=\(value.values.count); no history record saved") }
    } catch {
      if generation == epoch {
        state = reading == nil ? "unavailable" : "stale"
        if manual { MacTransferManager.appendDebugEvent("Local diagnostics: current battery request failed; error=\(error)") }
      }
    }
  }
  private static func japanDay(_ date: Date = Date()) -> String {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "Asia/Tokyo"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
  }
  private func importedBases(_ id: UUID) -> Set<String> {
    Set(UserDefaults.standard.stringArray(forKey: "LocalDiagnosticsImported." + id.uuidString) ?? [])
  }
  func collectNow(manual: Bool = true) async {
    guard !pairingActive, !busy, let credential, let address = safeAddress, AppSettings.shared.localAutomaticCollectionEnabled else { return }
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

#if DEBUG && targetEnvironment(simulator)
import Darwin

@available(iOS 17, *)
extension LocalDiagnosticsManager {
  /// Uses the real native transport against a loopback protocol fixture. Never
  /// runs on hardware or in release builds, and never imports history records.
  func debugSimulatorFixtureIfRequested() {
    guard !probeStarted, ProcessInfo.processInfo.environment["MOCHI_LOCAL_NATIVE_FIXTURE"] == "1",
      !AppSettings.shared.localAutomaticCollectionEnabled else { return }
    probeStarted = true
    Task {
      let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("LocalDiagnosticsFixture")
      var results: [String: Bool] = [:]
      let original = credential
      let originalMessage = message
      let osKey = "LocalDiagnosticsLastObservedOSVersion"
      let originalOS = UserDefaults.standard.object(forKey: osKey)
      var q = query; q[kSecReturnData as String] = true
      var stored: CFTypeRef?
      let originalStatus = SecItemCopyMatching(q as CFDictionary, &stored)
      let originalBytes = stored as? Data
      defer {
        stop()
        var restoreStatus: OSStatus
        if originalStatus == errSecSuccess, let originalBytes {
          restoreStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: originalBytes] as CFDictionary)
        } else { restoreStatus = SecItemDelete(query as CFDictionary) }
        credential = original; configured = original != nil; message = originalMessage
        if let originalOS { UserDefaults.standard.set(originalOS, forKey: osKey) }
        else { UserDefaults.standard.removeObject(forKey: osKey) }
        try? FileManager.default.removeItem(at: root)
        results["originalCredentialRestored"] = (restoreStatus == errSecSuccess || (originalBytes == nil && restoreStatus == errSecItemNotFound)) && credential?.pairing == original?.pairing
        results["passed"] = results.count == 14 && results.values.allSatisfy { $0 }
        let output = root.deletingLastPathComponent().appendingPathComponent("LocalDiagnosticsFixtureResult.json")
        if let data = try? JSONSerialization.data(withJSONObject: results, options: [.sortedKeys]) { try? data.write(to: output, options: .atomic) }
        MacTransferManager.appendDebugEvent("Local diagnostics simulator fixture: \(results.filter { $0.value }.count) passing checks; no records imported; credentials restored")
      }
      do {
        let config = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("config.json"))) as? [String: Any]
        guard let udid = config?["udid"] as? String, let port = config?["controlPort"] as? UInt16,
          let hash = config?["sha256"] as? String, let name = config?["name"] as? String else { throw LocalDiagnosticsTransport.Failure.invalid }
        let old = try Data(contentsOf: root.appendingPathComponent("old.plist"))
        let new = try Data(contentsOf: root.appendingPathComponent("new.plist"))
        func mode(_ value: UInt8) async throws { try await Task.detached { try Self.fixtureControl(port, value) }.value }
        func battery(_ value: LocalDiagnosticsCredential) async throws -> LiveBatteryReading {
          try await Task.detached { try LocalDiagnosticsTransport.battery(value, address: "127.0.0.1") }.value
        }
        try importPairing(old, expectedUDID: udid)
        guard let trusted = credential else { throw LocalDiagnosticsTransport.Failure.invalid }
        let installed = root.deletingLastPathComponent().appendingPathComponent("pairingFile.plist")
        guard !FileManager.default.fileExists(atPath: installed.path) else { throw LocalDiagnosticsTransport.Failure.invalid }
        defer { try? FileManager.default.removeItem(at: installed) }
        try old.write(to: installed, options: .atomic)
        checkInstalledPairingFile()
        results["directInstallAdopted"] = credential?.pairing == old && configured && !FileManager.default.fileExists(atPath: installed.path)
        var foreign = try PropertyListSerialization.propertyList(from: old, format: nil) as! [String: Any]
        foreign["UDID"] = "00008100-0000000000000002"
        try PropertyListSerialization.data(fromPropertyList: foreign, format: .binary, options: 0).write(to: installed, options: .atomic)
        checkInstalledPairingFile()
        results["directInstallRejectsForeign"] = credential?.pairing == old && FileManager.default.fileExists(atPath: installed.path)
        try Data("invalid".utf8).write(to: installed, options: .atomic)
        checkInstalledPairingFile()
        results["directInstallRejectsMalformed"] = credential?.pairing == old && FileManager.default.fileExists(atPath: installed.path)
        try FileManager.default.removeItem(at: installed)
        let reading = try await battery(trusted)
        results["nativeBattery"] = reading.values["CycleCount"] == 321 && reading.values["DesignCapacity"] == 4000
        let files = try await Task.detached { try LocalDiagnosticsTransport.logs(trusted, address: "127.0.0.1", alreadyReceived: []) }.value
        results["nativeLogBody"] = files.count == 1 && files[0].name == name &&
          SHA256.hash(data: files[0].bytes).map { String(format: "%02x", $0) }.joined() == hash
        let withheld = try await Task.detached { try LocalDiagnosticsTransport.logs(trusted, address: "127.0.0.1", alreadyReceived: ["Host::" + name]) }.value
        results["alreadyReceivedWithheld"] = withheld.isEmpty
        UserDefaults.standard.set("16.6-fixture", forKey: osKey)
        noteOSVersion()
        results["osChangePreservesCredential"] = credential?.pairing == old && configured
        do { try importPairing(Data("invalid".utf8), expectedUDID: udid); results["invalidImportPreservesCredential"] = false }
        catch { results["invalidImportPreservesCredential"] = credential?.pairing == old && configured }
        for (modeByte, key) in [(UInt8(114), "revokedTrustRejected"), (105, "differentIdentityRejected"), (102, "foreignCertificateRejected"), (100, "closedConnectionRejected")] {
          try await mode(modeByte)
          do { _ = try await battery(trusted); results[key] = false }
          catch { results[key] = credential?.pairing == old && configured }
        }
        try await mode(110)
        try importPairing(new, expectedUDID: udid)
        guard let refreshed = credential else { throw LocalDiagnosticsTransport.Failure.invalid }
        let recovered = try await battery(refreshed)
        results["reimportRecovers"] = recovered.values["CycleCount"] == 321 && credential?.pairing == new && configured
      } catch {
        results["fixtureCompleted"] = false
        MacTransferManager.appendDebugEvent("Local diagnostics simulator fixture: native test failed; error=\(error); synthetic credentials only")
      }

    }
  }
  nonisolated private static func fixtureControl(_ port: UInt16, _ command: UInt8) throws {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { throw LocalDiagnosticsTransport.Failure.invalid }
    defer { close(fd) }
    var timeout = timeval(tv_sec: 5, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    var address = sockaddr_in(); address.sin_family = sa_family_t(AF_INET)
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); address.sin_port = port.bigEndian
    inet_pton(AF_INET, "127.0.0.1", &address.sin_addr)
    let result = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
    guard result == 0 else { throw LocalDiagnosticsTransport.Failure.invalid }
    var command = command; var response: [UInt8] = [0, 0]
    guard write(fd, &command, 1) == 1, read(fd, &response, 2) == 2, response == [79, 75] else { throw LocalDiagnosticsTransport.Failure.invalid }
  }
}
#endif
