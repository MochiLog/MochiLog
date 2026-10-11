import Foundation
@main struct ViewerTests {
  static func main() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    for name in ["2026-10-11.log", "2026-10-09.log", "2026-10-12.json", "unrelated.log"] {
      try Data().write(to: root.appendingPathComponent(name))
    }
    precondition(DiagnosticLogViewer.days(in: root) == ["2026-10-11", "2026-10-09"])
    let unicode = String(repeating: "2026-10-11T09:00:00+09:00 | Connection: ready 日本語🧪\n", count: 108_672)
    for text in [unicode, String(repeating: "a\u{301}", count: 100_000), "\n\n", "", "without final newline"] {
      let pages = DiagnosticLogViewer.pages(text)
      precondition(pages.joined() == text)
      precondition(pages.allSatisfy { $0.utf8.count <= 48 * 1024 && $0.filter { $0 == "\n" }.count <= 120 })
    }
    let archive = "# {\"type\":\"mochilog-diagnostic-log\",\"formatVersion\":2,\"category\":\"combined\"}\nConnection: ready\nLive battery: updated\n"
    precondition(Set(DiagnosticLogViewer.categories(in: archive)) == ["pc-transfer", "live-battery"])
    let filtered = DiagnosticLogViewer.text(archive, category: "pc-transfer")
    precondition(filtered.contains("Connection: ready") && !filtered.contains("Live battery:"))
    let future = archive.replacingOccurrences(of: "\"formatVersion\":2", with: "\"formatVersion\":99")
    precondition(DiagnosticLogViewer.categories(in: future) == ["general"])
    let formatter = ISO8601DateFormatter()
    let entries = [
      ErrorLogEntry(id: "a", timestamp: formatter.date(from: "2026-10-10T23:30:00Z")!, message: "Bad import", rawTextPreview: nil),
      ErrorLogEntry(id: "b", timestamp: formatter.date(from: "2026-10-11T00:30:00Z")!, message: "Missing file", rawTextPreview: nil)
    ]
    var japan = Calendar(identifier: .gregorian); japan.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    var utc = japan; utc.timeZone = TimeZone(secondsFromGMT: 0)!
    precondition(ErrorLogPresentation.days(entries, calendar: japan).count == 1)
    precondition(ErrorLogPresentation.days(entries, calendar: utc).count == 2)
    precondition(ErrorLogPresentation.days(entries, query: "IMPORT", calendar: japan).first?.entries.map(\.id) == ["a"])
    precondition(ErrorLogPresentation.days(entries, query: "unmatched").isEmpty)
    precondition(ErrorLogPresentation.days(entries, calendar: japan).first?.entries.map(\.id) == ["b", "a"])
    print("PASS: 108,672-line Unicode logs, lossless bounded pages, category/version compatibility, safe archive listing, timezone grouping and message search")
  }
}
