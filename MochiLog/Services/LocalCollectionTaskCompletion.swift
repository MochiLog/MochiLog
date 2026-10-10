import Foundation

/// Expiration and asynchronous native completion can race. Only one may finish the OS task.
final class LocalCollectionTaskCompletion: @unchecked Sendable {
  private let lock = NSLock()
  private var completed = false
  func claim() -> Bool {
    lock.lock(); defer { lock.unlock() }
    guard !completed else { return false }
    completed = true; return true
  }
}
