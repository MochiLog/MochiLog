import Foundation
import ZIPFoundation

/// Compress only bounded, already prepared snapshots. Never archive a live log
/// directory or invoke a shell/Python process to create an attachment.
enum SupportArchive {
  static func create(
    files: [URL], directory: URL, maximumBytes: Int = 16 * 1024 * 1024
  ) throws -> URL {
    guard !files.isEmpty, files.count <= 100 else { throw CocoaError(.fileReadTooLarge) }
    let output = directory.appendingPathComponent("mochilog-support.zip")
    guard !FileManager.default.fileExists(atPath: output.path) else {
      throw CocoaError(.fileWriteFileExists)
    }
    do {
      try write(files: files, to: output, maximumBytes: maximumBytes)
      let size = try output.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard size <= maximumBytes + 256 * 1024 else { throw CocoaError(.fileReadTooLarge) }
      return output
    } catch {
      try? FileManager.default.removeItem(at: output)
      throw error
    }
  }

  private static func write(files: [URL], to output: URL, maximumBytes: Int) throws {
    let zip = try Archive(url: output, accessMode: .create)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: output.path)
    var names = Set<String>()
    var total = 0
    for file in files {
      try Task.checkCancellation()
      let name = file.lastPathComponent
      guard !name.hasPrefix("."), name.count <= 180,
        name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "-._".contains($0)) }),
        names.insert(name.lowercased()).inserted
      else { throw CocoaError(.fileReadInvalidFileName) }
      let info = try file.resourceValues(forKeys: [
        .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
      ])
      guard info.isRegularFile == true, info.isSymbolicLink != true else {
        throw CocoaError(.fileReadNoPermission)
      }
      let size = info.fileSize ?? 0
      guard size <= maximumBytes - total else { throw CocoaError(.fileReadTooLarge) }
      total += size
      try zip.addEntry(
        with: name, fileURL: file, compressionMethod: .deflate, bufferSize: 64 * 1024)
    }
  }
}
