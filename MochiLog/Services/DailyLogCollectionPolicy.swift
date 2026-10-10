import Foundation

/// Shared daily-log stopping and resuming policy for PC reception and on-device collection.
/// Dates are earliest permitted times, never a timer guarantee.
struct DailyLogCollectionPolicy: Sendable {
  enum Reason: String, Sendable { case retry, beforeDailyGeneration, dailyComplete }
  let earliest: Date
  let reason: Reason
  var shouldCollect: Bool { reason == .retry }

  static func timestamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = .current
    return formatter.string(from: date)
  }

  static var japanCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return calendar
  }

  static func dayKey(_ date: Date = Date()) -> String {
    let parts = japanCalendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
  }

  static func generationTime(on date: Date) -> Date {
    japanCalendar.date(byAdding: .hour, value: 9,
      to: japanCalendar.startOfDay(for: date))!
  }

  static func nextCollectionWindow(_ now: Date = Date()) -> Date {
    let generation = generationTime(on: now)
    return now < generation ? generation : japanCalendar.date(byAdding: .day, value: 1, to: generation)!
  }

  static func expectedWatchCount(isPad: Bool, isWatchPaired: Bool?, registeredCount: Int) -> Int? {
    if isPad { return 0 }
    guard let isWatchPaired else { return nil }
    return isWatchPaired ? max(1, registeredCount) : 0
  }

  /// Callers supply eligible sources, excluding failed imports. Unknown Watch pairing
  /// must never be treated as zero. Multiple files from one Watch count only once.
  static func isComplete(hostReceived: Bool, watchSources: Set<String>, expectedWatches: Int?) -> Bool {
    guard let expectedWatches, expectedWatches >= 0 else { return false }
    return hostReceived && watchSources.count >= expectedWatches
  }

  /// Used by both PC reception and on-device collection. PC reception can additionally
  /// require every paired computer to acknowledge the pause before stopping discovery.
  static func decide(now: Date, complete: Bool, pauseAcknowledged: Bool = true) -> Self {
    let generation = generationTime(on: now)
    if now < generation { return Self(earliest: generation, reason: .beforeDailyGeneration) }
    if complete && pauseAcknowledged {
      return Self(earliest: nextCollectionWindow(now), reason: .dailyComplete)
    }
    return Self(earliest: now.addingTimeInterval(5 * 60), reason: .retry)
  }

  static func decide(now: Date, received: Set<String>, expectedWatches: Int?) -> Self {
    let prefix = "Analytics-" + dayKey(now) + "-"
    var host = false
    var watches = Set<String>()
    for token in received {
      let parts = token.components(separatedBy: "::")
      if parts.count == 2, parts[0] == "Host", parts[1].hasPrefix(prefix) { host = true }
      if parts.count == 3, parts[0] == "Watch", !parts[1].isEmpty,
        parts[2].hasPrefix(prefix) { watches.insert(parts[1]) }
    }
    return decide(now: now, complete: isComplete(hostReceived: host,
      watchSources: watches, expectedWatches: expectedWatches))
  }
}
