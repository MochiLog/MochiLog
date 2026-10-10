import Foundation

/// Versioned feature files plus an append-only stream for older diagnostic peers.
/// Keep this Foundation-only format aligned with the desktop implementations.
enum DiagnosticLogArchive {
  static let formatVersion = 2
  static let categories = ["background", "local-collection", "pc-transfer", "live-battery", "cloud-sync", "pairing", "general"]
  private static let lock = NSLock()

  static func category(for message: String) -> String {
    let text = message.lowercased()
    if text.contains("local scheduler:") || text.contains("background") || text.contains("os wake") { return "background" }
    if text.contains("live battery") || text.contains("current battery") || text.contains("battery snapshot") { return "live-battery" }
    if text.contains("pairing") || text.contains("usb trust") || text.contains("ペアリング") { return "pairing" }
    if text.contains("cloud sharing") || text.contains("cloudkit") || text.contains("icloud") { return "cloud-sync" }
    if text.contains("local diagnostics") || text.contains("local collection") { return "local-collection" }
    if text.contains("connection:") || text.contains("transfer") || text.contains("preflight:") ||
      text.contains("bonjour") || text.contains("collection") || text.contains("受信") { return "pc-transfer" }
    return "general"
  }

  private static func safe(_ value: String) -> String {
    let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")
    let cleaned = String(value.filter { allowed.contains($0) }.prefix(64))
    return cleaned.isEmpty ? "unknown" : cleaned
  }

  @discardableResult static func append(_ event: String, root: URL,
    appVersion: String, build: String, legacy: Bool = false) -> Bool {
    let day = String(event.prefix(10))
    guard day.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil else { return false }
    lock.lock(); defer { lock.unlock() }
    let category = category(for: event)
    let version = legacy ? 1 : formatVersion
    let identity = legacy ? "legacy" : safe(appVersion) + "-" + safe(build)
    let folder = root.appendingPathComponent(day, isDirectory: true)
    let file = folder.appendingPathComponent("\(category)-v\(version)-\(identity).log")
    let aggregate = root.appendingPathComponent("\(day).log")
    let marker = folder.appendingPathComponent(".compat-v\(version)-\(identity)")
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700])
      let metadata: [String: Any] = ["type": "mochilog-diagnostic-log", "formatVersion": version,
        "category": category, "appVersion": legacy ? "unknown" : appVersion,
        "build": legacy ? "unknown" : build, "recordLayout": "timestamp | message",
        "createdAt": String(event.prefix(while: { $0 != " " })), "timeZone": TimeZone.autoupdatingCurrent.identifier]
      let header = Data("# ".utf8) + (try JSONSerialization.data(withJSONObject: metadata, options: .sortedKeys)) + Data("\n".utf8)
      let body = Data((event + "\n").utf8)
      try appendBytes(body, to: file, initialHeader: header)
      // Existing exchange offsets refer to this stream. Never rebuild or reorder it.
      if !FileManager.default.fileExists(atPath: marker.path) {
        var combinedMetadata = metadata
        combinedMetadata["category"] = "combined"
        let combinedHeader = Data("# ".utf8) + (try JSONSerialization.data(withJSONObject: combinedMetadata, options: .sortedKeys)) + Data("\n".utf8)
        try appendBytes(combinedHeader, to: aggregate)
        try combinedHeader.write(to: marker, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: marker.path)
      }
      try appendBytes(body, to: aggregate)
      return true
    } catch { return false } // Diagnostics must not interrupt collection or transfers.
  }

  private static func appendBytes(_ bytes: Data, to url: URL, initialHeader: Data = Data()) throws {
    if !FileManager.default.fileExists(atPath: url.path) {
      try initialHeader.write(to: url, options: .atomic)
    }
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.seekToEnd(); try handle.write(contentsOf: bytes)
  }

  /// Only a validated date may select a folder for pruning or user deletion.
  static func removeDay(_ day: String, root: URL) {
    guard day.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil else { return }
    try? FileManager.default.removeItem(at: root.appendingPathComponent("\(day).log"))
    try? FileManager.default.removeItem(at: root.appendingPathComponent(day, isDirectory: true))
  }
}
