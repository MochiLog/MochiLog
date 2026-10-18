import Foundation

/// Copies belong to the app group, never to the source provider. A batch only
/// becomes visible to the app after every attachment has finished loading.
enum SharedLogInbox {
  static let groupIdentifier = "group.net.ryuya-dev.MochiLog"
  static var root: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)?
      .appendingPathComponent("SharedLogInbox", isDirectory: true)
  }

  static func begin(at root: URL) throws -> URL {
    let batch = root.appendingPathComponent("." + UUID().uuidString + ".pending", isDirectory: true)
    try FileManager.default.createDirectory(at: batch, withIntermediateDirectories: true)
    return batch
  }

  static func copy(_ source: URL, index: Int, into batch: URL) throws {
    let folder = batch.appendingPathComponent(String(index), isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    do {
      var coordinationError: NSError?
      var copyResult: Result<Void, Error> = .failure(CocoaError(.fileReadUnknown))
      NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError)
      { readable in
        copyResult = Result {
          let values = try readable.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
          guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw CocoaError(.fileReadUnsupportedScheme)
          }
          try FileManager.default.copyItem(
            at: readable, to: folder.appendingPathComponent(source.lastPathComponent))
        }
      }
      if let coordinationError { throw coordinationError }
      try copyResult.get()
    } catch {
      try? FileManager.default.removeItem(at: folder)
      throw error
    }
  }

  static func publish(_ batch: URL) throws {
    let name = String(batch.lastPathComponent.dropFirst()).replacingOccurrences(
      of: ".pending", with: ".ready")
    try FileManager.default.moveItem(
      at: batch, to: batch.deletingLastPathComponent().appendingPathComponent(name))
  }

  static func pendingFiles(at root: URL) throws -> [URL] {
    guard FileManager.default.fileExists(atPath: root.path) else { return [] }
    let batches = try FileManager.default.contentsOfDirectory(
      at: root, includingPropertiesForKeys: nil
    )
    .filter { $0.pathExtension == "ready" }.sorted { $0.path < $1.path }
    var files: [URL] = []
    for batch in batches {
      guard
        let enumerator = FileManager.default.enumerator(
          at: batch,
          includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
          options: [.skipsHiddenFiles])
      else { continue }
      for case let file as URL in enumerator {
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        if values.isRegularFile == true && values.isSymbolicLink != true { files.append(file) }
      }
    }
    return files.sorted { $0.path < $1.path }
  }

  static func acknowledge(_ file: URL, saved: Bool, at root: URL) throws {
    let itemFolder = file.deletingLastPathComponent()
    let batch = itemFolder.deletingLastPathComponent()
    guard
      batch.deletingLastPathComponent().standardizedFileURL.path == root.standardizedFileURL.path,
      batch.pathExtension == "ready"
    else { return }
    if saved {
      try FileManager.default.removeItem(at: file)
    } else {
      let review = root.appendingPathComponent("Review").appendingPathComponent(
        batch.lastPathComponent
      )
      .appendingPathComponent(itemFolder.lastPathComponent)
      try FileManager.default.createDirectory(at: review, withIntermediateDirectories: true)
      try FileManager.default.moveItem(
        at: file, to: review.appendingPathComponent(file.lastPathComponent))
    }
    if (try FileManager.default.contentsOfDirectory(atPath: itemFolder.path)).isEmpty {
      try FileManager.default.removeItem(at: itemFolder)
    }
    if (try FileManager.default.contentsOfDirectory(atPath: batch.path)).isEmpty {
      try FileManager.default.removeItem(at: batch)
    }
  }
}
