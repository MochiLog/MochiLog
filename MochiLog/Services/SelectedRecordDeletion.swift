import Foundation

/// A confirmation refers to the exact IDs and values the user selected, never
/// row positions or another record with the same date/model.
enum SelectedRecordDeletion {
  struct Plan {
    let ids: Set<UUID>
    let payloads: [UUID: ExactRecordPayload]

    init(ids: Set<UUID>, records: [BatteryRecord]) {
      self.ids = ids
      let grouped = Dictionary(grouping: records, by: \.id)
      payloads = ids.reduce(into: [:]) { result, id in
        guard let copies = grouped[id], copies.count == 1 else { return }
        result[id] = ExactRecordPayload(copies[0])
      }
    }
  }

  struct Result {
    let deleted: Int
    let skipped: Int
  }

  static func matchingRecords(_ plan: Plan, in records: [BatteryRecord]) -> [BatteryRecord] {
    let grouped = Dictionary(grouping: records, by: \.id)
    return plan.ids.sorted { $0.uuidString < $1.uuidString }.compactMap { id in
      guard let expected = plan.payloads[id], let copies = grouped[id], copies.count == 1,
        ExactRecordPayload(copies[0]) == expected
      else { return nil }
      return copies[0]
    }
  }

  @discardableResult
  static func delete(_ plan: Plan, from store: DataStore) throws -> Result {
    store.refreshRecords()
    let matches = matchingRecords(plan, in: store.recordsDescending)
    for record in matches { store.delete(record) }
    // Both persistent stores roll back and report save failures through this
    // throwing path; do not show a successful deletion after a rolled-back save.
    if !matches.isEmpty { try store.saveChanges() }
    return Result(deleted: matches.count, skipped: plan.ids.count - matches.count)
  }
}
