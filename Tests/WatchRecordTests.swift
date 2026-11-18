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
      cycleCount: oldRecord.cycleCount, nominalHealthPercent: 96, healthPercent: 97,
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
    print(
      "PASS: Watch legacy payloads, stable diagnostics across languages, record identity, Codable round-trip"
    )
  }
}
