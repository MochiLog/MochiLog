import BackgroundTasks
import Combine
import Darwin
import Foundation
import UIKit
import UserNotifications
import idevice

/// Explicit, device-initiated OS trust. Normal reads still use verify-only.
@available(iOS 27, *)
@MainActor
final class LocalDevicePairing: NSObject, ObservableObject, NetServiceDelegate {
  static let shared = LocalDevicePairing()
  private static let taskID = "net.ryuya-dev.MochiLog.local-pairing"
  @Published private(set) var active = false
  @Published private(set) var pin = ""
  @Published private(set) var statusKey = "local_pair_ready"
  @Published private(set) var shortBackground = false
  private var worker: LocalPairingWorker?
  private var service: NetService?
  private var processing: BGContinuedProcessingTask?
  private var background = UIBackgroundTaskIdentifier.invalid
  private var timeout: Task<Void, Never>?
  private var token: UUID?
  @Published private(set) var hostName = ""
  private let notificationID = "MochiLogLocalPairingPIN"
  private static var registered = false

  static func register() {
    guard !registered, !ProcessInfo.processInfo.isiOSAppOnMac else { return }
    registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: .main) { task in
      guard let task = task as? BGContinuedProcessingTask else { task.setTaskCompleted(success: false); return }
      Task { @MainActor in
        let owner = shared
        guard owner.active, owner.worker == nil else { task.setTaskCompleted(success: false); return }
        owner.processing = task
        task.progress.totalUnitCount = 100
        task.progress.completedUnitCount = 1
        task.expirationHandler = { Task { @MainActor in owner.finish(success: false, key: "local_pair_expired") } }
        owner.launch()
      }
    }
  }

  func start() {
    guard !active, !ProcessInfo.processInfo.isiOSAppOnMac else { return }
    Self.register()
    active = true; token = UUID(); pin = ""; shortBackground = false
    hostName = "MochiLog-" + (UIDevice.current.userInterfaceIdiom == .pad ? "iPad-" : "iPhone-") + UUID().uuidString.prefix(8)
    statusKey = "local_pair_preparing"
    LocalDiagnosticsManager.shared.stop()
    MacTransferManager.appendDebugEvent("Local pairing: explicitly started; own-device only, random PIN required; existing credentials retained")
    let request = BGContinuedProcessingTaskRequest(identifier: Self.taskID,
      title: text("local_pair_title"), subtitle: text("local_pair_waiting"))
    request.strategy = .fail
    let attempt = token
    Task { [weak self] in
      do { try await Task.detached(priority: .userInitiated) { try await BGTaskScheduler.shared.submitTaskRequest(request) }.value }
      catch {
        guard let self, self.active, self.token == attempt, self.worker == nil else { return }
        self.shortBackground = true
        self.background = UIApplication.shared.beginBackgroundTask(withName: "MochiLog OS pairing") { [weak self] in
          Task { @MainActor [weak self] in self?.finish(success: false, key: "local_pair_expired") }
        }
        MacTransferManager.appendDebugEvent("Local pairing: continued processing unavailable; limited OS background time")
        self.launch()
      }
    }
    timeout = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(300)) } catch { return }
      self?.finish(success: false, key: "local_pair_expired")
    }
    // Notifications are optional; the OS task banner and in-app screen also show the code.
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
  }

  private func launch() {
    guard active, worker == nil, let token else { return }
    let worker = LocalPairingWorker(physicalID: PhysicalDeviceIdentityStore.current(), hostName: hostName)
    self.worker = worker
    worker.ready = { [weak self] id, port, txt in Task { @MainActor [weak self] in
      guard let self, self.token == token, self.active else { return }
      let service = NetService(domain: "local.", type: "_remotepairing-pairable-host._tcp.", name: id, port: Int32(port))
      service.delegate = self
      service.setTXTRecord(NetService.data(fromTXTRecord: txt))
      self.service = service; service.publish()
    } }
    worker.code = { [weak self] code in Task { @MainActor [weak self] in
      guard let self, self.token == token, self.active else { return }
      self.pin = code; self.statusKey = "local_pair_enter_code"
      self.processing?.progress.completedUnitCount = 50
      self.processing?.updateTitle(self.text("local_pair_title"), subtitle: self.text("local_pair_code") + ": " + code)
      let content = UNMutableNotificationContent()
      content.title = self.text("local_pair_title")
      content.body = self.text("local_pair_code") + ": " + code
      content.sound = .default
      let center = UNUserNotificationCenter.current()
      try? await center.add(UNNotificationRequest(identifier: self.notificationID, content: content, trigger: nil))
      guard self.token == token, self.active else {
        center.removeDeliveredNotifications(withIdentifiers: [self.notificationID]); return
      }
      MacTransferManager.appendDebugEvent("Local pairing: OS requested confirmation; PIN not logged")
    } }
    worker.result = { [weak self] result in Task { @MainActor [weak self] in
      guard let self, self.token == token, self.active else { return }
      switch result {
      case .success(let credential):
        do {
          try LocalDiagnosticsManager.shared.importPairing(credential.pairing, expectedUDID: credential.expectedUDID)
          self.finish(success: true, key: "local_pair_complete")
        } catch { self.finish(success: false, key: "local_pair_failed") }
      case .failure(let error):
        MacTransferManager.appendDebugEvent("Local pairing: handshake failed; errorType=\(error); no credential or PIN logged")
        self.finish(success: false, key: "local_pair_failed")
      }
    } }
    worker.run()
  }

  func cancel() { finish(success: false, key: "local_pair_cancelled") }
  private func finish(success: Bool, key: String) {
    guard active else { return }
    active = false; token = nil; pin = ""; statusKey = key
    service?.stop(); service = nil
    worker?.cancel(); worker = nil
    timeout?.cancel(); timeout = nil
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskID)
    processing?.updateTitle(text("local_pair_title"), subtitle: text(key))
    if success { processing?.progress.completedUnitCount = 100 }
    processing?.setTaskCompleted(success: success); processing = nil
    if background != .invalid { UIApplication.shared.endBackgroundTask(background); background = .invalid }
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationID])
    MacTransferManager.appendDebugEvent("Local pairing: \(success ? "completed; own-device credential saved in device-only Keychain" : "stopped; existing credential preserved"), reason=\(key)")
    LocalDiagnosticsManager.shared.updateActivity()
  }

  nonisolated func netServiceDidPublish(_ sender: NetService) {
    Task { @MainActor in
      guard self.service === sender, self.active else { return }
      self.statusKey = "local_pair_waiting"
      self.processing?.progress.completedUnitCount = 10
      MacTransferManager.appendDebugEvent("Local pairing: Bonjour host published; waiting for explicit OS authorization")
    }
  }
  nonisolated func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
    Task { @MainActor in
      guard self.service === sender else { return }
      self.finish(success: false, key: "local_pair_failed")
    }
  }
  private func text(_ key: String) -> String { L10n.text(key, table: "MacTransfer") }
}

/// Socket lifetime and blocking FFI calls belong to one worker thread.
nonisolated final class LocalPairingWorker: @unchecked Sendable {
  var ready: (@Sendable (String, UInt16, [String: Data]) -> Void)?
  var code: (@Sendable (String) -> Void)?
  var result: (@Sendable (Result<LocalDiagnosticsCredential, LocalDiagnosticsTransport.Failure>) -> Void)?
  private let physicalID: UUID
  private let hostName: String
  private let lock = NSLock()
  private var stopped = false
  private var sockets: Set<Int32> = []
  init(physicalID: UUID, hostName: String) { self.physicalID = physicalID; self.hostName = hostName }
  func cancel() {
    lock.lock(); defer { lock.unlock() }
    stopped = true
    for fd in sockets { _ = shutdown(fd, SHUT_RDWR) }
  }
  private var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
  private func own(_ fd: Int32) { lock.lock(); sockets.insert(fd); if stopped { _ = shutdown(fd, SHUT_RDWR) }; lock.unlock() }
  private func release(_ fd: Int32) { lock.lock(); sockets.remove(fd); _ = close(fd); lock.unlock() }
  func run() {
    DispatchQueue.global(qos: .userInitiated).async {
      do { self.result?(.success(try self.pair())) }
      catch { self.result?(.failure(error as? LocalDiagnosticsTransport.Failure ?? .invalid)) }
    }
  }
  private func pair() throws -> LocalDiagnosticsCredential {
    var handle: OpaquePointer?; var serviceID: UnsafeMutablePointer<CChar>?
    var txt: UnsafeMutablePointer<UInt8>?; var length = 0
    // A fresh host identity also preserves an earlier on-device trust on failure.
    let name = hostName
    try name.withCString { try LocalDiagnosticsTransport.check(pairable_host_prepare($0, nil, false, &handle, &serviceID, &txt, &length, nil)) }
    defer { if let handle { pairable_host_free(handle) }; if let serviceID { idevice_string_free(serviceID) }; if let txt { idevice_data_free(txt, UInt(length)) } }
    guard let handle, let serviceID, let txt, length > 0, length < 65536,
      let records = try PropertyListSerialization.propertyList(from: Data(bytes: txt, count: length), format: nil) as? [String: String] else { throw LocalDiagnosticsTransport.Failure.invalid }
    let server = socket(AF_INET6, SOCK_STREAM, 0)
    guard server >= 0 else { throw LocalDiagnosticsTransport.Failure.invalid }
    own(server); defer { release(server) }
    var dual: Int32 = 0
    guard setsockopt(server, IPPROTO_IPV6, IPV6_V6ONLY, &dual, socklen_t(MemoryLayout<Int32>.size)) == 0 else { throw LocalDiagnosticsTransport.Failure.invalid }
    var address = sockaddr_in6(); address.sin6_family = sa_family_t(AF_INET6); address.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
    guard withUnsafePointer(to: &address, { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(server, $0, socklen_t(MemoryLayout<sockaddr_in6>.size)) } }) == 0,
      listen(server, 4) == 0 else { throw LocalDiagnosticsTransport.Failure.invalid }
    var size = socklen_t(MemoryLayout<sockaddr_in6>.size)
    guard withUnsafeMutablePointer(to: &address, { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(server, $0, &size) } }) == 0 else { throw LocalDiagnosticsTransport.Failure.invalid }
    ready?(String(cString: serviceID), UInt16(bigEndian: address.sin6_port), records.mapValues { Data($0.utf8) })
    let deadline = Date().addingTimeInterval(300)
    while !cancelled && Date() < deadline {
      var waiter = pollfd(fd: server, events: Int16(POLLIN), revents: 0)
      let polled = poll(&waiter, 1, 1000)
      if polled == 0 { continue }
      guard polled > 0, waiter.revents & Int16(POLLIN) != 0 else { throw LocalDiagnosticsTransport.Failure.invalid }
      var peer = sockaddr_storage(); var peerSize = socklen_t(MemoryLayout<sockaddr_storage>.size)
      let fd = withUnsafeMutablePointer(to: &peer) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { accept(server, $0, &peerSize) } }
      guard fd >= 0 else { continue }
      own(fd); defer { release(fd) }
      // Never accept another LAN device for this own-device feature.
      guard LocalPairingAddressPolicy.isOwnAddress(peer, length: peerSize) else { continue }
      var paired: OpaquePointer?; var device: UnsafeMutablePointer<RpPairingPeerDeviceC>?
      defer { if let paired { rp_pairing_file_free(paired) }; if let device { rppairing_peer_device_free(device) } }
      let callback: PairableHostPinCb = { pin, context in
        guard let pin, let context else { return }
        let owner = Unmanaged<LocalPairingWorker>.fromOpaque(context).takeUnretainedValue()
        let value = String(cString: pin)
        guard !owner.cancelled, value.count == 6, value.allSatisfy({ $0.isNumber }) else { return }
        owner.code?(value)
      }
      try LocalDiagnosticsTransport.check(pairable_host_accept_fd(handle, fd, callback, Unmanaged.passUnretained(self).toOpaque(), &device, &paired))
      guard !cancelled, let paired, let udid = device?.pointee.udid else { throw LocalDiagnosticsTransport.Failure.invalid }
      var bytes: UnsafeMutablePointer<UInt8>?; var count = 0
      try LocalDiagnosticsTransport.check(rp_pairing_file_to_bytes(paired, &bytes, &count))
      defer { if let bytes { idevice_data_free(bytes, UInt(count)) } }
      guard let bytes, count > 0, count <= 65536 else { throw LocalDiagnosticsTransport.Failure.invalid }
      return try LocalDiagnosticsCredential.validate(Data(bytes: bytes, count: count), expectedUDID: String(cString: udid), physicalDeviceID: physicalID)
    }
    throw LocalDiagnosticsTransport.Failure.invalid
  }
}
