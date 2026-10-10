import Foundation

@main struct LocalCollectionScheduleTests {
  static func main() {
    let formatter = ISO8601DateFormatter()
    func date(_ value: String) -> Date { formatter.date(from: value)! }
    let morning = date("2026-10-10T08:59:59+09:00")
    let start = date("2026-10-10T09:00:00+09:00")
    let tomorrow = date("2026-10-11T09:00:00+09:00")
    let host = "Host::Analytics-2026-10-10-090000.ips.ca.synced"
    let watch = "Watch::watch-1::Analytics-2026-10-10-090000.ips.ca.synced"
    let before = LocalCollectionSchedule.decide(now: morning, received: [], expectedWatches: 0)
    precondition(!before.shouldCollect && before.earliest == start)
    let empty = LocalCollectionSchedule.decide(now: start, received: [], expectedWatches: 0)
    precondition(empty.shouldCollect && empty.earliest == start.addingTimeInterval(300))
    let ipad = LocalCollectionSchedule.decide(now: start, received: [host], expectedWatches: 0)
    precondition(!ipad.shouldCollect && ipad.reason == .dailyComplete && ipad.earliest == tomorrow)
    precondition(LocalCollectionSchedule.decide(now: start, received: [host], expectedWatches: 1).shouldCollect)
    precondition(LocalCollectionSchedule.decide(now: start, received: [host, watch], expectedWatches: 2).shouldCollect)
    // Two files from one Watch do not stand in for two different physical watches.
    precondition(LocalCollectionSchedule.decide(now: start, received: [host, watch,
      "Watch::watch-1::Analytics-2026-10-10-100000.ips.ca.synced"], expectedWatches: 2).shouldCollect)
    precondition(!LocalCollectionSchedule.decide(now: start, received: [host, watch,
      "Watch::watch-2::Analytics-2026-10-10-090000.ips.ca.synced"], expectedWatches: 2).shouldCollect)
    precondition(LocalCollectionSchedule.decide(now: start, received: [host, watch], expectedWatches: nil).shouldCollect)
    precondition(LocalCollectionSchedule.decide(now: tomorrow, received: [host, watch], expectedWatches: 1).shouldCollect)
    precondition(LocalCollectionSchedule.decide(now: start, received: [watch], expectedWatches: 1).shouldCollect)
    precondition(LocalCollectionSchedule.decide(now: date("2026-10-10T00:00:00Z"), received: [host], expectedWatches: 0).reason == .dailyComplete)
    let lease = LocalCollectionTaskCompletion()
    let lock = NSLock(); var completions = 0
    DispatchQueue.concurrentPerform(iterations: 100) { _ in
      if lease.claim() { lock.lock(); completions += 1; lock.unlock() }
    }
    precondition(completions == 1 && !lease.claim())
    print("PASS: JST generation boundary, daily restart, no Watch / multiple Watch / unknown Watch, missing host, concurrent expiration/completion")
  }
}
