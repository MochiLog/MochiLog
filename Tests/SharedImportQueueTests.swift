// Run with scripts/test-shared-import.sh. Uses the production queue and text reader.
import Foundation

struct FileImportResult {}

@MainActor
final class AppSettings {
  static let shared = AppSettings()
  var selectedTabIndex = 2
}

@main
struct SharedImportQueueTests {
  @MainActor
  static func main() throws {
    var now = Date(timeIntervalSince1970: 1_000)
    let queue = SharedImportQueue(now: { now })
    let first = URL(fileURLWithPath: "/tmp/first.ips")
    let second = URL(fileURLWithPath: "/tmp/second.ips")
    let third = URL(fileURLWithPath: "/tmp/third.ips")
    assert(!queue.begin())
    queue.enqueue(URL(string: "https://example.com/log.ips")!)
    assert(!queue.begin(), "Non-file URLs must be ignored")
    queue.enqueue(first)
    queue.enqueue(second)
    queue.enqueue(first)
    assert(AppSettings.shared.selectedTabIndex == 0)
    assert(queue.begin(), "Cold-launch URLs must survive until a consumer mounts")
    assert(!queue.begin(), "Two HomeViews must not consume the same batch")
    assert(queue.takeNext() == [first, second], "Deduplication must preserve order")
    queue.enqueue(third)
    assert(queue.takeNext() == [third], "Late arrivals must not replace active results")
    queue.acknowledge(first)
    queue.enqueue(first)
    assert(queue.takeNext().isEmpty, "Immediate duplicate scene delivery must be suppressed")
    now = now.addingTimeInterval(3)
    queue.enqueue(first)
    assert(queue.takeNext() == [first], "Explicit retry must be possible after completion")
    queue.acknowledge(first)
    queue.acknowledge(second)
    queue.acknowledge(third)
    queue.finish()
    assert(!queue.begin())
    assert(!queue.shouldPresentResults)
    now = now.addingTimeInterval(3)
    queue.enqueue(second, presentsResults: false)
    assert(!queue.shouldPresentResults, "Silent share preference must be retained")
    queue.enqueue(third)
    assert(queue.shouldPresentResults, "Picker input must make a mixed batch visible")
    assert(queue.begin())
    assert(queue.takeNext() == [second, third])
    queue.acknowledge(second)
    queue.acknowledge(third)
    queue.finish()

    now = now.addingTimeInterval(3)
    queue.enqueue(first, presentsResults: false, opensDetail: true)
    assert(
      queue.shouldOpenDetail && !queue.shouldPresentResults,
      "Direct single-file import must request detail without the batch sheet")
    assert(queue.begin())
    assert(queue.takeNext() == [first])
    queue.enqueue(second, presentsResults: true)
    assert(
      queue.shouldPresentResults,
      "Extension input must retain the batch sheet even during a direct import")
    assert(queue.takeNext() == [second])
    queue.acknowledge(first)
    queue.acknowledge(second)
    queue.finish()
    assert(
      !queue.shouldOpenDetail && !queue.shouldPresentResults,
      "Presentation preferences must not leak into the next import")

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let text = "バッテリーのログ\n{\"cycleCount\":42}"
    for (index, encoding) in [String.Encoding.utf8, .utf16, .shiftJIS].enumerated() {
      let url = directory.appendingPathComponent("\(index).ips")
      try text.data(using: encoding)!.write(to: url)
      let actual = try LogTextReader.read(url)
      assert(actual == text, "Encoding \(encoding) must round-trip")
      assert(FileManager.default.fileExists(atPath: url.path), "Reading must not delete input")
    }
    let empty = directory.appendingPathComponent("empty.ips")
    try Data().write(to: empty)
    let emptyText = try LogTextReader.read(empty)
    assert(emptyText.isEmpty)
    do {
      _ = try LogTextReader.read(directory.appendingPathComponent("missing.ips"))
      fatalError("Missing input must throw")
    } catch {}
    let dateStrings = [
      "2026-09-01T12:00:00+0900", "2026-09-01T12:00:00+09:00",
      "2026-09-01T03:00:00Z", "2026-09-01T03:00:00.000Z",
      "2026-09-01 12:00:00.00 +0900", "2026-09-01 12:00:00 +0900",
    ]
    let expected = LogDateParser.parse(dateStrings[0])!
    for value in dateStrings {
      assert(LogDateParser.parse(value) == expected, "Timestamp must parse: \(value)")
    }
    assert(LogDateParser.parse("not a date") == nil)
    print(
      "PASS: queue delivery, exclusive consumer, late arrivals, retries, encodings, missing/empty files"
    )
  }
}
