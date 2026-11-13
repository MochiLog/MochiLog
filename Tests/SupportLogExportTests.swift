import Foundation

@main struct Tests {
  static func main() throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: base) }
    let source = base.appendingPathComponent("source")
    let day = "2026-11-13"
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    precondition(
      DiagnosticLogArchive.append(
        day + "T16:00:00+09:00 | PC pairing: test failed",
        root: source, appVersion: "4.1.0", build: "1068"))
    precondition(
      DiagnosticLogArchive.append(
        day + "T16:00:01+09:00 | Local scheduler: test",
        root: source, appVersion: "4.1.0", build: "1068"))
    let external = base.appendingPathComponent("private-key")
    try Data("DO_NOT_EXPORT".utf8).write(to: external)
    let link = source.appendingPathComponent(day + "/pairing-v2-link.log")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: external)
    let sources = [
      SupportLogExport.Source(name: "phone", directory: source),
      .init(name: "computer", directory: base.appendingPathComponent("absent")),
    ]
    let output = base.appendingPathComponent("export")
    let files = try SupportLogExport.prepare(
      sources: sources, days: [day, "2026-11-12", "../bad"],
      diagnostics: [.init(name: "diagnostic.json", data: Data("{}".utf8))],
      unavailable: ["computer: app pairing not completed"], directory: output)
    precondition(files.contains { $0.lastPathComponent.contains("pairing-v2-4.1.0-1068") })
    precondition(files.contains { $0.lastPathComponent.contains("background-v2-4.1.0-1068") })
    let manifest = try String(
      contentsOf: output.appendingPathComponent("mochilog-support-manifest.json"), encoding: .utf8)
    precondition(manifest.contains("computer: app pairing not completed"))
    precondition(manifest.contains("missing") && manifest.contains("not-a-regular-file"))
    for file in files {
      let text = try String(contentsOf: file, encoding: .utf8)
      precondition(!text.contains("DO_NOT_EXPORT"))
    }
    let bounded = base.appendingPathComponent("bounded")
    _ = try SupportLogExport.prepare(
      sources: sources, days: [day], diagnostics: [], directory: bounded, maximumBytes: 1)
    let limited = try String(
      contentsOf: bounded.appendingPathComponent("mochilog-support-manifest.json"), encoding: .utf8)
    precondition(limited.contains("omitted-export-limit"))
    print(
      "PASS: feature and compatibility logs, missing-day/computer manifest, symlink rejection and export budget"
    )
  }
}
