import Foundation

struct LiveBatterySource: Identifiable {
  let id: UUID
  let physicalDeviceID: UUID
  let model: String
  let name: String
  let reading: LiveBatteryReading?
  let state: String
}

struct LiveBatteryDeviceReadings: Identifiable {
  let id: UUID
  let sources: [LiveBatterySource]
}

/// Compare values only. Source status and acquisition times remain separate;
/// a newer timestamp must not silently replace a different computer's value.
struct ComparedBatteryField<Key: Hashable, Value: Equatable>: Identifiable {
  let id: Key
  let values: [Value?]
  var isCommon: Bool {
    guard let first = values.first else { return false }
    return values.dropFirst().allSatisfy { $0 == first }
  }
}

struct BatteryFieldPath: Hashable {
  let path: [String]
  let occurrence: Int
  var group: String { path.count > 1 ? path[0] : "" }
  var label: String { (path.count > 1 ? Array(path.dropFirst()) : path).joined(separator: " › ") }
}

enum LiveBatteryComparison {
  static func devices(_ sources: [LiveBatterySource]) -> [LiveBatteryDeviceReadings] {
    var order: [UUID] = []
    var groups: [UUID: [LiveBatterySource]] = [:]
    for source in sources {
      if groups[source.physicalDeviceID] == nil { order.append(source.physicalDeviceID) }
      groups[source.physicalDeviceID, default: []].append(source)
    }
    return order.map { LiveBatteryDeviceReadings(id: $0, sources: groups[$0] ?? []) }
  }

  static func summary(_ readings: [LiveBatteryReading?]) -> [ComparedBatteryField<String, BatterySummaryRow>] {
    let sources = readings.map {
      BatteryPresentation.summary(values: $0?.values ?? [:], charging: $0?.charging, fields: $0?.fields ?? [])
    }
    return (BatteryPresentation.primaryKeys + BatteryPresentation.extraKeys).compactMap { key in
      let values = sources.map { $0.first { $0.key == key } }
      guard values.contains(where: { $0 != nil }) else { return nil }
      return ComparedBatteryField(id: key, values: values)
    }
  }

  static func details(_ readings: [LiveBatteryReading?]) -> [ComparedBatteryField<BatteryFieldPath, RawBatteryField>] {
    let sources: [[BatteryFieldPath: RawBatteryField]] = readings.map { reading in
      var values: [BatteryFieldPath: RawBatteryField] = [:]
      var occurrences: [[String]: Int] = [:]
      let fields = BatteryPresentation.details(values: reading?.values ?? [:], charging: reading?.charging,
        fields: reading?.fields ?? [])
      for field in fields {
        // Preserve duplicate paths and types rather than crashing or dropping data.
        let occurrence = occurrences[field.path, default: 0]
        occurrences[field.path] = occurrence + 1
        values[BatteryFieldPath(path: field.path, occurrence: occurrence)] = field
      }
      return values
    }
    let keys = Set(sources.flatMap { $0.keys }).sorted {
      $0.path == $1.path ? $0.occurrence < $1.occurrence : $0.path.lexicographicallyPrecedes($1.path)
    }
    return keys.map { key in ComparedBatteryField(id: key, values: sources.map { $0[key] }) }
  }
}
