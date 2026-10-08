import Foundation
import CryptoKit

@main struct LiveBatteryComparisonTests {
  static func main() throws {
    func reading(_ fields: [RawBatteryField], at date: Date = .distantPast) throws -> LiveBatteryReading {
      let data = try JSONEncoder().encode(fields)
      return LiveBatteryReading(values: [:], charging: false, revision: String(repeating: "a", count: 64),
        acquiredAt: date, detailsJSON: String(decoding: data, as: UTF8.self),
        detailsRevision: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
    }
    let cycle = RawBatteryField(path: ["CycleCount"], kind: "number", value: "245")
    let voltage = RawBatteryField(path: ["Voltage"], kind: "number", value: "4010")
    let huge = RawBatteryField(path: ["BatteryData", "Huge"], kind: "number", value: "18446744073709551615")
    let a = try reading([cycle, voltage, huge])
    let same = try reading([cycle, voltage, huge], at: Date())
    precondition(LiveBatteryComparison.summary([a, same]).allSatisfy(\.isCommon), "Time is not a value difference")
    let changed = try reading([cycle, RawBatteryField(path: ["Voltage"], kind: "number", value: "3990"), huge])
    let summary = LiveBatteryComparison.summary([a, changed])
    precondition(summary.filter { !$0.isCommon }.map(\.id) == ["Voltage"])
    precondition(summary.first { $0.id == "CycleCount" }?.isCommon == true)
    let details = LiveBatteryComparison.details([a, changed])
    precondition(details.count == 1 && details[0].isCommon && details[0].values[0]?.value == huge.value)
    precondition(!LiveBatteryComparison.details([a, nil])[0].isCommon, "Missing is not equal to a present value")
    let typed = try reading([RawBatteryField(path: huge.path, kind: "string", value: huge.value)])
    precondition(!LiveBatteryComparison.details([a, typed])[0].isCommon, "Types must not be conflated")
    let paths = try reading([
      RawBatteryField(path: ["A/B", "C"], kind: "string", value: "same"),
      RawBatteryField(path: ["A", "B/C"], kind: "string", value: "same"),
      RawBatteryField(path: ["Duplicate"], kind: "number", value: "1"),
      RawBatteryField(path: ["Duplicate"], kind: "number", value: "2")])
    let distinct = LiveBatteryComparison.details([paths, paths])
    precondition(distinct.count == 4 && Set(distinct.map(\.id)).count == 4 && distinct.allSatisfy(\.isCommon))
    let deviceA = UUID(), deviceB = UUID()
    let sources = [
      LiveBatterySource(id: UUID(), physicalDeviceID: deviceA, model: "iPad16,6", name: "Mac", reading: a, state: "current"),
      LiveBatterySource(id: UUID(), physicalDeviceID: deviceA, model: "iPad16,6", name: "Windows", reading: changed, state: "stale"),
      LiveBatterySource(id: UUID(), physicalDeviceID: deviceB, model: "iPad16,6", name: "Mac 2", reading: same, state: "current")]
    let devices = LiveBatteryComparison.devices(sources)
    precondition(devices.count == 2 && devices[0].sources.count == 2 && devices[1].sources.count == 1,
      "The same model is not the same physical device")
    precondition(devices[0].sources.map(\.state) == ["current", "stale"])
    precondition(LiveBatteryComparison.summary([]).isEmpty && LiveBatteryComparison.details([]).isEmpty)
    print("Live Battery comparison tests passed")
  }
}
