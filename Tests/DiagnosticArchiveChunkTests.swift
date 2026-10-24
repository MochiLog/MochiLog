import Foundation

@main struct DiagnosticArchiveChunkTests {
  static func main() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("day.log")
    func check(_ condition: Bool) { precondition(condition) }
    func append(_ value: String, _ offset: Int) throws -> DiagnosticArchiveChunk.Result {
      try DiagnosticArchiveChunk.append(Data(value.utf8), offset: offset, to: file)
    }
    check(try append("abc", 2) == .rejected)
    check(!FileManager.default.fileExists(atPath: file.path))
    check(try append("abcdef", 0) == .appended(6))
    check(try append("abcdef", 0) == .duplicate)
    check(try append("cdefgh", 2) == .appended(2))
    check(try append("cd", 2) == .duplicate)
    check(try append("xxxx", 4) == .rejected)
    check(try append("j", 9) == .rejected)
    check(try append("x", -1) == .rejected)
    check(try append("xx", 63_999_999) == .rejected)
    check(
      try DiagnosticArchiveChunk.append(Data(repeating: 1, count: 8193), offset: 8, to: file)
        == .rejected)
    check(try String(contentsOf: file, encoding: .utf8) == "abcdefgh")
    print(
      "PASS: diagnostic retries are idempotent, matching overlap resumes, conflicts/gaps/oversized chunks preserve saved data"
    )
  }
}
