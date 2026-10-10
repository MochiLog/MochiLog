import Foundation

@main struct LocalCollectionProgressTests {
  static func main() throws {
    precondition(LocalCollectionProgress().fraction == nil)
    let file = LocalCollectionProgress(phase: .downloading, completed: 1, total: 4, bytes: 25, fileBytes: 100)
    precondition(file.fraction == 0.3125)
    precondition(LocalCollectionProgress(completed: 1, total: 4, bytes: 1000, fileBytes: 100).fraction == 0.5)
    precondition(LocalCollectionProgress(completed: 1, total: 4, bytes: 1000).fraction == 0.25)
    precondition(LocalCollectionProgress(phase: .finishing, completed: 4, total: 4).fraction == 1)
    let cancellation = LocalCollectionCancellation()
    try cancellation.check()
    DispatchQueue.concurrentPerform(iterations: 100) { _ in cancellation.cancel() }
    precondition(cancellation.isCancelled)
    do { try cancellation.check(); fatalError("Cancelled native work must stop") }
    catch is CancellationError { }
    print("PASS: unknown size, byte/file progress, bounded fraction and concurrent cancellation")
  }
}
