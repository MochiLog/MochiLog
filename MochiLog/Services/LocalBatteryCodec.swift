import Foundation
import CryptoKit
import CoreFoundation

nonisolated enum LocalBatteryCodec {
  static func reading(_ registry: [String: Any]) throws -> LiveBatteryReading {
    var fields: [RawBatteryField] = []
    func visit(_ value: Any, path: [String]) throws {
      guard path.count <= 32, fields.count < 10000 else { throw RawBatteryField.Failure.invalid }
      if let dictionary = value as? [String: Any], !dictionary.isEmpty {
        for key in dictionary.keys.sorted() {
          guard key.count <= 512 else { throw RawBatteryField.Failure.invalid }
          try visit(dictionary[key]!, path: path + [key])
        }
        return
      }
      if let array = value as? [Any], !array.isEmpty {
        for (index, entry) in array.enumerated() { try visit(entry, path: path + ["[\(index)]"]) }
        return
      }
      let kind: String
      let text: String
      switch value {
      case let number as NSNumber:
        let boolean = CFGetTypeID(number) == CFBooleanGetTypeID()
        kind = boolean ? "boolean" : "number"
        text = boolean ? (number.boolValue ? "true" : "false") : number.stringValue
      case let string as String: kind = "string"; text = string
      case let blob as Data: kind = "data"; text = blob.base64EncodedString()
      case let date as Date: kind = "date"; text = ISO8601DateFormatter().string(from: date)
      case is [String: Any]: kind = "dictionary"; text = "{}"
      case is [Any]: kind = "array"; text = "[]"
      default: throw RawBatteryField.Failure.invalid
      }
      guard text.count <= 131072 else { throw RawBatteryField.Failure.invalid }
      fields.append(RawBatteryField(path: path, kind: kind, value: text))
    }
    try visit(registry, path: [])
    let battery = registry["BatteryData"] as? [String: Any] ?? [:]
    let limits = ["CycleCount": 0...100000, "DesignCapacity": 1...200000,
      "FullChargeCapacity": 1...200000, "NominalChargeCapacity": 1...200000,
      "AppleRawMaxCapacity": 1...200000, "CurrentCapacity": 0...100]
    var values: [String: Int] = [:]
    for (key, range) in limits {
      let raw = ["CycleCount", "CurrentCapacity"].contains(key) ? registry[key] : (battery[key] ?? registry[key])
      if let number = raw as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
        number.doubleValue.isFinite, number.doubleValue == Double(number.intValue), range.contains(number.intValue) {
        values[key] = number.intValue
      }
    }
    let charging = (registry["IsCharging"] as? NSNumber).flatMap {
      CFGetTypeID($0) == CFBooleanGetTypeID() ? $0.boolValue : nil
    }
    var core: [String: Any] = values
    if let charging { core["IsCharging"] = charging }
    let coreData = try JSONSerialization.data(withJSONObject: core, options: [.sortedKeys, .withoutEscapingSlashes])
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let details = try encoder.encode(fields)
    guard details.count <= 262144 else { throw RawBatteryField.Failure.invalid }
    let hash: (Data) -> String = { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() }
    return LiveBatteryReading(values: values, charging: charging, revision: hash(coreData), acquiredAt: Date(),
      detailsJSON: String(decoding: details, as: UTF8.self), detailsRevision: hash(details))
  }
}
