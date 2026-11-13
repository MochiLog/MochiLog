import Foundation

@main struct Tests {
  static func main() throws {
    let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let source = root.appendingPathComponent("snapshots", isDirectory: true)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    let files = ["pairing-v2.log", "pc-transfer-v2.log", "mochilog-support-manifest.json"].map {
      source.appendingPathComponent($0)
    }
    for file in files {
      try Data("日本語 diagnostic: \(file.lastPathComponent)\n".utf8).write(to: file)
    }
    try Data("DO_NOT_EXPORT_PARENT".utf8).write(
      to: source.appendingPathComponent("private-secret.txt"))
    let archive = try SupportArchive.create(files: files, directory: source)
    precondition(archive.pathExtension == "zip")
    let header = try Data(contentsOf: archive).prefix(2)
    precondition(header == Data([0x50, 0x4b]))
    precondition(
      !FileManager.default.fileExists(
        atPath: source.appendingPathComponent("MochiLog-Support").path))
    for file in files { precondition(FileManager.default.fileExists(atPath: file.path)) }
    let rejected = root.appendingPathComponent("rejected", isDirectory: true)
    try FileManager.default.createDirectory(at: rejected, withIntermediateDirectories: true)
    do {
      _ = try SupportArchive.create(files: files, directory: rejected, maximumBytes: 1)
      preconditionFailure("Oversized input was accepted")
    } catch {
      precondition(
        !FileManager.default.fileExists(
          atPath: rejected.appendingPathComponent("mochilog-support.zip").path))
    }
    let link = root.appendingPathComponent("link.log")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: files[0])
    do {
      _ = try SupportArchive.create(files: [link], directory: rejected)
      preconditionFailure("Symbolic file was accepted")
    } catch {}
    print("PASS: native ZIP, bounded snapshots, private flat inputs, cleanup and symlink rejection")
  }
}
