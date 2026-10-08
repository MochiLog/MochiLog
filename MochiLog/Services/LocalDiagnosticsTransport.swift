import CryptoKit
import Darwin
import Foundation
import idevice

nonisolated struct LocalDiagnosticsCredential: Codable, Sendable {
  let expectedUDID: String
  let physicalDeviceID: UUID
  let pairing: Data
  static func validate(_ data: Data, expectedUDID: String, physicalDeviceID: UUID) throws -> Self {
    guard data.count <= 65536, expectedUDID.range(of: "^[A-Fa-f0-9-]{16,64}$", options: .regularExpression) != nil,
      let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { throw LocalDiagnosticsTransport.Failure.invalid }
    if plist["public_key"] != nil || plist["private_key"] != nil {
      guard plist["HostID"] == nil, let pub = plist["public_key"] as? Data, pub.count == 32,
        let priv = plist["private_key"] as? Data, priv.count == 32,
        let id = plist["identifier"] as? String, !id.isEmpty, id.count <= 128 else { throw LocalDiagnosticsTransport.Failure.invalid }
    } else {
      guard ["DeviceCertificate", "HostCertificate", "HostPrivateKey", "RootCertificate", "RootPrivateKey"].allSatisfy({
        guard let bytes = plist[$0] as? Data else { return false }; return !bytes.isEmpty
      }), ["HostID", "SystemBUID"].allSatisfy({ (plist[$0] as? String)?.isEmpty == false }),
        plist["WiFiMACAddress"] is String,
        plist["UDID"] == nil || plist["UDID"] as? String == expectedUDID else { throw LocalDiagnosticsTransport.Failure.invalid }
      // Let the maintained parser also validate the certificate/key encodings.
      var parsed: OpaquePointer?
      try data.withUnsafeBytes { try LocalDiagnosticsTransport.check(idevice_pairing_file_from_bytes($0.bindMemory(to: UInt8.self).baseAddress, UInt($0.count), &parsed)) }
      guard let parsed else { throw LocalDiagnosticsTransport.Failure.invalid }
      idevice_pairing_file_free(parsed)
    }
    return Self(expectedUDID: expectedUDID, physicalDeviceID: physicalDeviceID, pairing: data)
  }
  var usesLockdown: Bool {
    (try? PropertyListSerialization.propertyList(from: pairing, format: nil) as? [String: Any])?["HostID"] != nil
  }

}

nonisolated struct LocalDiagnosticLog: Sendable {
  let name: String
  let source: String?
  let bytes: Data
  var base: String { ([source == nil ? "Host" : "Watch"] + (source.map { [$0] } ?? []) + [name]).joined(separator: "::") }
}

/// The maintained library owns authentication/TLS/RSD/AFC. Calls stay on one
/// worker thread per session; each job gets an independent authenticated tunnel.
nonisolated enum LocalDiagnosticsTransport {
  enum Failure: Error { case invalid, identity, service(Int32), oversized }
  private static let initialize: Void = { idevice_set_global_timeout(8) }()
  static func check(_ error: UnsafeMutablePointer<IdeviceFfiError>?) throws {
    if let error { let code = error.pointee.code; idevice_error_free(error); throw Failure.service(Int32(code)) }
  }
  enum Connection {
    case remote(OpaquePointer, OpaquePointer)
    case lockdown(OpaquePointer)
    func batteryClient(_ client: inout OpaquePointer?) throws {
      switch self {
      case .remote(let adapter, let handshake): try check(diagnostics_relay_client_connect_rsd(adapter, handshake, &client))
      case .lockdown(let provider): try check(diagnostics_relay_client_connect(provider, &client))
      }
    }
    func crashClient(_ client: inout OpaquePointer?) throws {
      switch self {
      case .remote(let adapter, let handshake): try check(crash_report_client_connect_rsd(adapter, handshake, &client))
      case .lockdown(let provider): try check(crash_report_client_connect(provider, &client))
      }
    }
  }
  /// Imported legacy records use authenticated lockdown; no automatic fallback
  /// from a failed remote verification and no new trust request during reads.
  private static func lockdownSession<T>(_ credential: LocalDiagnosticsCredential, address: String,
    work: (Connection) throws -> T) throws -> T {
    var pair: OpaquePointer?
    try credential.pairing.withUnsafeBytes { try check(idevice_pairing_file_from_bytes($0.bindMemory(to: UInt8.self).baseAddress, UInt($0.count), &pair)) }
    guard let parsed = pair else { throw Failure.invalid }
    defer { if let pair { idevice_pairing_file_free(pair) } }
    var addr = sockaddr_in(); addr.sin_family = sa_family_t(AF_INET)
    addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    guard address.withCString({ inet_pton(AF_INET, $0, &addr.sin_addr) }) == 1 else { throw Failure.invalid }
    var provider: OpaquePointer?
    try withUnsafePointer(to: &addr) { pointer in
      try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        try check(idevice_tcp_provider_new($0, parsed, "MochiLogLocalDiagnostics", &provider))
      }
    }
    pair = nil // Provider owns the parsed record after successful creation.
    guard let provider else { throw Failure.invalid }
    defer { idevice_provider_free(provider) }
    var lockdown: OpaquePointer?
    try check(lockdownd_connect(provider, &lockdown))
    guard let lockdown else { throw Failure.invalid }
    defer { lockdownd_client_free(lockdown) }
    var sessionPair: OpaquePointer?
    try check(idevice_provider_get_pairing_file(provider, &sessionPair))
    guard let sessionPair else { throw Failure.invalid }
    defer { idevice_pairing_file_free(sessionPair) }
    try check(lockdownd_start_session(lockdown, sessionPair))
    var identity: plist_t?
    try check(lockdownd_get_value(lockdown, "UniqueDeviceID", nil, &identity))
    defer { if let identity { plist_free(identity) } }
    guard value(identity) as? String == credential.expectedUDID else { throw Failure.identity }
    return try work(.lockdown(provider))
  }
  static func session<T>(_ credential: LocalDiagnosticsCredential, address: String,
    work: (Connection) throws -> T) throws -> T {
    _ = initialize
    if credential.usesLockdown { return try lockdownSession(credential, address: address, work: work) }
    var pair: OpaquePointer?
    try credential.pairing.withUnsafeBytes { bytes in
      try check(rp_pairing_file_from_bytes(bytes.bindMemory(to: UInt8.self).baseAddress, UInt(bytes.count), &pair))
    }
    guard let pair else { throw Failure.invalid }
    defer { rp_pairing_file_free(pair) }
    var addr = sockaddr_in(); addr.sin_family = sa_family_t(AF_INET)
    addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); addr.sin_port = UInt16(49152).bigEndian
    guard address.withCString({ inet_pton(AF_INET, $0, &addr.sin_addr) }) == 1 else { throw Failure.invalid }
    var adapter: OpaquePointer?; var handshake: OpaquePointer?
    try withUnsafePointer(to: &addr) { pointer in
      try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        try check(mochilog_tunnel_verify_rppairing($0, socklen_t(MemoryLayout<sockaddr_in>.stride),
          "MochiLogLocalDiagnostics", pair, nil, nil, &adapter, &handshake))
      }
    }
    guard let adapter, let handshake else { throw Failure.invalid }
    defer { rsd_handshake_free(handshake); adapter_free(adapter) }
    var lockdown: OpaquePointer?
    try check(lockdownd_connect_rsd(adapter, handshake, &lockdown))
    guard let lockdown else { throw Failure.invalid }
    defer { lockdownd_client_free(lockdown) }
    var identity: plist_t?
    try check(lockdownd_get_value(lockdown, "UniqueDeviceID", nil, &identity))
    defer { if let identity { plist_free(identity) } }
    guard value(identity) as? String == credential.expectedUDID else { throw Failure.identity }
    return try work(.remote(adapter, handshake))
  }
  static func battery(_ credential: LocalDiagnosticsCredential, address: String) throws -> LiveBatteryReading {
    try session(credential, address: address) { connection in
      var client: OpaquePointer?
      try connection.batteryClient(&client)
      guard let client else { throw Failure.invalid }
      defer { diagnostics_relay_client_free(client) }
      var node: plist_t?
      try check(diagnostics_relay_client_ioregistry(client, nil, nil, "IOPMPowerSource", &node))
      defer { if let node { plist_free(node) } }
      guard let dictionary = value(node) as? [String: Any] else { throw Failure.invalid }
      return try LocalBatteryCodec.reading(dictionary)
    }
  }
  static func logs(_ credential: LocalDiagnosticsCredential, address: String,
    alreadyReceived: Set<String>) throws -> [LocalDiagnosticLog] {
    try session(credential, address: address) { connection in
      var crash: OpaquePointer?
      try connection.crashClient(&crash)
      guard let crash else { throw Failure.invalid }
      // to_afc consumes crash even on failure.
      var consumed = false
      defer { if !consumed { crash_report_client_free(crash) } }
      func listing(_ path: String) throws -> [String] {
        var list: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
        var count = 0
        try check(crash_report_client_ls(crash, path, &list, &count))
        defer { if let list { mochilog_crash_entries_free(list, UInt(count)) } }
        guard count <= 10000 else { throw Failure.oversized }
        let entries = (0..<count).compactMap { list?[$0].map { String(cString: $0) } }
        return entries
      }
      let root = try listing("/")
      var directories: [(String, String?)] = [("/", nil), ("/Retired", nil)]
      for entry in root {
        let name = (entry as NSString).lastPathComponent
        if name.range(of: "^ProxiedDevice-[a-fA-F0-9]+$", options: .regularExpression) != nil {
          directories += [("/" + name, name), ("/" + name + "/Retired", name)]
        }
      }
      var candidates: [(String, String?, String)] = []; var seen: Set<String> = []
      for (directory, source) in directories {
        let entries = directory == "/" ? root : (try? listing(directory)) ?? []
        for entry in entries {
          let name = (entry as NSString).lastPathComponent
          let base = ([source == nil ? "Host" : "Watch"] + (source.map { [$0] } ?? []) + [name]).joined(separator: "::")
          guard CloudSharedLogToken.validBase(base), !alreadyReceived.contains(base), seen.insert(base).inserted else { continue }
          candidates.append((directory == "/" ? "/" + name : directory + "/" + name, source, name))
        }
      }
      var afc: OpaquePointer?; consumed = true
      try check(crash_report_client_to_afc(crash, &afc))
      guard let afc else { throw Failure.invalid }
      defer { afc_client_free(afc) }
      var results: [LocalDiagnosticLog] = []
      var totalBytes = 0
      var lastFailure: Error?
      for (path, source, name) in candidates.sorted(by: { $0.2 > $1.2 }).prefix(16) {
        // Bound retained memory as well as each file; reconnect uses staged digests.
        guard totalBytes < 96 * 1024 * 1024 else { break }
        do {
          let data: Data = try {
            var file: OpaquePointer?
            try check(afc_file_open(afc, path, AfcRdOnly, &file))
            guard let file else { throw Failure.invalid }
            defer { if let error = afc_file_close(file) { idevice_error_free(error) } }
            var data = Data()
            while true {
              var chunk: UnsafeMutablePointer<UInt8>?; var count = 0
              try check(afc_file_read(file, &chunk, 65536, &count))
              if let chunk { data.append(chunk, count: count); afc_file_read_data_free(chunk, count) }
              guard data.count <= 64 * 1024 * 1024 else { throw Failure.oversized }
              if count == 0 { break }
            }
            return data
          }()
          totalBytes += data.count
          results.append(LocalDiagnosticLog(name: name, source: source, bytes: data))
        } catch { lastFailure = error }
      }
      if results.isEmpty, let lastFailure { throw lastFailure }
      return results
    }
  }
  static func value(_ node: plist_t?) -> Any? {
    guard let node else { return nil }
    var xml: UnsafeMutablePointer<CChar>?; var length: UInt32 = 0
    guard plist_to_xml(node, &xml, &length) == PLIST_ERR_SUCCESS, let xml, length <= 1048576 else { return nil }
    defer { plist_mem_free(xml) }
    return try? PropertyListSerialization.propertyList(from: Data(bytes: xml, count: Int(length)), format: nil)
  }
}
