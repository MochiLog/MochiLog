import Foundation

// Standalone adapters for display-only dependencies of the production model.
enum DeviceLibrary {
  static func localizedName(for name: String) -> String { name }
  static func getSoC(for name: String) -> String? { nil }
}
enum L10n { static func string(_ key: String, table: String) -> String { key } }
final class AppSettings {
  enum Source { case nominal, raw }
  static let shared = AppSettings()
  var analysisDataSource = Source.nominal
}

final class DataStore {
  enum Failure: Error { case diskFull }
  var persisted: [BatteryRecord]
  var recordsDescending: [BatteryRecord] = []
  private var working: [BatteryRecord] = []
  var saveCount = 0
  var failSave = false
  init(_ records: [BatteryRecord]) { persisted = records; refreshRecords() }
  func refreshRecords() { working = persisted; recordsDescending = persisted }
  func delete(_ record: BatteryRecord) { working.removeAll { $0.id == record.id } }
  func saveChanges() throws {
    saveCount += 1
    if failSave { refreshRecords(); throw Failure.diskFull }
    persisted = working; recordsDescending = persisted
  }
}

@main
struct SelectedRecordDeletionTests {
  static func record(id: UUID = UUID(), cycles: Int = 100) -> BatteryRecord {
    BatteryRecord(id: id, logDate: Date(timeIntervalSince1970: 1_700_000_000),
      deviceName: "iPhone Test", cycleCount: cycles, designCapacity: 4000,
      nominalCapacity: 3800, rawCapacity: 3800)
  }

  static func main() throws {
    let a = record(), b = record(), c = record()
    let store = DataStore([a, b, c])
    let plan = SelectedRecordDeletion.Plan(ids: [a.id, c.id], records: store.recordsDescending)
    // Another device deletes one selected record and inserts an identical log
    // with a different ID before the user confirms. It must never be substituted.
    let replacement = record()
    store.persisted = [replacement, c, b]
    let result = try SelectedRecordDeletion.delete(plan, from: store)
    assert(result.deleted == 1 && result.skipped == 1)
    assert(Set(store.persisted.map(\.id)) == [replacement.id, b.id])
    assert(store.saveCount == 1, "Bulk deletion saves once")
    let repeated = try SelectedRecordDeletion.delete(plan, from: store)
    assert(repeated.deleted == 0 && store.saveCount == 1,
      "Repeating a confirmation must not delete a replacement or a remaining record")

    let edited = record(), unchanged = record()
    let editStore = DataStore([edited, unchanged])
    let editPlan = SelectedRecordDeletion.Plan(ids: [edited.id, unchanged.id], records: editStore.recordsDescending)
    edited.rawCapacity += 1
    let changed = try SelectedRecordDeletion.delete(editPlan, from: editStore)
    assert(changed.deleted == 1 && changed.skipped == 1 && editStore.persisted[0].id == edited.id,
      "Synced changes during confirmation are preserved")

    let duplicate = record(id: b.id)
    let ambiguousStore = DataStore([b, duplicate])
    let ambiguous = SelectedRecordDeletion.Plan(ids: [b.id], records: ambiguousStore.recordsDescending)
    let ambiguousResult = try SelectedRecordDeletion.delete(ambiguous, from: ambiguousStore)
    assert(ambiguousResult.deleted == 0)
    assert(ambiguousStore.persisted.count == 2 && ambiguousStore.saveCount == 0)

    let failedStore = DataStore([a, b])
    let failedPlan = SelectedRecordDeletion.Plan(ids: [a.id], records: failedStore.recordsDescending)
    failedStore.failSave = true
    do {
      _ = try SelectedRecordDeletion.delete(failedPlan, from: failedStore)
      fatalError("A rolled-back save must not report successful deletion")
    } catch DataStore.Failure.diskFull { }
    assert(failedStore.persisted.count == 2 && failedStore.recordsDescending.count == 2)

    let many = (0..<1000).map { _ in record() }
    let manyStore = DataStore(many)
    let manyPlan = SelectedRecordDeletion.Plan(ids: Set(many.prefix(750).map(\.id)), records: many)
    let later = record(); manyStore.persisted.insert(later, at: 0)
    let manyResult = try SelectedRecordDeletion.delete(manyPlan, from: manyStore)
    assert(manyResult.deleted == 750 && manyStore.persisted.count == 251)
    assert(manyStore.persisted.contains { $0.id == later.id })
    assert(manyStore.saveCount == 1)
    print("PASS: stable IDs, concurrent deletion/insertion, changed values, ambiguous IDs, save rollback, and 750-record batch")
  }
}
