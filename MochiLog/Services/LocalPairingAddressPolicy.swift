import Darwin
import Foundation

/// The on-device pairing host must never pair a different LAN device.
nonisolated enum LocalPairingAddressPolicy {
  static func privateDiagnosticAddress(_ text: String) -> String? {
    let parts = text.split(separator: ".", omittingEmptySubsequences: false)
    let bytes = parts.compactMap { UInt8($0) }
    guard parts.count == 4, bytes.count == 4,
      zip(parts, bytes).allSatisfy({ String($0.1) == $0.0 }),
      bytes[0] == 10 || (bytes[0] == 172 && (16...31).contains(bytes[1]))
        || (bytes[0] == 192 && bytes[1] == 168)
    else { return nil }
    return bytes.map(String.init).joined(separator: ".")
  }

  /// The VPN socket peer can be a translated address. Advertise the device's
  /// own Wi-Fi/Ethernet addresses only inside the sealed v3 request instead.
  static func diagnosticLANAddresses() -> [String] {
    var list: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&list) == 0 else { return [] }
    defer { freeifaddrs(list) }
    var result: [String] = []
    var current = list
    while let item = current {
      defer { current = item.pointee.ifa_next }
      guard item.pointee.ifa_flags & UInt32(IFF_UP) != 0,
        String(cString: item.pointee.ifa_name).hasPrefix("en"),
        let pointer = item.pointee.ifa_addr, pointer.pointee.sa_family == sa_family_t(AF_INET),
        let text = numeric(UnsafePointer(pointer), length: socklen_t(pointer.pointee.sa_len)),
        let address = privateDiagnosticAddress(text), !result.contains(address)
      else { continue }
      result.append(address)
      if result.count == 4 { break }
    }
    return result.sorted()
  }

  static func addingDiagnosticRouteHints(to request: [String: String]) -> [String: String] {
    var result = request
    guard let bytes = try? JSONEncoder().encode(diagnosticLANAddresses()),
      let addresses = String(data: bytes, encoding: .utf8)
    else { return request }
    result["diagnosticAddressVersion"] = "1"
    result["diagnosticAddresses"] = addresses
    return result
  }

  private static func numeric(_ pointer: UnsafePointer<sockaddr>, length: socklen_t) -> String? {
    var name = [CChar](repeating: 0, count: Int(NI_MAXHOST))
    guard getnameinfo(pointer, length, &name, socklen_t(name.count), nil, 0, NI_NUMERICHOST) == 0
    else { return nil }
    return String(cString: name).components(separatedBy: "%")[0].replacingOccurrences(
      of: "::ffff:", with: "")
  }
  static func isOwnAddress(_ peer: sockaddr_storage, length: socklen_t) -> Bool {
    var peer = peer
    guard
      let source = withUnsafePointer(
        to: &peer,
        { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { numeric($0, length: length) } })
    else { return false }
    var list: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&list) == 0 else { return false }
    defer { freeifaddrs(list) }
    var current = list
    while let item = current {
      defer { current = item.pointee.ifa_next }
      guard let address = item.pointee.ifa_addr,
        [sa_family_t(AF_INET), sa_family_t(AF_INET6)].contains(address.pointee.sa_family)
      else { continue }
      if numeric(UnsafePointer(address), length: socklen_t(address.pointee.sa_len)) == source {
        return true
      }
    }
    return false
  }
}
