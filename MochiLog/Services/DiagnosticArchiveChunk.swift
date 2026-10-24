import Foundation

/// An authenticated retry may overlap an already saved chunk. Compare only the
/// bounded overlap, then append its missing suffix; never overwrite saved bytes.
enum DiagnosticArchiveChunk {
  enum Result: Equatable {
    case appended(Int), duplicate, rejected
  }

  private static let lock = NSLock()

  static func append(_ bytes: Data, offset: Int, to url: URL) throws -> Result {
    guard !bytes.isEmpty, bytes.count <= 8_192, offset >= 0,
      offset <= 64_000_000 - bytes.count
    else { return .rejected }
    lock.lock()
    defer { lock.unlock() }
    if !FileManager.default.fileExists(atPath: url.path) {
      guard offset == 0 else { return .rejected }
      FileManager.default.createFile(atPath: url.path, contents: nil)
    }
    let handle = try FileHandle(forUpdating: url)
    defer { try? handle.close() }
    let size = try handle.seekToEnd()
    guard size <= 64_000_000, UInt64(offset) <= size else { return .rejected }
    let overlap = min(bytes.count, Int(size) - offset)
    if overlap > 0 {
      try handle.seek(toOffset: UInt64(offset))
      guard try handle.read(upToCount: overlap) == Data(bytes.prefix(overlap))
      else { return .rejected }
    }
    guard overlap < bytes.count else { return .duplicate }
    try handle.seek(toOffset: size)
    try handle.write(contentsOf: bytes.dropFirst(overlap))
    return .appended(bytes.count - overlap)
  }
}
