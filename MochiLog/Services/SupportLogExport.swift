import Foundation

/// A bounded file snapshot, shared with the Mac implementation. The compatibility
/// stream is retained alongside feature files; source files are never rewritten.
enum SupportLogExport {
  struct Source: Sendable {
    let name: String
    let directory: URL
  }
  struct Diagnostic: Sendable {
    let name: String
    let data: Data
  }
  struct Item: Codable {
    let name: String
    let status: String
    let bytes: Int
  }

  static func days(around date: Date) -> [String] {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = "yyyy-MM-dd"
    return (0...2).compactMap { offset in
      Calendar.current.date(byAdding: .day, value: -offset, to: date).map(formatter.string)
    }
  }

  static func prepare(
    sources: [Source], days: [String], diagnostics: [Diagnostic],
    unavailable: [String] = [], directory: URL,
    maximumBytes: Int = 12 * 1024 * 1024, maximumFiles: Int = 96
  ) throws -> [URL] {
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    var files: [URL] = []
    var items: [Item] = []
    var remaining = maximumBytes
    let selectedDays = Array(days.prefix(3))
    func validName(_ text: String) -> Bool {
      !text.isEmpty && text.count <= 180
        && text.allSatisfy {
          $0.isASCII && ($0.isLetter || $0.isNumber || "-._".contains($0))
        } && !text.hasPrefix(".")
    }
    func reserve(_ name: String, size: Int) -> Bool {
      guard validName(name), !items.contains(where: { $0.name == name }) else { return false }
      guard size > 0 else {
        items.append(.init(name: name, status: "missing-or-empty", bytes: 0))
        return false
      }
      guard size <= remaining, files.count < maximumFiles else {
        items.append(.init(name: name, status: "omitted-export-limit", bytes: size))
        return false
      }
      return true
    }
    func addFile(_ source: URL, name: String) {
      do {
        let info = try source.resourceValues(forKeys: [
          .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
        ])
        guard info.isRegularFile == true, info.isSymbolicLink != true else {
          items.append(.init(name: name, status: "not-a-regular-file", bytes: 0))
          return
        }
        let size = info.fileSize ?? 0
        guard reserve(name, size: size) else { return }
        let target = directory.appendingPathComponent(name)
        _ = FileManager.default.createFile(
          atPath: target.path, contents: nil,
          attributes: [.posixPermissions: 0o600])
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        let output = try FileHandle(forWritingTo: target)
        defer { try? output.close() }
        var copied = 0
        while copied < size {
          guard let data = try input.read(upToCount: min(64 * 1024, size - copied)), !data.isEmpty
          else {
            throw CocoaError(.fileReadCorruptFile)
          }
          try output.write(contentsOf: data)
          copied += data.count
        }
        remaining -= copied
        files.append(target)
        items.append(.init(name: name, status: "included-snapshot", bytes: copied))
      } catch {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        items.append(
          .init(
            name: name,
            status: FileManager.default.fileExists(atPath: source.path) ? "read-failed" : "missing",
            bytes: 0))
      }
    }
    for diagnostic in diagnostics.prefix(64) where validName(diagnostic.name) {
      guard reserve(diagnostic.name, size: diagnostic.data.count) else { continue }
      let target = directory.appendingPathComponent(diagnostic.name)
      try diagnostic.data.write(to: target, options: .atomic)
      try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
      remaining -= diagnostic.data.count
      files.append(target)
      items.append(.init(name: diagnostic.name, status: "included", bytes: diagnostic.data.count))
    }
    for source in sources.prefix(32) where validName(source.name) {
      for day in selectedDays
      where day.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil {
        let folder = source.directory.appendingPathComponent(day, isDirectory: true)
        let folderInfo = try? folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        if folderInfo?.isDirectory == true, folderInfo?.isSymbolicLink != true {
          let children: [URL]
          do {
            children = try FileManager.default.contentsOfDirectory(
              at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
          } catch {
            items.append(
              .init(
                name: "\(source.name)-\(day)-feature-files", status: "directory-read-failed",
                bytes: 0))
            children = []
          }
          let split = children.filter { url in
            validName(url.lastPathComponent) && url.pathExtension == "log"
              && DiagnosticLogArchive.categories.contains {
                url.lastPathComponent.hasPrefix($0 + "-v")
              }
          }.sorted { $0.lastPathComponent < $1.lastPathComponent }
          if split.isEmpty {
            items.append(
              .init(
                name: "\(source.name)-\(day)-feature-files", status: "no-feature-files", bytes: 0))
          }
          for file in split {
            addFile(file, name: "\(source.name)-\(day)-\(file.lastPathComponent)")
          }
        } else {
          items.append(
            .init(
              name: "\(source.name)-\(day)-feature-files",
              status: folderInfo?.isSymbolicLink == true
                ? "symbolic-directory-skipped" : "missing-feature-directory", bytes: 0))
        }
        addFile(
          source.directory.appendingPathComponent(day + ".log"),
          name: "\(source.name)-debug-\(day).log")
      }
    }
    let manifest: [String: Any] = [
      "type": "mochilog-support-export", "schema": 1,
      "generatedAt": ISO8601DateFormatter().string(from: Date()),
      "days": selectedDays, "unavailableSources": unavailable,
      "sourceLimitReached": sources.count > 32, "diagnosticLimitReached": diagnostics.count > 64,
      "dayLimitReached": days.count > 3,
      "maximumBytes": maximumBytes, "maximumFiles": maximumFiles,
      "includedBytes": maximumBytes - remaining,
      "items": try JSONSerialization.jsonObject(with: JSONEncoder().encode(items)),
      "note":
        "Feature files are included when stored locally. Remote peers exchange the complete daily compatibility stream; original feature files may not exist on the receiving device. Missing/limited files are explicitly listed.",
    ]
    let manifestURL = directory.appendingPathComponent("mochilog-support-manifest.json")
    try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys, .prettyPrinted])
      .write(to: manifestURL, options: .atomic)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o600], ofItemAtPath: manifestURL.path)
    return files + [manifestURL]
  }
}
