import Foundation

@main struct SharedLogInboxTests {
  static func main() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? fm.removeItem(at: root) }
    let inbox = root.appendingPathComponent("inbox")
    let batch = try SharedLogInbox.begin(at: inbox)
    let originals = root.appendingPathComponent("originals")
    try fm.createDirectory(at: originals, withIntermediateDirectories: true)
    for index in 0..<8 {
      let folder = originals.appendingPathComponent(String(index))
      try fm.createDirectory(at: folder, withIntermediateDirectories: true)
      let file = folder.appendingPathComponent("same-name.ips")
      try String(index).write(to: file, atomically: true, encoding: .utf8)
      try SharedLogInbox.copy(file, index: index, into: batch)
    }
    let partial = try SharedLogInbox.pendingFiles(at: inbox)
    assert(partial.isEmpty, "Partial batches must stay invisible")
    do {
      try SharedLogInbox.copy(
        originals.appendingPathComponent("missing.ips"), index: 8, into: batch)
      fatalError("Missing file must fail")
    } catch {}
    try SharedLogInbox.publish(batch)
    let files = try SharedLogInbox.pendingFiles(at: inbox)
    assert(files.count == 8, "Same filenames must not overwrite each other")
    let contents = try files.map { try String(contentsOf: $0, encoding: .utf8) }
    assert(Set(contents).count == 8)
    // Reading after a fresh scan models app restart before acknowledgment.
    let rescanned = try SharedLogInbox.pendingFiles(at: inbox)
    assert(rescanned.count == 8)
    for (index, file) in files.enumerated() {
      try SharedLogInbox.acknowledge(file, saved: index != 7, at: inbox)
    }
    let remaining = try SharedLogInbox.pendingFiles(at: inbox)
    assert(remaining.isEmpty)
    let reviewed = fm.enumerator(
      at: inbox.appendingPathComponent("Review"), includingPropertiesForKeys: nil)!
      .allObjects.compactMap { $0 as? URL }.filter { $0.pathExtension == "ips" }
    assert(
      reviewed.count == 1,
      "Unsuccessful file remains available for review, without auto-retrying forever")
    for index in 0..<8 {
      assert(
        fm.fileExists(
          atPath: originals.appendingPathComponent(String(index)).appendingPathComponent(
            "same-name.ips"
          ).path))
    }
    print(
      "PASS: eight files, filename collisions, atomic publication, restart recovery, failure retention, originals preserved"
    )
  }
}
