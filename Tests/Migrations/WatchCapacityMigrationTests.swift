import CoreData
import SwiftData
import XCTest

@testable import MochiLog

@MainActor
final class WatchCapacityMigrationTests: XCTestCase {
  private func fixture(name: String = "Apple Watch 3 (42mm) Cellular", capacity: Int = 279)
    -> BatteryRecord
  {
    BatteryRecord(
      logDate: Date(timeIntervalSince1970: 1_700_000_000), deviceName: name,
      deviceModelCode: "Watch3,4", physicalDeviceID: UUID(), cycleCount: 432,
      designCapacity: capacity, nominalCapacity: 310, rawCapacity: 300,
      avgTemp: 24.5)
  }

  private func assertPreserved(_ result: BatteryRecord, _ original: BatteryRecord, capacity: Int) {
    XCTAssertEqual(result.designCapacity, capacity)
    XCTAssertEqual(result.id, original.id)
    XCTAssertEqual(result.physicalDeviceID, original.physicalDeviceID)
    XCTAssertEqual(result.logDate, original.logDate)
    XCTAssertEqual(result.deviceName, original.deviceName)
    XCTAssertEqual(result.deviceModelCode, original.deviceModelCode)
    XCTAssertEqual(result.rawCapacity, original.rawCapacity)
    XCTAssertEqual(result.nominalCapacity, original.nominalCapacity)
    XCTAssertEqual(result.cycleCount, original.cycleCount)
    XCTAssertEqual(result.avgTemp, original.avgTemp)
  }

  func testCoreDataUpgradeAndLateArrival() throws {
    let container = NSPersistentContainer(
      name: "MigrationTests", managedObjectModel: CoreDataStore.createManagedObjectModel())
    let description = NSPersistentStoreDescription()
    description.type = NSInMemoryStoreType
    container.persistentStoreDescriptions = [description]
    var loadError: Error?
    container.loadPersistentStores { _, error in loadError = error }
    if let loadError { throw loadError }
    let context = container.viewContext
    let first = fixture()
    let saved = CDBatteryRecord.from(first, context: context)
    try context.save()
    let oldFlag = UserDefaults.standard.object(
      forKey: Migration_v3_WatchSeries3Capacity.coreDataKey)
    defer {
      UserDefaults.standard.set(oldFlag, forKey: Migration_v3_WatchSeries3Capacity.coreDataKey)
    }
    try Migration_v3_WatchSeries3Capacity.migrate(viewContext: context)
    assertPreserved(saved.toBatteryRecord(), first, capacity: 352)
    XCTAssertTrue(UserDefaults.standard.bool(forKey: Migration_v3_WatchSeries3Capacity.coreDataKey))
    try Migration_v3_WatchSeries3Capacity.migrate(viewContext: context)
    assertPreserved(saved.toBatteryRecord(), first, capacity: 352)

    // An older replica/import arrives after the initial completion flag.
    let late = fixture(name: "Apple Watch 3 (38mm) Cellular", capacity: 262)
    let lateSaved = CDBatteryRecord.from(late, context: context)
    let custom = fixture(capacity: 300)
    let customSaved = CDBatteryRecord.from(custom, context: context)
    try context.save()
    XCTAssertTrue(
      Migration_v3_WatchSeries3Capacity.repairIfNeeded(
        [saved, lateSaved, customSaved], in: context))
    context.refreshAllObjects()
    assertPreserved(lateSaved.toBatteryRecord(), late, capacity: 279)
    assertPreserved(customSaved.toBatteryRecord(), custom, capacity: 300)
    XCTAssertEqual(
      try context.count(for: NSFetchRequest<CDBatteryRecord>(entityName: "CDBatteryRecord")), 3)
  }

  @available(iOS 17, *)
  func testSwiftDataUpgradeAndLateArrival() throws {
    let schema = Schema(versionedSchema: CurrentBatterySchema.self)
    let configuration = ModelConfiguration(
      schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let context = container.mainContext
    let first = fixture()
    let saved = CurrentBatterySchema.BatteryRecord(from: first)
    context.insert(saved)
    try context.save()
    let oldFlag = UserDefaults.standard.object(
      forKey: Migration_v3_WatchSeries3Capacity.swiftDataKey)
    defer {
      UserDefaults.standard.set(oldFlag, forKey: Migration_v3_WatchSeries3Capacity.swiftDataKey)
    }
    try Migration_v3_WatchSeries3Capacity.migrate(modelContext: context)
    assertPreserved(saved.toBatteryRecord(), first, capacity: 352)
    XCTAssertTrue(
      UserDefaults.standard.bool(forKey: Migration_v3_WatchSeries3Capacity.swiftDataKey))
    try Migration_v3_WatchSeries3Capacity.migrate(modelContext: context)
    assertPreserved(saved.toBatteryRecord(), first, capacity: 352)

    let late = fixture(name: "Apple Watch 3 (38mm) Cellular", capacity: 262)
    let lateSaved = CurrentBatterySchema.BatteryRecord(from: late)
    context.insert(lateSaved)
    let custom = fixture(capacity: 300)
    let customSaved = CurrentBatterySchema.BatteryRecord(from: custom)
    context.insert(customSaved)
    try context.save()
    XCTAssertTrue(
      Migration_v3_WatchSeries3Capacity.repairIfNeeded(
        [saved, lateSaved, customSaved], in: context))
    assertPreserved(lateSaved.toBatteryRecord(), late, capacity: 279)
    assertPreserved(customSaved.toBatteryRecord(), custom, capacity: 300)
    XCTAssertEqual(try context.fetchCount(FetchDescriptor<CurrentBatterySchema.BatteryRecord>()), 3)
  }

  func testFailedCoreDataSaveRollsBackAndCanRetry() throws {
    let model = CoreDataStore.createManagedObjectModel()
    // Make the corrected value fail model validation, exercising the real
    // transaction rollback rather than a mock of context.save().
    let capacity = model.entitiesByName["CDBatteryRecord"]!.attributesByName["designCapacity"]!
    capacity.setValidationPredicates(
      [NSPredicate(format: "SELF <= 300")], withValidationWarnings: ["Injected test failure"])
    let container = NSPersistentContainer(name: "FailureTest", managedObjectModel: model)
    let description = NSPersistentStoreDescription()
    description.type = NSInMemoryStoreType
    container.persistentStoreDescriptions = [description]
    var loadError: Error?
    container.loadPersistentStores { _, error in loadError = error }
    if let loadError { throw loadError }
    let context = container.viewContext
    let original = fixture()
    let saved = CDBatteryRecord.from(original, context: context)
    try context.save()
    XCTAssertFalse(Migration_v3_WatchSeries3Capacity.repairIfNeeded([saved], in: context))
    assertPreserved(saved.toBatteryRecord(), original, capacity: 279)
    XCTAssertFalse(context.hasChanges)
    let oldFlag = UserDefaults.standard.object(
      forKey: Migration_v3_WatchSeries3Capacity.coreDataKey)
    defer {
      UserDefaults.standard.set(oldFlag, forKey: Migration_v3_WatchSeries3Capacity.coreDataKey)
    }
    UserDefaults.standard.removeObject(forKey: Migration_v3_WatchSeries3Capacity.coreDataKey)
    XCTAssertThrowsError(try Migration_v3_WatchSeries3Capacity.migrate(viewContext: context))
    XCTAssertFalse(
      UserDefaults.standard.bool(forKey: Migration_v3_WatchSeries3Capacity.coreDataKey))
    assertPreserved(saved.toBatteryRecord(), original, capacity: 279)
  }
}
