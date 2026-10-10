import Foundation
@main struct Tests {
 static func main() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let version = "4.0.0", build = "1050", day = "2026-10-10"
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  let old = "2026-10-10T10:00:00+09:00 | old unversioned event\n"
  try Data(old.utf8).write(to: root.appendingPathComponent(day + ".log"))
  func append(_ message: String) { precondition(DiagnosticLogArchive.append("2026-10-10T11:00:00+09:00 | " + message, root: root, appVersion: version, build: build)) }
  append("Local scheduler: OS wake; wakeID=a")
  let snapshot = try Data(contentsOf: root.appendingPathComponent(day + ".log"))
  precondition(snapshot.starts(with: Data(old.utf8)))
  append("Local diagnostics: collection started")
  append("Connection: ready")
  append("Live battery: updated")
  let after = try Data(contentsOf: root.appendingPathComponent(day + ".log"))
  precondition(after.starts(with: snapshot)) // Old chunk offsets remain valid.
  let folder = root.appendingPathComponent(day)
  for category in ["background", "local-collection", "pc-transfer", "live-battery"] {
   let file = folder.appendingPathComponent(category + "-v2-4.0.0-1050.log")
   let text = try String(contentsOf: file, encoding: .utf8)
   let line = text.components(separatedBy: "\n")[0]
   let metadata = try JSONSerialization.jsonObject(with: Data(line.dropFirst(2).utf8)) as! [String:Any]
   precondition(metadata["formatVersion"] as? Int == 2 && metadata["category"] as? String == category)
   precondition(metadata["build"] as? String == build)
   precondition(text.components(separatedBy: "\n")[1].hasPrefix("2026-10-10T"))
  }
  precondition(String(data: after, encoding: .utf8)!.components(separatedBy: "# ").count == 2)
  precondition(!DiagnosticLogArchive.append("../attack", root: root, appVersion: version, build: build))
  precondition(DiagnosticLogArchive.append("2026-10-09T11:00:00+09:00 | old migrated", root: root, appVersion: version, build: build, legacy: true))
  precondition(FileManager.default.fileExists(atPath: root.appendingPathComponent("2026-10-09/general-v1-legacy.log").path))
  DiagnosticLogArchive.removeDay("../outside", root: root)
  precondition(FileManager.default.fileExists(atPath: folder.path))
  DiagnosticLogArchive.removeDay(day, root: root)
  precondition(!FileManager.default.fileExists(atPath: folder.path) && !FileManager.default.fileExists(atPath: root.appendingPathComponent(day + ".log").path))
  print("PASS: versioned per-feature files, single headers, untouched legacy prefix, stable chunk offsets, safe pruning")
 }
}
