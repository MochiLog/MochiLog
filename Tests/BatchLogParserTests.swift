import Foundation

struct FileImportResult {}
@MainActor final class AppSettings {
  static let shared = AppSettings()
  var selectedTabIndex = 0
}
enum L10n { static func string(_ key: String, table: String) -> String { key } }
enum DeviceLibrary {
  static func getDeviceName(for identifier: String) -> String? { "Test Device" }
  static func getCapacity(for name: String) -> Int? { 4000 }
}
enum DeviceProfileStore {
  static let shared = DeviceProfileStoreStub()
}
struct DeviceProfileStoreStub {
  struct Variant { let capacity: Int? }
  func capacityVariant(for name: String, productSku: String?) -> Variant? { nil }
}
final class ErrorLogStore {
  static let shared = ErrorLogStore()
  func saveLog(message: String, rawText: String?) {}
}

@main
struct BatchLogParserTests {
  @MainActor static func main() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let queue = SharedImportQueue()
    for index in 1...8 {
      let header = "{\"timestamp\":\"2026-09-0\(index) 09:00:00.00 +0900\",\"bug_type\":\"211\"}"
      let metadata = "{\"deviceCapacity\":256,\"dramSize\":7.5,\"productSku\":\"C/A\"}"
      let battery = "{\"hardwareModel\":\"iPhone99,1\",\"message\":{\"last_value_CycleCount\":42,\"last_value_NominalChargeCapacity\":3900,\"last_value_AppleRawMaxCapacity\":3950}}"
      let unrelated = "{\"message\":{\"Count\":1,\"errorCode\":0}}"
      let url = directory.appendingPathComponent("Analytics-\(index).ips.ca.synced")
      try (header + "\n" + metadata + "\n" + (index == 8 ? unrelated : battery)).write(to: url, atomically: true, encoding: .utf8)
      queue.enqueue(url)
    }
    assert(queue.begin())
    let urls = queue.takeNext()
    assert(urls.count == 8, "All eight inputs must remain queued")
    var valid = 0
    var unsupported = 0
    for url in urls {
      let parsed = LogParser.parse(text: try LogTextReader.read(url), enableValidation: false)
      if parsed.failureDescription == "import_no_battery_measurements" { unsupported += 1 }
      else {
        assert(parsed.logDate != nil && parsed.cycleCount == 42 && parsed.nominalCapacity == 3900)
        assert(parsed.productSku == "C/A" && parsed.storage == "256 GB" && parsed.ram == "7.5 GB")
        valid += 1
      }
      queue.acknowledge(url)
    }
    queue.finish()
    assert(valid == 7 && unsupported == 1, "One nonbattery file must not invalidate seven valid logs")
    let malformed = LogParser.parse(text: "{\"message\":{\"last_value_NominalChargeCapacity\":\"invalid\"}}")
    assert(malformed.failureDescription == "import_invalid_battery_format")
    let watchHeader = "{\"timestamp\":\"2026-09-29 09:00:00.00 +0900\",\"os_version\":\"Watch OS 27.2\"}"
    let watchBattery = "{\"name\":\"BatteryConfigValueHistogramFinal_V2\",\"message\":{\"last_value_CycleCount\":205,\"last_value_NominalChargeCapacity\":366,\"last_value_AppleRawMaxCapacity\":353}}"
    let watchShutdown = "{\"name\":\"BatteryShutdownHistogram\",\"message\":{\"last_value_CycleCount\":null,\"last_value_NominalChargeCapacity\":366,\"last_value_AppleRawMaxCapacity\":null}}"
    let watchResult = LogParser.parse(text: [watchHeader, watchBattery, watchShutdown].joined(separator: "\n"),
      enableValidation: false)
    assert(watchResult.failureDescription == nil && watchResult.cycleCount == 205 &&
      watchResult.nominalCapacity == 366 && watchResult.rawCapacity == 353,
      "A later Watch shutdown row must not replace a complete battery measurement")
    if let path = CommandLine.arguments.dropFirst().first {
      let result = LogParser.parse(text: try LogTextReader.read(URL(fileURLWithPath: path)))
      assert(result.failureDescription == "import_no_battery_measurements")
      print("PASS: supplied failure contains no battery measurements")
    }
    print("PASS: eight inputs, seven valid logs plus one nonbattery log, malformed format distinguished")
  }
}
