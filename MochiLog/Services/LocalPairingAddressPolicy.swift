import Darwin
import Foundation

/// The on-device pairing host must never pair a different LAN device.
nonisolated enum LocalPairingAddressPolicy {
  private static func numeric(_ pointer: UnsafePointer<sockaddr>, length: socklen_t) -> String? {
    var name = [CChar](repeating: 0, count: Int(NI_MAXHOST))
    guard getnameinfo(pointer, length, &name, socklen_t(name.count), nil, 0, NI_NUMERICHOST) == 0 else { return nil }
    return String(cString: name).components(separatedBy: "%")[0].replacingOccurrences(of: "::ffff:", with: "")
  }
  static func isOwnAddress(_ peer: sockaddr_storage, length: socklen_t) -> Bool {
    var peer = peer
    guard let source = withUnsafePointer(to: &peer, { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { numeric($0, length: length) } }) else { return false }
    var list: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&list) == 0 else { return false }
    defer { freeifaddrs(list) }
    var current = list
    while let item = current {
      defer { current = item.pointee.ifa_next }
      guard let address = item.pointee.ifa_addr, [sa_family_t(AF_INET), sa_family_t(AF_INET6)].contains(address.pointee.sa_family) else { continue }
      if numeric(UnsafePointer(address), length: socklen_t(address.pointee.sa_len)) == source { return true }
    }
    return false
  }
}
