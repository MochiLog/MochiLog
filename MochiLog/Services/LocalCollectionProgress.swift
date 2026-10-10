import Foundation

nonisolated struct LocalCollectionProgress: Sendable {
  enum Phase: String, Sendable { case connecting, listing, downloading, finishing }
  var phase: Phase = .connecting
  var file = ""
  var completed = 0
  var total = 0
  var bytes: Int64 = 0
  var fileBytes: Int64?
  var fraction: Double? {
    guard total > 0 else { return nil }
    let current = fileBytes.flatMap { $0 > 0 ? min(1, Double(bytes) / Double($0)) : nil } ?? 0
    return min(1, (Double(completed) + current) / Double(total))
  }
}

/// Cancellation is checked between bounded native reads. Never free an FFI
/// client from another thread while the maintained library is using it.
nonisolated final class LocalCollectionCancellation: @unchecked Sendable {
  private let lock = NSLock()
  private var stopped = false
  func cancel() { lock.lock(); stopped = true; lock.unlock() }
  var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
  func check() throws { if isCancelled { throw CancellationError() } }
}
