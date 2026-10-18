import Foundation

@main struct LocalLogCheckpointTests {
  static func main() throws {
    let sandbox = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: sandbox) }
    let documents = sandbox.appendingPathComponent("Documents", isDirectory: true)
    let root = documents.appendingPathComponent(
      "MacTransferInbox/LocalDevice/fixture", isDirectory: true)
    let directory = root.appendingPathComponent("Host", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let name = "Analytics-2026-10-11-090002.000.ips.ca.synced"
    let file = directory.appendingPathComponent(name)
    try Data("checkpoint".utf8).write(to: file)
    let alias = sandbox.appendingPathComponent("DocumentsAlias", isDirectory: true)
    try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: documents)
    let aliasRoot = alias.appendingPathComponent(
      "MacTransferInbox/LocalDevice/fixture", isDirectory: true)
    precondition(LocalLogCheckpoint.base(for: file, root: aliasRoot) == "Host::" + name)
    precondition(
      LocalLogCheckpoint.base(for: aliasRoot.appendingPathComponent("Host/" + name), root: root)
        == "Host::" + name)
    precondition(LocalLogCheckpoint.base(for: file, root: root) == "Host::" + name)
    precondition(
      LocalLogCheckpoint.base(for: file, root: root.appendingPathComponent("other")) == nil)
    precondition(LocalLogCheckpoint.base(for: file, root: sandbox) == nil)
    let sibling = URL(fileURLWithPath: root.path + "-other/Host/" + name)
    precondition(LocalLogCheckpoint.base(for: sibling, root: root) == nil)
    let watch = root.appendingPathComponent("Watch/ProxiedDevice-abcdef/" + name)
    precondition(
      LocalLogCheckpoint.base(for: watch, root: aliasRoot) == "Watch::ProxiedDevice-abcdef::" + name
    )
    precondition(
      LocalLogCheckpoint.base(
        for: root.appendingPathComponent("Host/Analytics-2026-10-11-090002.session.ips.ca.synced"),
        root: root) == nil)
    print(
      "PASS: checkpoint URL aliases, correct receipt tokens, Watch separation and root containment")
  }
}
