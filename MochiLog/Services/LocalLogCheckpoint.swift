import Foundation

/// Documents URLs and enumerated URLs can use /var and /private/var aliases.
/// Derive receipt tokens from path components, never offsets into a path string.
nonisolated enum LocalLogCheckpoint {
  static func base(for file: URL, root: URL) -> String? {
    guard file.isFileURL, root.isFileURL else { return nil }
    let parent = root.resolvingSymlinksInPath().standardizedFileURL.pathComponents
    let components = file.resolvingSymlinksInPath().standardizedFileURL.pathComponents
    guard components.count > parent.count,
      Array(components.prefix(parent.count)) == parent
    else { return nil }
    let base = components.dropFirst(parent.count).joined(separator: "::")
    return CloudSharedLogToken.validBase(base) ? base : nil
  }
}
