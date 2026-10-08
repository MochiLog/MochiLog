import CryptoKit
import Foundation

/// Versioned origin token. No component is ever used as an unchecked path.
struct CloudSharedLogToken {
  let scope: String
  let origin: UUID
  let base: String
  var value: String { "Shared::\(scope)::\(origin.uuidString)::\(base)" }
  /// Account scope is deliberately excluded from support logs.
  static func debugLabel(_ text: String) -> String {
    if let token = parse(text) { return "Shared[origin=\(token.origin.uuidString)]::\(token.base)" }
    if text.hasPrefix("Shared::") { return "Shared[invalid token]" }
    return String(String.UnicodeScalarView(text.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }.prefix(800)))
  }
  static func validScope(_ text: String) -> Bool {
    text.count == 64 && text.allSatisfy { "0123456789abcdef".contains($0) }
  }
  static func parse(_ text: String) -> Self? {
    let parts = text.components(separatedBy: "::")
    guard (5...6).contains(parts.count), parts[0] == "Shared",
      validScope(parts[1]), let origin = UUID(uuidString: parts[2]) else { return nil }
    let base = parts.dropFirst(3).joined(separator: "::")
    guard validBase(base) else { return nil }
    return Self(scope: parts[1], origin: origin, base: base)
  }
  static func validBase(_ text: String) -> Bool {
    let parts = text.components(separatedBy: "::")
    guard (2...3).contains(parts.count), ["Host", "Watch"].contains(parts[0]),
      let name = parts.last, name.hasPrefix("Analytics-"), name.hasSuffix(".ips.ca.synced"),
      !name.contains("/"), !name.contains("\\"), !name.contains(".."),
      !name.localizedCaseInsensitiveContains("session"),
      !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }), text.utf8.count <= 800 else { return false }
    if parts.count == 3 {
      return parts[0] == "Watch" && parts[1].range(of: #"^ProxiedDevice-[a-fA-F0-9]+$"#,
        options: .regularExpression) != nil
    }
    return true
  }
  static func measurementOrigin(base: String, origin: UUID) -> UUID? {
    let parts = base.components(separatedBy: "::")
    guard validBase(base) else { return nil }
    if parts[0] == "Host" { return origin }
    guard parts.count == 3 else { return nil }
    let hash = SHA256.hash(data: Data("\(origin.uuidString)|\(parts[1])".utf8))
    var b = Array(hash.prefix(16)); b[6] = (b[6] & 15) | 80; b[8] = (b[8] & 63) | 128
    return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
      b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
  }
  /// Coalesce one logical content-derived record without deleting cloud objects.
  /// Metadata may be localized differently on independently importing devices.
  static func coalesced<T>(_ rows: [T], id: (T) -> UUID, origin: (T) -> UUID?,
    date: (T) -> Date) -> [T] {
    var seen: [UUID: Set<String>] = [:]
    return rows.filter { row in
      let id = id(row)
      guard id.uuid.6 >> 4 == 5, let source = origin(row) else { return true }
      let identity = "\(source.uuidString)|\(date(row).timeIntervalSince1970)"
      return seen[id, default: []].insert(identity).inserted
    }
  }
  /// Every replica retains the same oldest creation timestamp. Only strictly
  /// newer copies may be removed; ties are retained so no replica can delete
  /// a different "last copy". The source/date must match as well as the v5 ID.
  static func redundantCopies<T>(_ rows: [T], id: (T) -> UUID, origin: (T) -> UUID?,
    date: (T) -> Date, createdAt: (T) -> Date) -> [T] {
    var oldest: [String: Date] = [:]
    func key(_ row: T) -> String? {
      let id = id(row)
      guard id.uuid.6 >> 4 == 5, let source = origin(row) else { return nil }
      return "\(id.uuidString)|\(source.uuidString)|\(date(row).timeIntervalSince1970)"
    }
    for row in rows {
      guard let key = key(row) else { continue }
      oldest[key] = min(oldest[key] ?? createdAt(row), createdAt(row))
    }
    return rows.filter { row in
      guard let key = key(row), let first = oldest[key] else { return false }
      return createdAt(row) > first
    }
  }
  static func recordID(origin: UUID, digest: String) -> UUID {
    let hash = SHA256.hash(data: Data("mochilog.pc-record.v1|\(origin.uuidString)|\(digest.lowercased())".utf8))
    var b = Array(hash.prefix(16)); b[6] = (b[6] & 15) | 80; b[8] = (b[8] & 63) | 128
    return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
      b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
  }
}
