import Darwin
import Foundation

@main struct LocalPairingAddressTests {
  static func accepted(_ ip: String, family: Int32) -> Bool {
    var storage = sockaddr_storage()
    let length: socklen_t
    if family == AF_INET {
      var address = sockaddr_in()
      address.sin_family = sa_family_t(AF_INET); address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
      precondition(ip.withCString { inet_pton(AF_INET, $0, &address.sin_addr) } == 1)
      withUnsafeBytes(of: address) { source in withUnsafeMutableBytes(of: &storage) { $0.copyBytes(from: source) } }
      length = socklen_t(MemoryLayout<sockaddr_in>.size)
    } else {
      var address = sockaddr_in6()
      address.sin6_family = sa_family_t(AF_INET6); address.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
      precondition(ip.withCString { inet_pton(AF_INET6, $0, &address.sin6_addr) } == 1)
      withUnsafeBytes(of: address) { source in withUnsafeMutableBytes(of: &storage) { $0.copyBytes(from: source) } }
      length = socklen_t(MemoryLayout<sockaddr_in6>.size)
    }
    return LocalPairingAddressPolicy.isOwnAddress(storage, length: length)
  }
  static func main() {
    precondition(accepted("127.0.0.1", family: AF_INET))
    precondition(accepted("::1", family: AF_INET6))
    precondition(accepted("::ffff:127.0.0.1", family: AF_INET6))
    precondition(!accepted("203.0.113.9", family: AF_INET))
    precondition(!accepted("::ffff:203.0.113.9", family: AF_INET6))
    precondition(!accepted("2001:db8::9", family: AF_INET6))
    print("PASS: own-device pairing accepts local and mapped peers; rejects foreign IPv4/IPv6")
  }
}
