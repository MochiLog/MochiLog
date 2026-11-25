import Foundation

/// The record list and its capture time travel together over both WatchConnectivity paths.
nonisolated struct WatchRecordSnapshot<Record: Codable & Equatable> {
  let records: [Record]
  let isSampleMode: Bool
  let syncTimestamp: TimeInterval?

  init(records: [Record], isSampleMode: Bool, syncTimestamp: TimeInterval?) {
    self.records = records
    self.isSampleMode = isSampleMode
    self.syncTimestamp = syncTimestamp
  }

  init(context: [String: Any]) throws {
    guard let data = context["records"] as? Data else { throw CocoaError(.coderValueNotFound) }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    records = try decoder.decode([Record].self, from: data)
    isSampleMode = context["isSampleMode"] as? Bool ?? false
    syncTimestamp = (context["syncDate"] as? TimeInterval).flatMap { $0.isFinite ? $0 : nil }
  }

  func context(appLanguage: String) throws -> [String: Any] {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    var context: [String: Any] = [
      "records": try encoder.encode(records),
      "isSampleMode": isSampleMode,
      "appLanguage": appLanguage,
    ]
    context["syncDate"] = syncTimestamp
    return context
  }

  func hasSameContent(as other: Self) -> Bool {
    isSampleMode == other.isSampleMode && records == other.records
  }

  /// A resend (including one after restarting the iPhone app) keeps its capture time.
  static func capture(
    _ records: [Record], isSampleMode: Bool, after previous: Self?, now: TimeInterval
  ) -> Self {
    let candidate = Self(records: records, isSampleMode: isSampleMode, syncTimestamp: now)
    guard let previous else { return candidate }
    if previous.syncTimestamp != nil && candidate.hasSameContent(as: previous) { return previous }
    let nextTimestamp = previous.syncTimestamp.map { max(now, $0 + 0.001) } ?? now
    return Self(records: records, isSampleMode: isSampleMode, syncTimestamp: nextTimestamp)
  }

  /// Late replies or cached contexts cannot replace a newer Watch snapshot.
  func canFollow(_ previous: Self?) -> Bool {
    guard let previous, let last = previous.syncTimestamp else { return true }
    guard let syncTimestamp else { return false }
    return syncTimestamp > last || (syncTimestamp == last && hasSameContent(as: previous))
  }
}
