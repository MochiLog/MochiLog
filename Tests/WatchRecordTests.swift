import Foundation

enum L10n {
  static func text(_ key: String) -> String { "localized:\(key)" }
}

@main
struct WatchRecordTests {
  static func main() throws {
    let legacy = """
      {"deviceName":"iPhone 15 Pro","logDate":"2026-09-01T03:00:00Z","cycleCount":42,
       "nominalHealthPercent":96,"healthPercent":97,"diagnosticResult":"✅ 正常"}
      """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let oldRecord = try decoder.decode(WatchBatteryRecord.self, from: Data(legacy.utf8))
    assert(oldRecord.diagnosticCode == nil, "Existing iPhone payloads must remain decodable")
    assert(oldRecord.localizedDiagnosticResult == "localized:diag_normal")
    let current = WatchBatteryRecord(
      deviceName: oldRecord.deviceName, logDate: oldRecord.logDate,
      cycleCount: oldRecord.cycleCount + 1, nominalHealthPercent: 96, healthPercent: 97,
      diagnosticResult: "beliebiger übersetzter Text", diagnosticCode: "diag_replace_recommended")
    assert(
      current.localizedDiagnosticResult == "localized:diag_replace_recommended",
      "Stable diagnostic codes must override the sending phone's display language")
    assert(current.id == oldRecord.id, "Adding localization metadata must preserve record identity")
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let roundTrip = try decoder.decode(WatchBatteryRecord.self, from: encoder.encode(current))
    assert(roundTrip == current)
    let unknown = WatchBatteryRecord(
      deviceName: "Future device", logDate: oldRecord.logDate,
      cycleCount: 0, nominalHealthPercent: 100, healthPercent: 100,
      diagnosticResult: "Future diagnostic", diagnosticCode: "future_code")
    assert(unknown.localizedDiagnosticResult == "Future diagnostic")
    for (value, expected) in [(97.9, 97), (101.5, 101), (0.0, 0)] {
      assert(WatchBatteryRecord.displayedPercentage(value) == expected)
    }
    for value in [Double.nan, .infinity, -.infinity, 1e100, Double(Int.max), -1] {
      assert(WatchBatteryRecord.displayedPercentage(value) == nil)
      assert(
        WatchBatteryRecord.percentageText(WatchBatteryRecord.displayedPercentage(value)) == "—")
    }
    let oversized = legacy.replacingOccurrences(
      of: "\"healthPercent\":97", with: "\"healthPercent\":1e100")
    let oversizedRecord = try decoder.decode(WatchBatteryRecord.self, from: Data(oversized.utf8))
    assert(oversizedRecord.healthPercent == 1e100, "Keep the original received value")
    assert(
      oversizedRecord.displayedHealthPercent == nil && oversizedRecord.healthPercentText == "—")
    assert(current.healthPercentText == "97%" && current.nominalHealthPercentText == "96%")
    try testSnapshotFreshness(oldRecord, current)
    print(
      "PASS: Watch legacy payloads, stable diagnostics across languages, record identity, Codable round-trip"
    )
  }

  private static func testSnapshotFreshness(_ oldRecord: WatchBatteryRecord, _ changed: WatchBatteryRecord)
    throws
  {
    typealias Snapshot = WatchRecordSnapshot<WatchBatteryRecord>
    let original = Snapshot.capture([oldRecord], isSampleMode: false, after: nil, now: 100)
    let cachedContext = try original.context(appLanguage: "ja")
    let recalled = try Snapshot(context: cachedContext)
    let retried = Snapshot.capture([oldRecord], isSampleMode: false, after: recalled, now: 200)
    assert(retried.syncTimestamp == 100, "Do not refresh the timestamp when resending the same records")

    // The newest record can change without the number of records changing.
    let updated = Snapshot.capture([changed], isSampleMode: false, after: retried, now: 300)
    let freshReply = try Snapshot(context: updated.context(appLanguage: "en"))
    assert(freshReply.syncTimestamp == 300 && freshReply.records == [changed])
    assert(freshReply.records.first?.cycleCount == oldRecord.cycleCount + 1)
    assert(freshReply.canFollow(recalled))
    assert(!recalled.canFollow(freshReply), "A delayed background context cannot undo a manual reply")
    assert(freshReply.canFollow(freshReply) && freshReply.hasSameContent(as: updated))

    let cleared = Snapshot.capture([], isSampleMode: false, after: updated, now: 299)
    assert(cleared.records.isEmpty && cleared.canFollow(updated), "An intentional deletion must sync")
    let legacy = try Snapshot(context: ["records": cachedContext["records"]!])
    assert(legacy.syncTimestamp == nil && legacy.canFollow(nil) && !legacy.canFollow(freshReply))
    let legacyResend = Snapshot(records: [changed], isSampleMode: false, syncTimestamp: 400)
    assert(legacyResend.canFollow(freshReply) && legacyResend.hasSameContent(as: freshReply))
    print("PASS: Watch snapshots keep retry timestamps, include same-count changes and reject late data")
  }
}
