import Foundation

/// Read-only categorization of local and received archives. Never rewrites the
/// append-only exchange stream, and retains unsupported future formats as general.
enum DiagnosticLogViewer {
  static func days(in directory: URL) -> [String] {
    let files = (try? FileManager.default.contentsOfDirectory(at: directory,
      includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
    return files.filter { $0.pathExtension == "log" }.map { $0.deletingPathExtension().lastPathComponent }
      .filter { $0.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil }
      .sorted(by: >)
  }

  static func categories(in text: String) -> [String] {
    var result = Set<String>()
    visit(text) { category, _, _ in result.insert(category) }
    return DiagnosticLogArchive.categories.filter { result.contains($0) }
  }

  static func text(_ text: String, category: String?) -> String {
    guard let category, DiagnosticLogArchive.categories.contains(category) else { return text }
    var result: [String] = []
    var lastHeader: String?
    visit(text) { actual, header, line in
      guard actual == category else { return }
      if lastHeader != header { result.append(header); lastHeader = header }
      result.append(line)
    }
    return result.joined(separator: "\n")
  }

  /// Bound both the row count and text layout cost, including very long lines.
  /// Every character remains available across pages; the full copy/export stream
  /// is unchanged. This function is called only by the background loader.
  static func pages(_ text: String, maxLines: Int = 120, maxBytes: Int = 48 * 1024) -> [String] {
    precondition(maxLines > 0 && maxBytes >= 4)
    guard !text.isEmpty else { return [] }
    var result: [String] = []
    var current = ""
    var lines = 0
    var bytes = 0
    func flushPage() {
      if !current.isEmpty { result.append(current) }
      current = ""; lines = 0; bytes = 0
    }
    // Work on UTF-8 boundaries rather than constructing one String per scalar.
    // Newline bytes cannot occur inside a multibyte UTF-8 sequence.
    let utf8 = Array(text.utf8)
    var start = 0
    var end = 0
    while end < utf8.count {
      let byte = utf8[end]
      let width = byte < 0x80 ? 1 : byte < 0xE0 ? 2 : byte < 0xF0 ? 3 : 4
      if end - start + width > maxBytes {
        if end > start {
          if bytes + end - start > maxBytes || lines >= maxLines { flushPage() }
          let part = String(decoding: utf8[start..<end], as: UTF8.self)
          current += part; bytes += end - start
        }
        start = end
      }
      end += width
      if byte == 10 || end == utf8.count {
        let size = end - start
        if bytes + size > maxBytes || lines >= maxLines { flushPage() }
        current += String(decoding: utf8[start..<end], as: UTF8.self)
        bytes += size
        if byte == 10 { lines += 1 }
        start = end
      }
    }
    flushPage()
    return result
  }

  private static func visit(_ text: String, consume: (String, String, String) -> Void) {
    var header = "# {\"type\":\"mochilog-diagnostic-log\",\"formatVersion\":1,\"appVersion\":\"unknown\",\"build\":\"unknown\"}"
    var fixedCategory: String?
    var supported = true
    for line in text.components(separatedBy: .newlines) where !line.isEmpty {
      if line.hasPrefix("# "), let data = String(line.dropFirst(2)).data(using: .utf8),
        let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        metadata["type"] as? String == "mochilog-diagnostic-log",
        let version = metadata["formatVersion"] as? Int {
        header = line
        supported = version == 1 || version == 2
        let category = metadata["category"] as? String
        fixedCategory = category.flatMap { DiagnosticLogArchive.categories.contains($0) ? $0 : nil }
        continue
      }
      let category = supported ? (fixedCategory ?? DiagnosticLogArchive.category(for: line)) : "general"
      consume(category, header, line)
    }
  }
}
