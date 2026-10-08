import Foundation
import Darwin
import CryptoKit
import idevice

// Standalone research using maintained idevice FFI and an existing remote pairing.
// No DDI mounting, restart/sleep command, record import or production app integration.
// The upstream tunnel helper can fall back to pair-setup if verification fails;
// do not treat this helper as a verify-only production API.
enum FFIProbe {
  static func run() -> [[String: String]] {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let pairURL = documents.appendingPathComponent("probe-pairing.plist")
    let identityURL = documents.appendingPathComponent("probe-identity.plist")
    defer { try? FileManager.default.removeItem(at: pairURL); try? FileManager.default.removeItem(at: identityURL) }
    guard let identityData = try? Data(contentsOf: identityURL),
      let config = try? PropertyListSerialization.propertyList(from: identityData, format: nil) as? [String: String],
      let expected = config["expectedUDID"] else {
      return [["stage": "authentication", "result": "existing pairing input not provided"]]
    }
    var pairing: OpaquePointer?
    if let error = pairURL.path.withCString({ rp_pairing_file_read($0, &pairing) }) {
      let code = error.pointee.code; idevice_error_free(error)
      return [["stage": "pairing-read", "errorCode": String(code)]]
    }
    guard let pairing else { return [["stage": "pairing-read", "result": "missing handle"]] }
    // Remove the temporary input before network access; the library owns an in-memory copy.
    try? FileManager.default.removeItem(at: pairURL)
    defer { rp_pairing_file_free(pairing) }
    idevice_set_global_timeout(8)
    var rows: [[String: String]] = []
    for host in ["10.7.0.1", "127.0.0.1"] {
      var addr = sockaddr_in(); addr.sin_family = sa_family_t(AF_INET)
      addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); addr.sin_port = UInt16(49152).bigEndian
      _ = host.withCString { inet_pton(AF_INET, $0, &addr.sin_addr) }
      var adapter: OpaquePointer?; var handshake: OpaquePointer?
      let error = withUnsafePointer(to: &addr) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          tunnel_create_rppairing($0, socklen_t(MemoryLayout<sockaddr_in>.stride), "MochiLogLocalDevResearch",
            pairing, nil, nil, &adapter, &handshake)
        }
      }
      if let error {
        rows.append(errorRow(stage: "authenticated tunnel", host: host, error: error)); continue
      }
      guard let adapter, let handshake else {
        rows.append(["stage": "authenticated tunnel", "host": host, "result": "missing handles"]); continue
      }
      defer { rsd_handshake_free(handshake); adapter_free(adapter) }
      rows.append(["stage": "authenticated tunnel", "host": host, "result": "ready"])
      var lockdown: OpaquePointer?
      if let error = lockdownd_connect_rsd(adapter, handshake, &lockdown) {
        rows.append(errorRow(stage: "identity", host: host, error: error)); continue
      }
      guard let lockdown else { continue }
      defer { lockdownd_client_free(lockdown) }
      var identity: plist_t?
      if let error = lockdownd_get_value(lockdown, "UniqueDeviceID", nil, &identity) {
        rows.append(errorRow(stage: "identity", host: host, error: error)); continue
      }
      let actual = value(identity) as? String
      if let identity { plist_free(identity) }
      guard actual == expected else {
        rows.append(["stage": "identity", "host": host, "result": "device mismatch; stopped"]); continue
      }
      rows.append(["stage": "identity", "host": host, "result": "own device verified"])
      for service in ["com.apple.mobile.diagnostics_relay.shim.remote", "com.apple.crashreportcopymobile.shim.remote"] {
        var available = false
        if let error = rsd_service_available(handshake, service, &available) { idevice_error_free(error) }
        rows.append(["stage": "service available", "host": host, "service": service, "available": String(available)])
      }
      var diagnostics: OpaquePointer?
      if let error = diagnostics_relay_client_connect_rsd(adapter, handshake, &diagnostics) {
        rows.append(errorRow(stage: "battery service", host: host, error: error))
      } else if let diagnostics {
        defer { diagnostics_relay_client_free(diagnostics) }
        var node: plist_t?
        if let error = diagnostics_relay_client_ioregistry(diagnostics, nil, nil, "IOPMPowerSource", &node) {
          rows.append(errorRow(stage: "battery query", host: host, error: error))
        } else {
          let battery = value(node)
          var keys: [String] = []
          func collect(_ object: Any?) {
            if let d = object as? [String: Any] {
              for (key, val) in d {
                if ["CycleCount", "DesignCapacity", "AppleRawMaxCapacity", "NominalChargeCapacity", "FullChargeCapacity"].contains(key), val is NSNumber { keys.append(key) }
                collect(val)
              }
            } else if let list = object as? [Any] { list.forEach { collect($0) } }
          }
          collect(battery)
          rows.append(["stage": "battery query", "host": host, "result": "response received",
            "numericMetricNames": Set(keys).sorted().joined(separator: ","), "valuesPersisted": "false"])
        }
        if let node { plist_free(node) }
      }
      var crash: OpaquePointer?
      if let error = crash_report_client_connect_rsd(adapter, handshake, &crash) {
        rows.append(errorRow(stage: "daily files", host: host, error: error))
      } else if let crash {
        var candidates: [String] = []
        var directories = ["/", "/Retired"]
        var directoryIndex = 0
        while directoryIndex < directories.count {
          let directory = directories[directoryIndex]; directoryIndex += 1
          var entries: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?; var count = 0
          if let error = crash_report_client_ls(crash, directory, &entries, &count) {
            rows.append(errorRow(stage: "daily directory", host: host, error: error))
          } else {
            let names = (0..<count).compactMap { entries?[$0].map { String(cString: $0) } }
            if directory == "/" {
              let proxied = names.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }.filter {
                $0.range(of: #"^ProxiedDevice-[a-fA-F0-9]+$"#, options: .regularExpression) != nil
              }.prefix(10)
              for source in proxied { directories += ["/" + source, "/" + source + "/Retired"] }
              rows.append(["stage": "proxied accessories", "host": host, "directories": String(proxied.count)])
            }
            let analytics = names.filter {
              $0.range(of: #"^Analytics-[0-9]{4}-[0-9]{2}-[0-9]{2}-"#, options: .regularExpression) != nil
                && !$0.lowercased().contains("session")
            }
            candidates += analytics.map { directory == "/" ? "/" + $0 : directory + "/" + $0 }
            let displayDirectory = directory.hasPrefix("/ProxiedDevice-") ? "/ProxiedDevice-[redacted]" + (directory.hasSuffix("/Retired") ? "/Retired" : "") : directory
            rows.append(["stage": "daily directory", "host": host, "directory": displayDirectory,
              "entries": String(count), "analyticsCandidates": String(analytics.count)])
            // Includes the null sentinel; match the Rust allocation length.
            if let entries { device_info_string_array_free(entries, UInt(count + 1)) }
          }
        }
        // This conversion consumes the crash client even on failure.
        var afc: OpaquePointer?
        if let error = crash_report_client_to_afc(crash, &afc) {
          rows.append(errorRow(stage: "daily AFC", host: host, error: error))
        } else if let afc {
          defer { afc_client_free(afc) }
          var substantial: [String] = []
          for path in candidates {
            var info = AfcFileInfo()
            if let error = afc_get_file_info(afc, path, &info) { idevice_error_free(error); continue }
            if info.size >= 512 * 1024 && info.size < 48 * 1024 * 1024 { substantial.append(path) }
            afc_file_info_free(&info)
          }
          // Sampling heuristic only, not a production eligibility rule. Verify body markers below.
          rows.append(["stage": "daily sampling", "host": host, "substantialCandidates": String(substantial.count)])
          var sampledPlatforms: Set<String> = []
          for path in substantial.sorted(by: { ($0 as NSString).lastPathComponent > ($1 as NSString).lastPathComponent }).prefix(8) {
            let row = readDailyFile(afc: afc, path: path, host: host, sampledPlatforms: sampledPlatforms)
            rows.append(row)
            if row["fileBodyRead"] == "true", let platform = row["logPlatform"] { sampledPlatforms.insert(platform) }
            if sampledPlatforms.contains("watchOS") && sampledPlatforms.contains("iPhone OS") { break }
          }
        }
      }
    }
    return rows
  }
  static func readDailyFile(afc: OpaquePointer, path: String, host: String, sampledPlatforms: Set<String>) -> [String: String] {
    var file: OpaquePointer?
    if let error = afc_file_open(afc, path, AfcRdOnly, &file) {
      return errorRow(stage: "daily body", host: host, error: error)
    }
    guard let file else { return ["stage": "daily body", "result": "missing handle"] }
    defer { if let error = afc_file_close(file) { idevice_error_free(error) } }
    var initial: UnsafeMutablePointer<UInt8>?; var initialCount = 0
    if let error = afc_file_read(file, &initial, 64 * 1024, &initialCount) {
      return errorRow(stage: "daily header", host: host, error: error)
    }
    var data = Data()
    if let initial { data.append(initial, count: initialCount); afc_file_read_data_free(initial, initialCount) }
    // Classify only the JSON header. Mentioning watchOS elsewhere in an iPad
    // report does not make that report an Apple Watch log.
    let headerBytes = data.prefix { $0 != 10 }
    let header = (try? JSONSerialization.jsonObject(with: Data(headerBytes))) as? [String: Any]
    let os = header?["os_version"] as? String ?? ""
    let normalizedOS = os.lowercased().filter { !$0.isWhitespace }
    let platform = normalizedOS.hasPrefix("watchos") ? "watchOS" : (normalizedOS.hasPrefix("iphoneos") ? "iPhone OS" : "unknown")
    if sampledPlatforms.contains(platform) {
      return ["stage": "daily header", "host": host, "logPlatform": platform, "result": "already sampled; skipped body"]
    }
    var complete = initialCount == 0
    let limit = 48 * 1024 * 1024
    while data.count < limit {
      var chunk: UnsafeMutablePointer<UInt8>?; var count = 0
      if let error = afc_file_read(file, &chunk, UInt(min(64 * 1024, limit - data.count)), &count) {
        return errorRow(stage: "daily body", host: host, error: error)
      }
      if let chunk {
        data.append(chunk, count: count)
        afc_file_read_data_free(chunk, count)
      }
      if count == 0 { complete = true; break }
    }
    let text = String(decoding: data, as: UTF8.self)
    let lines = data.reduce(0) { $0 + ($1 == 10 ? 1 : 0) }
    let markers = ["last_value_CycleCount", "last_value_NominalChargeCapacity"].filter { text.contains($0) }
    let date = String((path as NSString).lastPathComponent.dropFirst("Analytics-".count).prefix(10))
    return ["stage": "daily body", "host": host, "logDate": date,
      "bytes": String(data.count), "lines": String(lines), "complete": String(complete),
      "batteryMarkers": markers.joined(separator: ","),
      "logPlatform": platform,
      "fileBodyRead": String(complete && lines >= 100 && !markers.isEmpty),
      "sha256": SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
      "bodyPersisted": "false"]
  }
  static func errorRow(stage: String, host: String, error: UnsafeMutablePointer<IdeviceFfiError>) -> [String: String] {
    let result = ["stage": stage, "host": host, "errorCode": String(error.pointee.code),
      "error": error.pointee.message.map { String(String(cString: $0).prefix(300)) } ?? "unknown"]
    idevice_error_free(error); return result
  }
  static func value(_ node: plist_t?) -> Any? {
    guard let node else { return nil }
    var xml: UnsafeMutablePointer<CChar>?; var length: UInt32 = 0
    guard plist_to_xml(node, &xml, &length) == PLIST_ERR_SUCCESS, let xml else { return nil }
    defer { plist_mem_free(xml) }
    return try? PropertyListSerialization.propertyList(from: Data(bytes: xml, count: Int(length)), format: nil)
  }
}
