import Foundation

/// A monotonic idle deadline, separate from total transfer duration. All state
/// belongs to queue, and a stopped deadline cannot fire again.
final class ProgressDeadline: @unchecked Sendable {
  private let queue: DispatchQueue
  private let interval: TimeInterval
  private let expired: @Sendable () -> Void
  private var lastProgress = ProcessInfo.processInfo.systemUptime
  private var timer: DispatchSourceTimer?
  private var stopped = false

  init(interval: TimeInterval, queue: DispatchQueue, expired: @escaping @Sendable () -> Void) {
    self.interval = interval
    self.queue = queue
    self.expired = expired
    queue.async { [self] in
      let timer = DispatchSource.makeTimerSource(queue: queue)
      self.timer = timer
      timer.setEventHandler { [weak self] in self?.check() }
      timer.schedule(deadline: .now() + interval)
      timer.resume()
    }
  }

  func progress() {
    let now = ProcessInfo.processInfo.systemUptime
    queue.async { [self] in if !stopped { lastProgress = max(lastProgress, now) } }
  }

  func cancel() {
    queue.async { [self] in stop() }
  }

  private func stop() {
    stopped = true
    timer?.cancel()
    timer = nil
  }

  private func check() {
    guard !stopped else { return }
    let remaining = interval - (ProcessInfo.processInfo.systemUptime - lastProgress)
    if remaining > 0 {
      timer?.schedule(deadline: .now() + remaining)
    } else {
      stop()
      expired()
    }
  }

  deinit { timer?.cancel() }
}
