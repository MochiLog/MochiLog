import Foundation

@main struct Tests {
  static func main() {
    let queue = DispatchQueue(label: "deadline-test")
    let fired = DispatchSemaphore(value: 0)
    let deadline = ProgressDeadline(interval: 0.25, queue: queue) { fired.signal() }
    // Total duration exceeds the idle limit, while chunks keep arriving.
    for _ in 0..<8 {
      Thread.sleep(forTimeInterval: 0.05)
      deadline.progress()
    }
    precondition(fired.wait(timeout: .now()) == .timedOut, "Slow progressing transfer timed out")
    precondition(fired.wait(timeout: .now() + 2) == .success, "Silent transfer never timed out")
    precondition(fired.wait(timeout: .now() + 0.3) == .timedOut, "Deadline fired repeatedly")
    let cancelled = DispatchSemaphore(value: 0)
    let other = ProgressDeadline(interval: 0.05, queue: queue) { cancelled.signal() }
    other.cancel()
    precondition(cancelled.wait(timeout: .now() + 0.15) == .timedOut, "Cancelled deadline fired")
    print("PASS: idle deadline permits slow progress, detects a stall once and cancels cleanly")
  }
}
