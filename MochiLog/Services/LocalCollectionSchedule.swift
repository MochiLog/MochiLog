import Foundation

/// Pure scheduling policy. The dates are earliest permitted times, never a timer guarantee.
struct LocalCollectionSchedule: Sendable {
  enum Reason: String, Sendable { case retry, beforeDailyGeneration, dailyComplete }
  let earliest: Date
  let reason: Reason
  var shouldCollect: Bool { reason == .retry }

  static func decide(now: Date, received: Set<String>, expectedWatches: Int?) -> Self {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    let day = calendar.startOfDay(for: now)
    let generation = calendar.date(byAdding: .hour, value: 9, to: day)!
    if now < generation { return Self(earliest: generation, reason: .beforeDailyGeneration) }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone; formatter.dateFormat = "yyyy-MM-dd"
    let suffix = "Analytics-" + formatter.string(from: now) + "-"
    let host = received.contains { $0.hasPrefix("Host::" + suffix) }
    let watches = Set(received.filter { $0.hasPrefix("Watch::") && $0.contains("::" + suffix) }
      .compactMap { $0.components(separatedBy: "::").dropFirst().first })
    if host, let expectedWatches, watches.count >= expectedWatches {
      return Self(earliest: calendar.date(byAdding: .day, value: 1, to: generation)!, reason: .dailyComplete)
    }
    return Self(earliest: now.addingTimeInterval(15 * 60), reason: .retry)
  }
}

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
