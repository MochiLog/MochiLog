import Foundation

/// Transport framing only. A complete frame still requires the existing AES-GCM
/// authentication before it can affect receipts, records or pairing state.
nonisolated enum PCTransferRecoveryPolicy {
  static let maximumFrameBytes = 64 * 1024 * 1024 + 1_024
  static let discoveryTimeout: TimeInterval = 8
  static let maximumRoutes = 16

  enum FrameFailure: Error { case invalidLength, oversized, trailingBytes }

  static func frameIsComplete(_ bytes: Data) throws -> Bool {
    guard bytes.count <= maximumFrameBytes else { throw FrameFailure.oversized }
    guard bytes.count >= 4 else { return false }
    let bodyLength = bytes.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    guard bodyLength > 0 else { throw FrameFailure.invalidLength }
    guard bodyLength <= maximumFrameBytes - 4 else { throw FrameFailure.oversized }
    let total = Int(bodyLength) + 4
    guard bytes.count <= total else { throw FrameFailure.trailingBytes }
    return bytes.count == total
  }

  /// Bonjour interface/order changes must not restart the current connection
  /// or change the index of routes already attempted. New routes remain usable.
  static func routes<Route: Equatable>(
    current: [Route], discovered: [Route], attemptActive: Bool
  ) -> [Route] {
    var result: [Route] = []
    for route in (attemptActive ? current + discovered : discovered) {
      if !result.contains(route) { result.append(route) }
      if result.count == maximumRoutes { break }
    }
    return result
  }
}
