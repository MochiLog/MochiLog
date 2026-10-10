import BackgroundTasks
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
  @Published private(set) var collectionProgress: LocalCollectionProgress?
  @Published private(set) var collectionPaused = false
  @Published private(set) var collectionStartedAt: Date?
  private var collectionCancellation: LocalCollectionCancellation?
  private var backgroundTask = UIBackgroundTaskIdentifier.invalid
  private var continuedProcessing: AnyObject?
  private var activeCollectionTaskID: String?
  @available(iOS 26, *)
  private var continuedTask: BGContinuedProcessingTask? {
    get { continuedProcessing as? BGContinuedProcessingTask }
    set { continuedProcessing = newValue }
  }
  @available(iOS 26, *)
  private static func registerCollectionTask(identifier: String) -> Bool {
    guard !ProcessInfo.processInfo.isiOSAppOnMac else { return false }
    // Register the fully composed request ID, not the Info.plist wildcard.
    // Continued-processing handlers may be registered after app launch.
    return BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
      guard let task = task as? BGContinuedProcessingTask else { task.setTaskCompleted(success: false); return }
      Task { @MainActor in
        let owner = shared
        guard owner.busy, task.identifier == owner.activeCollectionTaskID,
          let cancellation = owner.collectionCancellation, !cancellation.isCancelled else {
          task.setTaskCompleted(success: false); return
        }
        owner.continuedTask = task
        task.progress.totalUnitCount = 1000
        task.expirationHandler = { Task { @MainActor in
          guard owner.continuedTask === task else { return }
          owner.pauseCollection(reason: "system continued-task expiration/cancellation")
        } }
        owner.publishCollectionProgress(owner.collectionProgress ?? LocalCollectionProgress())
        if owner.backgroundTask != .invalid {
          UIApplication.shared.endBackgroundTask(owner.backgroundTask); owner.backgroundTask = .invalid
        }
        MacTransferManager.appendDebugEvent("Local diagnostics: continued background task accepted; progress reporting active")
      }
    }
  }
  private func beginCollectionBackground(manual: Bool) async {
    backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "MochiLog local collection") { [weak self] in
      Task { @MainActor [weak self] in self?.pauseCollection(reason: "short background time expired") }
    }
    if #available(iOS 26, *), manual {
      let identifier = "net.ryuya-dev.MochiLog.local-collection." + UUID().uuidString
      guard Self.registerCollectionTask(identifier: identifier) else {
        MacTransferManager.appendDebugEvent("Local diagnostics: continued-task registration unavailable; short background fallback")
        return
      }
      activeCollectionTaskID = identifier
      let request = BGContinuedProcessingTaskRequest(identifier: identifier,
        title: text("local_collecting"), subtitle: text("local_progress_connecting"))
      request.strategy = .fail
      do {
        if #available(iOS 27, *) {
          try await Task.detached { try await BGTaskScheduler.shared.submitTaskRequest(request) }.value
        } else {
          try BGTaskScheduler.shared.submit(request)
        }
      }
      catch {
        let error = error as NSError
        MacTransferManager.appendDebugEvent("Local diagnostics: continued background task unavailable; domain=\(error.domain), code=\(error.code); short background fallback")
      }
    }
  }
  private func endCollectionBackground(success: Bool) {
    if #available(iOS 26, *) {
      if let identifier = activeCollectionTaskID { BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier) }
      activeCollectionTaskID = nil
      if success { continuedTask?.progress.completedUnitCount = 1000 }
      continuedTask?.setTaskCompleted(success: success); continuedTask = nil
    }
    if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask); backgroundTask = .invalid }
  }
  private func pauseCollection(reason: String) {
    guard let cancellation = collectionCancellation else { return }
    cancellation.cancel(); collectionPaused = true; message = text("local_collection_paused")
    MacTransferManager.appendDebugEvent("Local diagnostics: collection paused; trigger=\(reason); completed file checkpoints retained, interrupted file retried")
    endCollectionBackground(success: false)
  }
  func cancelCollection() {
    pauseCollection(reason: "user pause")
    #if DEBUG && targetEnvironment(simulator)
    if ProcessInfo.processInfo.environment["MOCHI_COLLECTION_PROGRESS_UI"] == "1" { busy = false }
    #endif
  }
  func dismissCollectionNotice() { collectionPaused = false; collectionProgress = nil }
  func suspendForBackground() {
    batteryLoop?.cancel(); batteryLoop = nil
    // A sleeping foreground loop must not cancel an independently OS-owned job.
    if !busy { loop?.cancel(); loop = nil }
    LocalCollectionScheduler.reschedule()
    if busy {
      MacTransferManager.appendDebugEvent("Local diagnostics: app backgrounded; active collection continues within OS budget; completed files checkpointed")
    }
  }
  private func publishCollectionProgress(_ value: LocalCollectionProgress) {
    let previous = collectionProgress
    collectionProgress = value
    if previous?.phase != value.phase || previous?.file != value.file || previous?.completed != value.completed {
      MacTransferManager.appendDebugEvent("Local diagnostics: progress; stage=\(value.phase.rawValue), processed=\(value.completed)/\(value.total), file=\(value.file), bytes=\(value.bytes)")
    }
    if #available(iOS 26, *), let task = continuedTask {
      task.progress.completedUnitCount = max(task.progress.completedUnitCount, Int64((value.fraction ?? 0) * 990))
      task.updateTitle(text("local_collecting"), subtitle: text("local_progress_" + value.phase.rawValue))
    }
  }
  @Published private(set) var reading: LiveBatteryReading?
  @Published private(set) var state = "waiting"
  @Published private(set) var message = ""
  @Published private(set) var installingPairing = false
  private var installedImportTask: Task<Void, Never>?
  private var installedImportID: UUID?
  private var credential: LocalDiagnosticsCredential?
  private var loop: Task<Void, Never>?
  private var batteryLoop: Task<Void, Never>?
  private var generation = 0
  private var protectionObserver: NSObjectProtocol?
  var hasStoredCredential: Bool { configured || UserDefaults.standard.bool(forKey: "LocalDiagnosticsHasCredential") }
  @Published var address = UserDefaults.standard.string(forKey: "LocalDiagnosticsAddress") ?? "10.7.0.1" {
    didSet { UserDefaults.standard.set(address, forKey: "LocalDiagnosticsAddress") }
  }
  private static let service = "net.ryuya-dev.MochiLog.local-diagnostics"
  private var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: Self.service, kSecAttrAccount as String: "own-device"] }
  private init() {
    reloadCredentialIfUnlocked()
    protectionObserver = NotificationCenter.default.addObserver(forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
      object: nil, queue: .main) { [weak self] _ in
      Task { @MainActor [weak self] in self?.pauseCollection(reason: "device locked; protected data unavailable") }
    }
    if UIApplication.shared.isProtectedDataAvailable { checkInstalledPairingFile() }
  }
  private func reloadCredentialIfUnlocked() {
    guard UIApplication.shared.isProtectedDataAvailable, credential == nil else { return }
    var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(q as CFDictionary, &result)
    if status == errSecSuccess, let data = result as? Data,
      let saved = try? JSONDecoder().decode(LocalDiagnosticsCredential.self, from: data),
      let verified = try? LocalDiagnosticsCredential.validate(saved.pairing, expectedUDID: saved.expectedUDID, physicalDeviceID: saved.physicalDeviceID) {
      credential = verified; configured = true
      UserDefaults.standard.set(true, forKey: "LocalDiagnosticsHasCredential")
      noteOSVersion()
    } else if status == errSecItemNotFound {
      UserDefaults.standard.set(false, forKey: "LocalDiagnosticsHasCredential")
    }
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
    stop(); credential = value; configured = true; UserDefaults.standard.set(true, forKey: "LocalDiagnosticsHasCredential"); message = text("local_configured"); noteOSVersion()
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
    installedImportTask?.cancel(); installedImportTask = nil; installedImportID = nil; installingPairing = false
    stop(); SecItemDelete(query as CFDictionary); credential = nil; configured = false; UserDefaults.standard.set(false, forKey: "LocalDiagnosticsHasCredential")
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
  func checkInstalledPairingFile() {
    guard UIApplication.shared.isProtectedDataAvailable, !busy, !batteryBusy, !pairingActive, !installingPairing, !ProcessInfo.processInfo.isiOSAppOnMac else { return }
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
          let plist = LocalPairingFileFormat.normalized(raw) else { throw LocalDiagnosticsTransport.Failure.invalid }
        let previous = credential
        let embeddedUDID = plist["UDID"] as? String
        guard embeddedUDID == nil || previous == nil || embeddedUDID == previous?.expectedUDID else {
          throw LocalDiagnosticsTransport.Failure.identity
        }
        let expectedUDID = previous?.expectedUDID ?? embeddedUDID
        // Metadata describes a target; it does not prove the OS still accepts
        // these keys or that this transport supports the file's pairing kind.
        _ = try LocalDiagnosticsCredential.validate(data, expectedUDID: expectedUDID ?? "0000000000000000",
          physicalDeviceID: previous?.physicalDeviceID ?? PhysicalDeviceIdentityStore.current())
        guard let address = safeAddress else { throw LocalDiagnosticsTransport.Failure.invalid }
        let importID = UUID(); installedImportID = importID; installingPairing = true
        MacTransferManager.appendDebugEvent("Local diagnostics: installed file awaiting authenticated identity; source=\(name); previous credential retained")
        installedImportTask = Task { [weak self] in
          guard let self else { return }
          defer {
            if self.installedImportID == importID {
              self.installingPairing = false; self.installedImportTask = nil; self.installedImportID = nil
            }
          }
          do {
            let physicalID = previous?.physicalDeviceID ?? PhysicalDeviceIdentityStore.current()
            let candidate = try await Task.detached {
              try LocalDiagnosticsTransport.installedCredential(data, expectedUDID: expectedUDID,
                physicalDeviceID: physicalID, address: address)
            }.value
            guard !Task.isCancelled, self.installedImportID == importID, self.credential?.pairing == previous?.pairing,
              try Data(contentsOf: file) == data else { return }
            try self.save(candidate, activate: true)
            do {
              try FileManager.default.removeItem(at: file)
              MacTransferManager.appendDebugEvent("Local diagnostics: installed file authenticated and adopted into device-only Keychain; staging removed; records and PC pairings retained")
            } catch {
              MacTransferManager.appendDebugEvent("Local diagnostics: installed credential saved; staging cleanup failed; retry after next activation")
            }
          } catch {
            guard !Task.isCancelled, self.installedImportID == importID else { return }
            self.message = self.text("local_direct_import_pending")
            MacTransferManager.appendDebugEvent("Local diagnostics: installed file not adopted; authenticated identity unavailable; previous credential and staging retained; error=\(error)")
          }
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
  #if targetEnvironment(simulator)
  private var collectionUITestStarted = false
  private func showCollectionUIFixture() {
    configured = true; busy = true; collectionPaused = false
    collectionCancellation = LocalCollectionCancellation(); collectionStartedAt = Date()
    collectionProgress = LocalCollectionProgress(phase: .downloading,
      file: "Analytics-2026-10-10-090000.ips.ca.synced", completed: 1, total: 4,
      bytes: 1048576, fileBytes: 4194304)
  }
  #endif
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
      // Exercise the production progress/background lease without touching the
      // real import ledger or records. Completed probe files are ephemeral.
      for _ in 0..<600 {
        if !busy { break }
        try? await Task.sleep(for: .milliseconds(50))
      }
      guard !busy else {
        MacTransferManager.appendDebugEvent("Local diagnostics probe: existing collection still stopping; no second reader started")
        updateActivity(); return
      }
      let cancellation = LocalCollectionCancellation()
      collectionCancellation = cancellation; busy = true; collectionPaused = false
      collectionStartedAt = Date(); collectionProgress = LocalCollectionProgress()
      await beginCollectionBackground(manual: true)
      let root = FileManager.default.temporaryDirectory.appendingPathComponent("MochiLogReadOnlyProbe-" + UUID().uuidString)
      var success = false
      defer {
        endCollectionBackground(success: success)
        collectionCancellation = nil; busy = false
        collectionPaused = false; collectionProgress = nil
        try? FileManager.default.removeItem(at: root)
        updateActivity()
      }
      do {
        let counts = try await Task.detached {
          var host = 0; var watch = 0
          _ = try LocalDiagnosticsTransport.logs(credential, address: address, alreadyReceived: [],
            cancellation: cancellation, progress: { value in Task { @MainActor in
              guard self.collectionCancellation === cancellation else { return }
              self.publishCollectionProgress(value)
            } }, onLog: { log in
              guard MacTransferManager.looksLikeBatteryLog(log.bytes) else { return }
              try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
              try log.bytes.write(to: root.appendingPathComponent(UUID().uuidString), options: [.atomic, .completeFileProtection])
              if log.source == nil { host += 1 } else { watch += 1 }
            })
          return (host, watch)
        }.value
        success = true
        MacTransferManager.appendDebugEvent("Local diagnostics probe: native file read success; hostBatteryFiles=\(counts.0), watchBatteryFiles=\(counts.1); completed probe checkpoints; no records imported")
      } catch { MacTransferManager.appendDebugEvent("Local diagnostics probe: native file read failure=\(error); no records imported") }
    }
  }
  #endif
  func setPairingActive(_ value: Bool) {
    pairingActive = value
    updateActivity()
  }
  func updateActivity() {
    reloadCredentialIfUnlocked()
    LocalCollectionScheduler.reschedule()
    #if DEBUG && targetEnvironment(simulator)
    if ProcessInfo.processInfo.environment["MOCHI_COLLECTION_PROGRESS_UI"] == "1" {
      if !collectionUITestStarted { collectionUITestStarted = true; showCollectionUIFixture() }
      return
    }
    #endif
    guard !pairingActive, AppSettings.shared.localAutomaticCollectionEnabled, !ProcessInfo.processInfo.isiOSAppOnMac,
      configured else { stop(); return }
    guard UIApplication.shared.connectedScenes.contains(where: { $0.activationState == .foregroundActive }) else {
      suspendForBackground(); return
    }
    restoreStagedFiles()
    if loop == nil {
      let epoch = generation
      loop = Task { [weak self] in
        while !Task.isCancelled, self?.generation == epoch {
          await self?.collectNow(manual: false)
          guard UIApplication.shared.connectedScenes.contains(where: { $0.activationState == .foregroundActive }) else {
            self?.loop = nil; return
          }
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
  func stop() { pauseCollection(reason: "activity stopped/settings changed"); generation += 1; loop?.cancel(); loop = nil; batteryLoop?.cancel(); batteryLoop = nil }
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
  private func importedBases(_ id: UUID) -> Set<String> {
    Set(UserDefaults.standard.stringArray(forKey: "LocalDiagnosticsImported." + id.uuidString) ?? [])
  }
  func backgroundSchedule(now: Date = Date()) -> DailyLogCollectionPolicy {
    var received = credential.map { importedBases($0.physicalDeviceID) } ?? []
    if UIApplication.shared.isProtectedDataAvailable, let credential {
      received.formUnion(stagedBases(stagingRoot(credential.physicalDeviceID)))
    }
    return DailyLogCollectionPolicy.decide(now: now, received: received, expectedWatches: DailyLogCollectionPolicy.currentExpectedWatchCount())
  }
  private func stagingRoot(_ id: UUID) -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("MacTransferInbox/LocalDevice/" + id.uuidString, isDirectory: true)
  }
  func cancelScheduledCollection(_ token: LocalCollectionCancellation) {
    guard collectionCancellation === token else { return }
    pauseCollection(reason: "scheduled task expired")
  }
  @discardableResult
  func collectNow(manual: Bool = true, scheduled: LocalCollectionCancellation? = nil) async -> Bool {
    #if DEBUG && targetEnvironment(simulator)
    if ProcessInfo.processInfo.environment["MOCHI_COLLECTION_PROGRESS_UI"] == "1" {
      showCollectionUIFixture(); return false
    }
    #endif
    guard !ProcessInfo.processInfo.isiOSAppOnMac, UIApplication.shared.isProtectedDataAvailable else {
      if scheduled != nil { MacTransferManager.appendDebugEvent("Local scheduler: deferred; device locked or viewing-only host") }
      return false
    }
    reloadCredentialIfUnlocked()
    guard !pairingActive, !installingPairing, !busy, let credential, let address = safeAddress,
      AppSettings.shared.localAutomaticCollectionEnabled, scheduled?.isCancelled != true else {
      if scheduled != nil { MacTransferManager.appendDebugEvent("Local scheduler: deferred; disabled, unconfigured, pairing or collection already active") }
      return false
    }
    let day = DailyLogCollectionPolicy.dayKey()
    let imported = importedBases(credential.physicalDeviceID)
    if !manual {
      let decision = backgroundSchedule()
      if !decision.shouldCollect {
        message = text("local_daily_wait")
        MacTransferManager.appendDebugEvent("Local diagnostics: automatic collection deferred; reason=\(decision.reason.rawValue), earliest=\(DailyLogCollectionPolicy.timestamp(decision.earliest))")
        return true
      }
    }
    let skippedBases = skipped()
    busy = true; collectionPaused = false; collectionProgress = LocalCollectionProgress(); collectionStartedAt = Date()
    let cancellation = scheduled ?? LocalCollectionCancellation(); collectionCancellation = cancellation
    let epoch = generation; let started = ProcessInfo.processInfo.systemUptime
    var succeeded = false
    defer {
      endCollectionBackground(success: succeeded)
      collectionCancellation = nil; busy = false
      if scheduled == nil { LocalCollectionScheduler.reschedule() }
      if scheduled != nil, UIApplication.shared.connectedScenes.contains(where: { $0.activationState == .foregroundActive }) { restoreStagedFiles() }
      if !collectionPaused { collectionProgress = nil }
      MacTransferManager.appendDebugEvent("Local diagnostics: collection ended; success=\(succeeded), paused=\(collectionPaused), elapsedMs=\(Int((ProcessInfo.processInfo.systemUptime - started) * 1000))")
    }
    MacTransferManager.appendDebugEvent("Local diagnostics: collection started; trigger=\(scheduled != nil ? "OS background wake" : manual ? "manual" : "automatic"), ownDevice=\(credential.physicalDeviceID), dailyDate=\(day)")
    if scheduled == nil { await beginCollectionBackground(manual: manual) }
    let root = stagingRoot(credential.physicalDeviceID)
    let existing = stagedBases(root)
    do {
      let owner = self
      let excluded = try await Task.detached(priority: .utility) {
        var excluded: [String] = []
        _ = try LocalDiagnosticsTransport.logs(credential, address: address,
          alreadyReceived: imported.union(skippedBases).union(existing), cancellation: cancellation,
          progress: { value in Task { @MainActor [weak owner] in
            guard let owner, owner.generation == epoch, owner.collectionCancellation === cancellation, !cancellation.isCancelled else { return }
            owner.publishCollectionProgress(value)
          } }, onLog: { log in
            try cancellation.check()
            guard MacTransferManager.looksLikeBatteryLog(log.bytes) else { excluded.append(log.base); return }
            let header = (try? JSONSerialization.jsonObject(with: Data(log.bytes.prefix { $0 != 10 }))) as? [String: Any]
            let os = (header?["os_version"] as? String ?? "").lowercased().filter { !$0.isWhitespace }
            guard log.source == nil ? os.hasPrefix("iphoneos") : os.hasPrefix("watchos") else { excluded.append(log.base); return }
            // Each complete, validated file is committed before the next read.
            // A force-quit or expired OS budget loses only the unfinished file.
            var url = root
            for component in log.base.components(separatedBy: "::") { url.appendPathComponent(component) }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try cancellation.check()
            try log.bytes.write(to: url, options: [.atomic, .completeFileProtection])
          })
        return excluded
      }.value
      guard generation == epoch, !Task.isCancelled, UIApplication.shared.isProtectedDataAvailable, AppSettings.shared.localAutomaticCollectionEnabled else { return false }
      for base in excluded { skip(base) }
      try cancellation.check()
      if scheduled == nil {
        let count = importStagedFiles(root, parentID: credential.physicalDeviceID)
        message = String(format: text("local_received"), count)
      } else {
        MacTransferManager.appendDebugEvent("Local scheduler: complete files staged; count=\(stagedBases(root).count); existing deduplicated import runs on next foreground activation")
      }
      succeeded = true
    } catch is CancellationError {
      collectionPaused = true; message = text("local_collection_paused")
    } catch {
      if generation == epoch {
        message = text("local_connection_failed")
        MacTransferManager.appendDebugEvent("Local diagnostics: collection failed; stage=authenticated own-device read, errorType=\(String(describing: error)); complete file checkpoints retained")
      }
    }
    return succeeded
  }
  private static func validCheckpoint(_ url: URL) -> Bool {
    guard let metadata = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
      metadata.isRegularFile == true, metadata.isSymbolicLink != true,
      let size = metadata.fileSize, size > 0, size <= 64 * 1024 * 1024,
      let bytes = try? Data(contentsOf: url, options: .mappedIfSafe),
      MacTransferManager.looksLikeBatteryLog(bytes) else { return false }
    return true
  }
  private func stagedBases(_ root: URL) -> Set<String> {
    let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])?.allObjects.compactMap { $0 as? URL } ?? []
    return Set(files.compactMap { url in
      guard Self.validCheckpoint(url) else { return nil }
      let base = url.path.dropFirst(root.path.count + 1).components(separatedBy: "/").joined(separator: "::")
      return CloudSharedLogToken.validBase(base) ? base : nil
    })
  }
  private func importStagedFiles(_ root: URL, parentID: UUID) -> Int {
    let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])?.allObjects.compactMap { $0 as? URL } ?? []
    var batch: [(url: URL, physicalDeviceID: UUID?)] = []
    for url in files.sorted(by: { $0.path < $1.path }) {
      guard Self.validCheckpoint(url) else { continue }
      let base = url.path.dropFirst(root.path.count + 1).components(separatedBy: "/").joined(separator: "::")
      guard let origin = CloudSharedLogToken.measurementOrigin(base: base, origin: parentID),
        let bytes = try? Data(contentsOf: url, options: .mappedIfSafe), MacTransferManager.looksLikeBatteryLog(bytes) else { continue }
      let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
      if let previous = MacTransferManager.shared.receivedLocalDigestState(digest, parentID: parentID, recordOrigin: origin), previous != "inbox" {
        markImported(base, parentID: parentID); try? FileManager.default.removeItem(at: url)
        MacTransferManager.appendDebugEvent("Local diagnostics: checkpoint duplicate withheld; source=\(previous), SHA256=\(digest.prefix(12))")
      } else { batch.append((url, origin)) }
    }
    SharedImportQueue.shared.enqueueBatch(batch)
    return batch.count
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
    let count = importStagedFiles(root, parentID: credential.physicalDeviceID)
    if count > 0 { MacTransferManager.appendDebugEvent("Local diagnostics: recovered \(count) completed file checkpoint(s); shared import queue") }
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

// Recorder is confined to one native fixture worker; progress is called
// synchronously on that same worker, never by the production UI.
nonisolated private final class LocalCollectionFixtureRecorder: @unchecked Sendable {
  var checkpoints: [LocalDiagnosticLog] = []
  var stages: [LocalCollectionProgress.Phase] = []
  func add(_ value: LocalCollectionProgress) { stages.append(value.phase) }
}

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
      await installedImportTask?.value
      let original = credential
      let originalMessage = message
      let osKey = "LocalDiagnosticsLastObservedOSVersion"
      let originalOS = UserDefaults.standard.object(forKey: osKey)
      var expectedChecks = 23
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
        results["passed"] = results.count == expectedChecks && results.values.allSatisfy { $0 }
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
        if let coldCase = config?["coldCase"] as? String {
          expectedChecks += 2
          let staged = root.deletingLastPathComponent().appendingPathComponent("pairingFile.plist")
          var attributesQuery = query; attributesQuery[kSecReturnAttributes as String] = true
          var attributes: CFTypeRef?
          let status = SecItemCopyMatching(attributesQuery as CFDictionary, &attributes)
          if coldCase == "valid" || coldCase == "standard" {
            results["coldStartupAdoptsInstalledFile"] = configured && credential?.expectedUDID == udid &&
              credential?.usesLockdown == true && !FileManager.default.fileExists(atPath: staged.path)
            results["coldStartupUsesDeviceOnlyKeychain"] = status == errSecSuccess &&
              (attributes as? [String: Any])?[kSecAttrAccessible as String] as? String == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
          } else {
            results["coldStartupRejectsUntrustedFile"] = !configured && credential == nil && FileManager.default.fileExists(atPath: staged.path)
            results["coldStartupDoesNotCreateCredential"] = status == errSecItemNotFound
          }
          // Only synthetic inputs on the disposable cold-start simulator.
          if FileManager.default.fileExists(atPath: staged.path) { try FileManager.default.removeItem(at: staged) }
        }
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
        await installedImportTask?.value
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
        try await mode(102)
        try old.write(to: installed, options: .atomic)
        checkInstalledPairingFile()
        await installedImportTask?.value
        results["directInstallRejectsUnauthenticatedMetadata"] = credential?.pairing == old && configured && FileManager.default.fileExists(atPath: installed.path)
        try FileManager.default.removeItem(at: installed)
        try await mode(111)
        var standard = try PropertyListSerialization.propertyList(from: old, format: nil) as! [String: Any]
        standard.removeValue(forKey: "UDID")
        let standardBytes = try PropertyListSerialization.data(fromPropertyList: standard, format: .binary, options: 0)
        let learned = try await Task.detached {
          try LocalDiagnosticsTransport.installedCredential(standardBytes, expectedUDID: nil,
            physicalDeviceID: trusted.physicalDeviceID, address: "127.0.0.1")
        }.value
        results["standardFileLearnsAuthenticatedIdentity"] = learned.expectedUDID == udid && learned.pairing == standardBytes
        for (modeByte, key) in [(UInt8(105), "standardFileRejectsChangedIdentity"), (102, "standardFileRejectsForeignCertificate")] {
          try await mode(modeByte)
          do {
            _ = try await Task.detached {
              try LocalDiagnosticsTransport.installedCredential(standardBytes, expectedUDID: udid,
                physicalDeviceID: trusted.physicalDeviceID, address: "127.0.0.1")
            }.value
            results[key] = false
          } catch { results[key] = credential?.pairing == old && configured }
        }
        try await mode(111)
        let reading = try await battery(trusted)
        results["nativeBattery"] = reading.values["CycleCount"] == 321 && reading.values["DesignCapacity"] == 4000
        let files = try await Task.detached { try LocalDiagnosticsTransport.logs(trusted, address: "127.0.0.1", alreadyReceived: []) }.value
        results["nativeLogBody"] = files.count == 1 && files[0].name == name &&
          SHA256.hash(data: files[0].bytes).map { String(format: "%02x", $0) }.joined() == hash
        let streamed = try await Task.detached {
          let recorder = LocalCollectionFixtureRecorder()
          let returned = try LocalDiagnosticsTransport.logs(trusted, address: "127.0.0.1", alreadyReceived: [],
            progress: { recorder.add($0) }, onLog: { recorder.checkpoints.append($0) })
          return (returned.isEmpty, recorder.checkpoints, recorder.stages)
        }.value
        results["streamedCompleteCheckpoint"] = streamed.0 && streamed.1.count == 1 && streamed.1[0].bytes == files[0].bytes
        results["nativeProgressPhases"] = streamed.2.contains(.connecting) && streamed.2.contains(.listing) &&
          streamed.2.contains(.downloading) && streamed.2.last == .finishing
        let beforeRead = LocalCollectionCancellation(); beforeRead.cancel()
        do {
          _ = try LocalDiagnosticsTransport.logs(trusted, address: "127.0.0.1", alreadyReceived: [], cancellation: beforeRead)
          results["cancelBeforeConnection"] = false
        } catch is CancellationError { results["cancelBeforeConnection"] = true }
        let checkpointSurvives = try await Task.detached {
          let cancellation = LocalCollectionCancellation()
          let recorder = LocalCollectionFixtureRecorder()
          do {
            _ = try LocalDiagnosticsTransport.logs(trusted, address: "127.0.0.1", alreadyReceived: [],
              cancellation: cancellation, progress: { value in
                if value.phase == .downloading && value.bytes > 0 { cancellation.cancel() }
              }, onLog: { recorder.checkpoints.append($0) })
          } catch is CancellationError { return recorder.checkpoints.isEmpty }
          return false
        }.value
        results["cancelledFileNotPublished"] = checkpointSurvives
        let checkpoint = root.appendingPathComponent("completed-checkpoint.ips")
        let retained = try await Task.detached {
          let cancellation = LocalCollectionCancellation()
          do {
            _ = try LocalDiagnosticsTransport.logs(trusted, address: "127.0.0.1", alreadyReceived: [],
              cancellation: cancellation, onLog: { file in
                try file.bytes.write(to: checkpoint, options: .atomic)
                cancellation.cancel()
              })
          } catch is CancellationError { return (try? Data(contentsOf: checkpoint)) == files[0].bytes }
          return false
        }.value
        results["completeCheckpointSurvivesCancellation"] = retained
        try? FileManager.default.removeItem(at: checkpoint)
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
