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
    print(
      "PASS: Watch legacy payloads, stable diagnostics across languages, record identity, Codable round-trip"
    )
  }
}
