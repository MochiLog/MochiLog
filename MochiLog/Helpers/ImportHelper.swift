import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation

extension HomeView {
  /// The picker and Open In routes share one import pipeline.
  @MainActor
  func handleFileImport(result: Result<[URL], Error>) async {
    switch result {
    case .success(let urls):
      guard !urls.isEmpty else { return }
      var scoped: [URL] = []
      defer { for url in scoped { url.stopAccessingSecurityScopedResource() } }
      var files: [URL] = []
      var directories: [URL] = []
      var errors: [String] = []
      for url in urls {
        if url.startAccessingSecurityScopedResource() { scoped.append(url) }
        do {
          if try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
            directories.append(url)
            files += try await ImportHelper.recursiveContentsOfFolder(url: url)
          } else if url.pathExtension.lowercased() == "zip" {
            files += try await ImportHelper.extractZipContents(zipURL: url)
          } else {
            files.append(url)
          }
        } catch {
          errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
        }
      }
      files = ImportHelper.filterSupportedFiles(files, supportedTypes: [.plainText, .json])
      // The queue retains parent directory permissions even if another batch is in flight.
      for file in files {
        let parents = directories.filter { file.path.hasPrefix($0.path + "/") }
        SharedImportQueue.shared.enqueue(file, accessRoots: parents)
      }
      await consumeSharedImports()
      if !errors.isEmpty || files.isEmpty {
        errorMessage =
          errors.isEmpty
          ? L10n.string("no_supported_files", table: "Home") : errors.joined(separator: "\n")
        showingErrorAlert = true
      }
    case .failure(let error):
      if (error as NSError).domain == NSCocoaErrorDomain
        && (error as NSError).code == CocoaError.userCancelled.rawValue
      {
        return
      }
      errorMessage =
        "\(L10n.string("file_select_error", table: "Home")): \(error.localizedDescription)"
      showingErrorAlert = true
    }
  }
}

struct ImportHelper {
  nonisolated static func recursiveContentsOfFolder(url: URL) async throws -> [URL] {
    try await Task.detached(priority: .userInitiated) {
      var readError: Error?
      guard
        let enumerator = FileManager.default.enumerator(
          at: url, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
          options: [.skipsHiddenFiles],
          errorHandler: { _, error in
            readError = error; return false
          })
      else { throw CocoaError(.fileReadUnknown) }
      var files: [URL] = []
      while let file = enumerator.nextObject() as? URL {
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        if values.isRegularFile == true && values.isSymbolicLink != true { files.append(file) }
      }
      if let readError { throw readError }
      return files.sorted { $0.path < $1.path }
    }.value
  }

  nonisolated static func extractZipContents(zipURL: URL) async throws -> [URL] {
    try await Task.detached(priority: .userInitiated) {
      let fm = FileManager.default
      let directory = fm.temporaryDirectory.appendingPathComponent(
        UUID().uuidString, isDirectory: true)
      try fm.createDirectory(at: directory, withIntermediateDirectories: true)
      do {
        let archive = try Archive(url: zipURL, accessMode: .read)
        var files: [URL] = []
        for entry in archive {
          guard entry.type != .symlink else { throw CocoaError(.fileReadUnsupportedScheme) }
          let destination = directory.appendingPathComponent(entry.path).standardizedFileURL
          guard destination.path.hasPrefix(directory.standardizedFileURL.path + "/") else {
            throw CocoaError(.fileReadInvalidFileName)
          }
          if entry.type == .directory { continue }
          guard !entry.path.hasPrefix("__MACOSX/"), !destination.lastPathComponent.hasPrefix(".")
          else { continue }
          try fm.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
          _ = try archive.extract(entry, to: destination)
          files.append(destination)
        }
        return files.sorted { $0.path < $1.path }
      } catch {
        try? fm.removeItem(at: directory)
        throw error
      }
    }.value
  }

  nonisolated static func filterSupportedFiles(_ urls: [URL], supportedTypes: [UTType]) -> [URL] {
    var seen: Set<URL> = []
    return urls.filter { url in
      guard seen.insert(url.standardizedFileURL).inserted else { return false }
      let name = url.lastPathComponent.lowercased()
      if name.hasSuffix(".ips.ca.synced") { return true }
      if ["txt", "ips", "log", "json"].contains(url.pathExtension.lowercased()) { return true }
      if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
        return supportedTypes.contains { type.conforms(to: $0) }
      }
      return false
    }
  }
}
