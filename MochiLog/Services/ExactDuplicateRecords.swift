import Foundation

/// Only records with the same complete log payload are candidates. The record ID and
/// creation date are excluded because imports on different devices assign new values.
struct ExactRecordPayload: Hashable {
  let logDate: Date
  let deviceName: String
  let deviceModelCode: String?
  let physicalDeviceID: UUID?
  let osVersion: String?
  let productSku: String?
  let storage: String?
  let ram: String?
  let manufactureDate: String?
  let firstUseDate: Date?
  let cycleCount: Int
  let designCapacity: Int
  let nominalCapacity: Int
  let rawCapacity: Int
  let lowRateCapacity: Int?
  let deflator: Double?
  let settingsDisplayPercent: Int?
  let diagnosticResult: String?
  let avgTemp: Double?
  let maxTemp: Double?
  let minTemp: Double?
  let maxVoltage: Double?
  let minVoltage: Double?
  let minSoC: Int?
  let maxSoC: Int?

  init(_ record: BatteryRecord) {
    logDate = record.logDate
    deviceName = record.deviceName
    deviceModelCode = record.deviceModelCode
    physicalDeviceID = record.physicalDeviceID
    osVersion = record.osVersion
    productSku = record.productSku
    storage = record.storage
    ram = record.ram
    manufactureDate = record.manufactureDate
    firstUseDate = record.firstUseDate
    cycleCount = record.cycleCount
    designCapacity = record.designCapacity
    nominalCapacity = record.nominalCapacity
    rawCapacity = record.rawCapacity
    lowRateCapacity = record.lowRateCapacity
    deflator = record.deflator
    settingsDisplayPercent = record.settingsDisplayPercent
    diagnosticResult = record.diagnosticResult
    avgTemp = record.avgTemp
    maxTemp = record.maxTemp
    minTemp = record.minTemp
    maxVoltage = record.maxVoltage
    minVoltage = record.minVoltage
    minSoC = record.minSoC
    maxSoC = record.maxSoC
  }
}

struct ExactDuplicateGroup: Identifiable {
  let id: ExactRecordPayload
  let records: [BatteryRecord]

  var extraCount: Int { records.count - 1 }
  var representative: BatteryRecord { records[0] }
}

enum ExactDuplicateRecords {
  static func groups(in records: [BatteryRecord]) -> [ExactDuplicateGroup] {
    var grouped: [ExactRecordPayload: [BatteryRecord]] = [:]
    var idCounts: [UUID: Int] = [:]
    for record in records {
      grouped[ExactRecordPayload(record), default: []].append(record)
      idCounts[record.id, default: 0] += 1
    }
    return grouped.compactMap { payload, copies in
      // A duplicate record ID can indicate a store fault, not independent imports.
      guard copies.count > 1, copies.allSatisfy({ idCounts[$0.id] == 1 }) else { return nil }
      return ExactDuplicateGroup(
        id: payload,
        records: copies.sorted { $0.id.uuidString < $1.id.uuidString }
      )
    }.sorted {
      if $0.id.logDate != $1.id.logDate { return $0.id.logDate > $1.id.logDate }
      return $0.id.deviceName < $1.id.deviceName
    }
  }

  /// Re-fetch immediately before deletion. The same smallest UUID is kept on
  /// every device, even when CloudKit deliveries arrive in different orders.
  @discardableResult
  static func removeSelected(_ selected: Set<ExactRecordPayload>, from store: DataStore) throws -> Int {
    guard !selected.isEmpty else { return 0 }
    store.refreshRecords()
    let candidates = groups(in: store.recordsDescending).filter { selected.contains($0.id) }
    let extra = candidates.flatMap { Array($0.records.dropFirst()) }
    guard !extra.isEmpty else { return 0 }
    for record in extra { store.delete(record) }
    try store.saveChanges()
    return extra.count
  }
}
