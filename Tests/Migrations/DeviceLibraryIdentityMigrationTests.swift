import CoreData
import SwiftData
import XCTest

@testable import MochiLog

@MainActor
final class DeviceLibraryIdentityMigrationTests: XCTestCase {
  private func fixture() -> BatteryRecord {
    BatteryRecord(
      logDate: Date(timeIntervalSince1970: 1_700_000_000),
      deviceName: "Apple Watch 8 (41mm)", deviceModelCode: "Watch6,10",
      osVersion: "watchOS 26.0", productSku: "J/A", physicalDeviceID: UUID(),
      storage: "32 GB", ram: "1 GB",
      manufactureDate: "2022-08", firstUseDate: Date(timeIntervalSince1970: 1_660_000_000),
      cycleCount: 321, designCapacity: 282, nominalCapacity: 270, rawCapacity: 260,
      lowRateCapacity: 265, deflator: 103.8, settingsDisplayPercent: 95,
      diagnosticResult: "Saved diagnosis", avgTemp: 24.5, maxTemp: 30.1, minTemp: 18.9,
      maxVoltage: 4.35, minVoltage: 3.6, minSoC: 20, maxSoC: 100)
  }

  private func assertPreserved(_ result: BatteryRecord, _ original: BatteryRecord) {
    XCTAssertEqual(result.deviceModelCode, "Watch6,14")
    XCTAssertEqual(result.deviceName, original.deviceName)
    XCTAssertEqual(result.id, original.id)
    XCTAssertEqual(result.physicalDeviceID, original.physicalDeviceID)
    XCTAssertEqual(result.logDate, original.logDate)
    XCTAssertEqual(result.osVersion, original.osVersion)
    XCTAssertEqual(result.productSku, original.productSku)
    XCTAssertEqual(result.storage, original.storage)
    XCTAssertEqual(result.ram, original.ram)
    XCTAssertEqual(result.manufactureDate, original.manufactureDate)
    XCTAssertEqual(result.firstUseDate, original.firstUseDate)
    XCTAssertEqual(result.designCapacity, original.designCapacity)
    XCTAssertEqual(result.rawCapacity, original.rawCapacity)
    XCTAssertEqual(result.nominalCapacity, original.nominalCapacity)
    XCTAssertEqual(result.lowRateCapacity, original.lowRateCapacity)
    XCTAssertEqual(result.cycleCount, original.cycleCount)
    XCTAssertEqual(result.deflator, original.deflator)
    XCTAssertEqual(result.settingsDisplayPercent, original.settingsDisplayPercent)
    XCTAssertEqual(result.diagnosticResult, original.diagnosticResult)
    XCTAssertEqual(result.avgTemp, original.avgTemp)
    XCTAssertEqual(result.maxTemp, original.maxTemp)
    XCTAssertEqual(result.minTemp, original.minTemp)
    XCTAssertEqual(result.maxVoltage, original.maxVoltage)
    XCTAssertEqual(result.minVoltage, original.minVoltage)
    XCTAssertEqual(result.minSoC, original.minSoC)
    XCTAssertEqual(result.maxSoC, original.maxSoC)
  }

  private func coreDataContainer(model: NSManagedObjectModel? = nil) throws
    -> NSPersistentContainer
  {
    let container = NSPersistentContainer(
      name: "IdentityMigrationTests",
      managedObjectModel: model ?? CoreDataStore.createManagedObjectModel())
    let description = NSPersistentStoreDescription()
    description.type = NSInMemoryStoreType
    container.persistentStoreDescriptions = [description]
    var failure: Error?
    container.loadPersistentStores { _, error in failure = error }
    if let failure { throw failure }
    return container
  }

  func testCoreDataMigrationRepeatAndLateReplicaPreserveAllValues() throws {
    let container = try coreDataContainer()
    let context = container.viewContext
    let original = fixture()
    let saved = CDBatteryRecord.from(original, context: context)
    try context.save()
    let key = Migration_v4_DeviceLibraryIdentity.coreDataKey
    let previousFlag = UserDefaults.standard.object(forKey: key)
    defer { UserDefaults.standard.set(previousFlag, forKey: key) }
    try Migration_v4_DeviceLibraryIdentity.migrate(viewContext: context)
    assertPreserved(saved.toBatteryRecord(), original)
    XCTAssertFalse(context.hasChanges, "The initial correction must be persisted")
    XCTAssertTrue(DeviceLibraryMigrations.repairIfNeeded([saved], in: context))
    XCTAssertFalse(context.hasChanges, "The normal refresh path must also be a no-op")
    XCTAssertEqual(saved.createdAt, original.createdAt)
    XCTAssertTrue(UserDefaults.standard.bool(forKey: key))
    try Migration_v4_DeviceLibraryIdentity.migrate(viewContext: context)
    assertPreserved(saved.toBatteryRecord(), original)
    XCTAssertFalse(context.hasChanges, "The second migration must be a no-op")

    // An older device sends the old field after the initial completion flag.
    saved.deviceModelCode = original.deviceModelCode
    let late = fixture()
    let lateSaved = CDBatteryRecord.from(late, context: context)
    try context.save()
    XCTAssertTrue(DeviceLibraryMigrations.repairIfNeeded([saved, lateSaved], in: context))
    context.refreshAllObjects()
    assertPreserved(saved.toBatteryRecord(), original)
    assertPreserved(lateSaved.toBatteryRecord(), late)
    XCTAssertTrue(DeviceLibraryMigrations.repairIfNeeded([saved, lateSaved], in: context))
    XCTAssertFalse(context.hasChanges, "Repaired late arrivals must not trigger another rewrite")
    XCTAssertEqual(
      try context.count(for: NSFetchRequest<CDBatteryRecord>(entityName: "CDBatteryRecord")), 2)
  }

  @available(iOS 17, *)
  func testSwiftDataMigrationRepeatAndLateReplicaPreserveAllValues() throws {
    let schema = Schema(versionedSchema: CurrentBatterySchema.self)
    let configuration = ModelConfiguration(
      schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let context = container.mainContext
    let original = fixture()
    let saved = CurrentBatterySchema.BatteryRecord(from: original)
    context.insert(saved)
    try context.save()
    let key = Migration_v4_DeviceLibraryIdentity.swiftDataKey
    let previousFlag = UserDefaults.standard.object(forKey: key)
    defer { UserDefaults.standard.set(previousFlag, forKey: key) }
    try Migration_v4_DeviceLibraryIdentity.migrate(modelContext: context)
    assertPreserved(saved.toBatteryRecord(), original)
    XCTAssertFalse(context.hasChanges, "The initial correction must be persisted")
    XCTAssertTrue(DeviceLibraryMigrations.repairIfNeeded([saved], in: context))
    XCTAssertFalse(context.hasChanges, "The normal refresh path must also be a no-op")
    XCTAssertEqual(saved.createdAt, original.createdAt)
    XCTAssertTrue(UserDefaults.standard.bool(forKey: key))
    try Migration_v4_DeviceLibraryIdentity.migrate(modelContext: context)
    assertPreserved(saved.toBatteryRecord(), original)
    XCTAssertFalse(context.hasChanges, "The second migration must be a no-op")

    saved.deviceModelCode = original.deviceModelCode
    let late = fixture()
    let lateSaved = CurrentBatterySchema.BatteryRecord(from: late)
    context.insert(lateSaved)
    try context.save()
    XCTAssertTrue(DeviceLibraryMigrations.repairIfNeeded([saved, lateSaved], in: context))
    assertPreserved(saved.toBatteryRecord(), original)
    assertPreserved(lateSaved.toBatteryRecord(), late)
    XCTAssertTrue(DeviceLibraryMigrations.repairIfNeeded([saved, lateSaved], in: context))
    XCTAssertFalse(context.hasChanges, "Repaired late arrivals must not trigger another rewrite")
    XCTAssertEqual(try context.fetchCount(FetchDescriptor<CurrentBatterySchema.BatteryRecord>()), 2)
  }

  func testCoreDataSaveFailureDoesNotCompleteMigrationAndCanRetry() throws {
    let model = CoreDataStore.createManagedObjectModel()
    let code = model.entitiesByName["CDBatteryRecord"]!.attributesByName["deviceModelCode"]!
    code.setValidationPredicates(
      [NSPredicate(format: "SELF != %@", "Watch6,14")],
      withValidationWarnings: ["Injected identity migration save failure"])
    let container = try coreDataContainer(model: model)
    let context = container.viewContext
    let original = fixture()
    let saved = CDBatteryRecord.from(original, context: context)
    try context.save()
    let key = Migration_v4_DeviceLibraryIdentity.coreDataKey
    let previousFlag = UserDefaults.standard.object(forKey: key)
    defer { UserDefaults.standard.set(previousFlag, forKey: key) }
    UserDefaults.standard.removeObject(forKey: key)
    XCTAssertThrowsError(try Migration_v4_DeviceLibraryIdentity.migrate(viewContext: context))
    XCTAssertEqual(saved.deviceModelCode, original.deviceModelCode)
    XCTAssertEqual(saved.designCapacity, Int64(original.designCapacity))
    XCTAssertEqual(saved.recordID, original.id)
    XCTAssertFalse(context.hasChanges)
    XCTAssertFalse(UserDefaults.standard.bool(forKey: key))

    // A later launch with a writable/valid store can retry because the failed
    // transaction never wrote the completion flag. Loaded models are immutable.
    let retryContainer = try coreDataContainer()
    let retryContext = retryContainer.viewContext
    let retried = CDBatteryRecord.from(saved.toBatteryRecord(), context: retryContext)
    try retryContext.save()
    try Migration_v4_DeviceLibraryIdentity.migrate(viewContext: retryContext)
    assertPreserved(retried.toBatteryRecord(), original)
    XCTAssertTrue(UserDefaults.standard.bool(forKey: key))
  }
}
