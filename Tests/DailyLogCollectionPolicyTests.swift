import Foundation

@main struct DailyLogCollectionPolicyTests {
  static func main() {
    let formatter = ISO8601DateFormatter()
    func date(_ value: String) -> Date { formatter.date(from: value)! }
    let morning = date("2026-10-10T08:59:59+09:00")
    let start = date("2026-10-10T09:00:00+09:00")
    precondition(formatter.date(from: DailyLogCollectionPolicy.timestamp(start)) == start)
    let tomorrow = date("2026-10-11T09:00:00+09:00")
    let host = "Host::Analytics-2026-10-10-090000.ips.ca.synced"
    let watch = "Watch::watch-1::Analytics-2026-10-10-090000.ips.ca.synced"
    let before = DailyLogCollectionPolicy.decide(now: morning, received: [], expectedWatches: 0)
    precondition(!before.shouldCollect && before.earliest == start)
    let empty = DailyLogCollectionPolicy.decide(now: start, received: [], expectedWatches: 0)
    precondition(empty.shouldCollect && empty.earliest == start.addingTimeInterval(300))
    let ipad = DailyLogCollectionPolicy.decide(now: start, received: [host], expectedWatches: 0)
    precondition(!ipad.shouldCollect && ipad.reason == .dailyComplete && ipad.earliest == tomorrow)
    precondition(DailyLogCollectionPolicy.decide(now: start, received: [host], expectedWatches: 1).shouldCollect)
    precondition(DailyLogCollectionPolicy.decide(now: start, received: [host, watch], expectedWatches: 2).shouldCollect)
    // Two files from one Watch do not stand in for two different physical watches.
    precondition(DailyLogCollectionPolicy.decide(now: start, received: [host, watch,
      "Watch::watch-1::Analytics-2026-10-10-100000.ips.ca.synced"], expectedWatches: 2).shouldCollect)
    precondition(!DailyLogCollectionPolicy.decide(now: start, received: [host, watch,
      "Watch::watch-2::Analytics-2026-10-10-090000.ips.ca.synced"], expectedWatches: 2).shouldCollect)
    precondition(DailyLogCollectionPolicy.decide(now: start, received: [host, watch], expectedWatches: nil).shouldCollect)
    precondition(DailyLogCollectionPolicy.decide(now: tomorrow, received: [host, watch], expectedWatches: 1).shouldCollect)
    precondition(DailyLogCollectionPolicy.decide(now: start, received: [watch], expectedWatches: 1).shouldCollect)
    precondition(DailyLogCollectionPolicy.decide(now: date("2026-10-10T00:00:00Z"), received: [host], expectedWatches: 0).reason == .dailyComplete)
    // Both acquisition routes consume the same completion and pause decision.
    let sources: Set<String> = ["watch-1", "watch-2"]
    precondition(DailyLogCollectionPolicy.isComplete(hostReceived: true,
      watchSources: sources, expectedWatches: 2))
    precondition(!DailyLogCollectionPolicy.isComplete(hostReceived: false,
      watchSources: sources, expectedWatches: 2))
    precondition(!DailyLogCollectionPolicy.isComplete(hostReceived: true,
      watchSources: sources.subtracting(["watch-2"]), expectedWatches: 2))
    precondition(DailyLogCollectionPolicy.decide(now: start, complete: true,
      pauseAcknowledged: false).shouldCollect)
    precondition(!DailyLogCollectionPolicy.decide(now: start, complete: true,
      pauseAcknowledged: true).shouldCollect)
    precondition(DailyLogCollectionPolicy.expectedWatchCount(isPad: true,
      isWatchPaired: nil, registeredCount: 2) == 0)
    precondition(DailyLogCollectionPolicy.expectedWatchCount(isPad: false,
      isWatchPaired: nil, registeredCount: 0) == nil)
    precondition(DailyLogCollectionPolicy.expectedWatchCount(isPad: false,
      isWatchPaired: true, registeredCount: 0) == 1)
    precondition(DailyLogCollectionPolicy.expectedWatchCount(isPad: false,
      isWatchPaired: true, registeredCount: 2) == 2)
    precondition(DailyLogCollectionPolicy.expectedWatchCount(isPad: false,
      isWatchPaired: false, registeredCount: 2) == 0)
    precondition(DailyLogCollectionPolicy.nextCollectionWindow(morning) == start)
    precondition(DailyLogCollectionPolicy.nextCollectionWindow(start) == tomorrow)
    precondition(DailyLogCollectionPolicy.dayKey(date("2026-10-09T15:00:00Z")) == "2026-10-10")
    // Malformed source tokens cannot falsely satisfy another Watch or another day.
    precondition(DailyLogCollectionPolicy.decide(now: start, received: [host,
      "Watch::::Analytics-2026-10-10-090000.ips.ca.synced",
      "Watch::watch-1::Other::Analytics-2026-10-10-090000.ips.ca.synced"],
      expectedWatches: 1).shouldCollect)
    let lease = LocalCollectionTaskCompletion()
    let lock = NSLock(); var completions = 0
    DispatchQueue.concurrentPerform(iterations: 100) { _ in
      if lease.claim() { lock.lock(); completions += 1; lock.unlock() }
    }
    precondition(completions == 1 && !lease.claim())
    print("PASS: JST generation boundary, daily restart, no Watch / multiple Watch / unknown Watch, missing host, concurrent expiration/completion")
  }
}
