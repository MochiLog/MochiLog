import CoreData
import SwiftData
import XCTest

@testable import MochiLog

@MainActor
final class IPadCapacityMigrationTests: XCTestCase {
  private let corrections: [(String, Int, Int)] = [
    ("iPad Pro 13 (M5)", 10340, 10209), ("iPad Pro 13 (M4)", 10340, 10209),
    ("iPad Pro 11 (M5)", 8340, 8160), ("iPad Pro 11 (M4)", 8340, 8160),
    ("iPad mini (A17 Pro)", 5124, 5034), ("iPad (A16)", 7698, 7606),
    ("iPad Air 13 (M4)", 9705, 9720), ("iPad Air 13 (M3)", 9705, 9720),
  ]

  private func fixture(name: String, capacity: Int, rawCapacity: Int = 7500) -> BatteryRecord {
    BatteryRecord(
      logDate: Date(timeIntervalSince1970: 1_700_000_000),
      deviceName: name, deviceModelCode: DeviceLibrary.getFirstIdentifier(for: name),
      osVersion: "iPadOS 27.0", productSku: "J/A", physicalDeviceID: UUID(),
      storage: "256 GB", ram: "8 GB", manufactureDate: "2024-04",
      firstUseDate: Date(timeIntervalSince1970: 1_690_000_000), cycleCount: 432,
      designCapacity: capacity, nominalCapacity: 7600, rawCapacity: rawCapacity,
      lowRateCapacity: 7400, deflator: 103.8, settingsDisplayPercent: 95,
      diagnosticResult: "Saved diagnosis", avgTemp: 24.5, maxTemp: 30.1, minTemp: 18.9,
      maxVoltage: 4.35, minVoltage: 3.6, minSoC: 20, maxSoC: 100)
  }

  private func assertPreserved(_ result: BatteryRecord, _ original: BatteryRecord, capacity: Int) {
    XCTAssertEqual(result.designCapacity, capacity)
    XCTAssertEqual(result.id, original.id)
    XCTAssertEqual(result.physicalDeviceID, original.physicalDeviceID)
    XCTAssertEqual(result.logDate, original.logDate)
    XCTAssertEqual(result.deviceName, original.deviceName)
    XCTAssertEqual(result.deviceModelCode, original.deviceModelCode)
    XCTAssertEqual(result.osVersion, original.osVersion)
    XCTAssertEqual(result.productSku, original.productSku)
    XCTAssertEqual(result.storage, original.storage)
    XCTAssertEqual(result.ram, original.ram)
    XCTAssertEqual(result.manufactureDate, original.manufactureDate)
    XCTAssertEqual(result.firstUseDate, original.firstUseDate)
    XCTAssertEqual(result.rawCapacity, original.rawCapacity)
    XCTAssertEqual(result.nominalCapacity, original.nominalCapacity)
    XCTAssertEqual(result.lowRateCapacity, original.lowRateCapacity)
    XCTAssertEqual(result.cycleCount, original.cycleCount)
    XCTAssertEqual(result.deflator, original.deflator)
    XCTAssertEqual(result.settingsDisplayPercent, original.settingsDisplayPercent)
    XCTAssertEqual(result.avgTemp, original.avgTemp)
    XCTAssertEqual(result.maxTemp, original.maxTemp)
    XCTAssertEqual(result.minTemp, original.minTemp)
    XCTAssertEqual(result.maxVoltage, original.maxVoltage)
    XCTAssertEqual(result.minVoltage, original.minVoltage)
    XCTAssertEqual(result.minSoC, original.minSoC)
    XCTAssertEqual(result.maxSoC, original.maxSoC)
    let expectedDiagnosis =
      capacity != original.designCapacity && original.rawCapacity > 0
      ? DeviceLibraryMigrations.diagnostic(
        rawCapacity: original.rawCapacity, designCapacity: capacity)
      : original.diagnosticResult
    XCTAssertEqual(result.diagnosticResult, expectedDiagnosis)
  }

  private func coreDataContainer(model: NSManagedObjectModel? = nil) throws -> NSPersistentContainer
  {
    let container = NSPersistentContainer(
      name: "IPadCapacityMigrationTests",
      managedObjectModel: model ?? CoreDataStore.createManagedObjectModel())
    let description = NSPersistentStoreDescription()
    description.type = NSInMemoryStoreType
    container.persistentStoreDescriptions = [description]
    var failure: Error?
    container.loadPersistentStores { _, error in failure = error }
    if let failure { throw failure }
    return container
  }

  func testCoreDataUpgradeRepeatedPassesAndOldCloudReplica() throws {
    let container = try coreDataContainer()
    let context = container.viewContext
    let originals = corrections.map { fixture(name: $0.0, capacity: $0.1) }
    let records = originals.map { CDBatteryRecord.from($0, context: context) }
    try context.save()
    let key = Migration_v5_iPadReferenceCapacity.coreDataKey
    let previousFlag = UserDefaults.standard.object(forKey: key)
    defer { UserDefaults.standard.set(previousFlag, forKey: key) }
    UserDefaults.standard.removeObject(forKey: key)
    try DeviceLibraryMigrations.runPending(in: context)
    XCTAssertTrue(UserDefaults.standard.bool(forKey: key))
    for (index, record) in records.enumerated() {
      assertPreserved(record.toBatteryRecord(), originals[index], capacity: corrections[index].2)
      XCTAssertEqual(record.createdAt, originals[index].createdAt)
    }
    XCTAssertTrue(DeviceLibraryMigrations.repairIfNeeded(records, in: context))
    XCTAssertFalse(context.hasChanges, "Already corrected records must not be saved again")

    // An old replica can overwrite the field after the completion flag is set.
    records[0].designCapacity = Int64(corrections[0].1)
    let late = fixture(name: "iPad Pro 11 (M4)", capacity: 8340)
    let lateSaved = CDBatteryRecord.from(late, context: context)
    let custom = fixture(name: "iPad Pro 11 (M4)", capacity: 9000)
    let customSaved = CDBatteryRecord.from(custom, context: context)
    try context.save()
    XCTAssertTrue(
      DeviceLibraryMigrations.repairIfNeeded(records + [lateSaved, customSaved], in: context))
    assertPreserved(records[0].toBatteryRecord(), originals[0], capacity: corrections[0].2)
    assertPreserved(lateSaved.toBatteryRecord(), late, capacity: 8160)
    XCTAssertEqual(lateSaved.createdAt, late.createdAt)
    assertPreserved(customSaved.toBatteryRecord(), custom, capacity: 9000)
    XCTAssertTrue(
      DeviceLibraryMigrations.repairIfNeeded(records + [lateSaved, customSaved], in: context))
    XCTAssertFalse(context.hasChanges)
    XCTAssertEqual(
      try context.count(for: NSFetchRequest<CDBatteryRecord>(entityName: "CDBatteryRecord")), 10)
  }

  @available(iOS 17, *)
  func testSwiftDataUpgradeRepeatedPassesAndOldCloudReplica() throws {
    let schema = Schema(versionedSchema: CurrentBatterySchema.self)
    let configuration = ModelConfiguration(
      schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let context = container.mainContext
    let originals = corrections.map { fixture(name: $0.0, capacity: $0.1) }
    let records = originals.map { CurrentBatterySchema.BatteryRecord(from: $0) }
    records.forEach { context.insert($0) }
    try context.save()
    let key = Migration_v5_iPadReferenceCapacity.swiftDataKey
    let previousFlag = UserDefaults.standard.object(forKey: key)
    defer { UserDefaults.standard.set(previousFlag, forKey: key) }
    UserDefaults.standard.removeObject(forKey: key)
    try DeviceLibraryMigrations.runPending(in: context)
    XCTAssertTrue(UserDefaults.standard.bool(forKey: key))
    for (index, record) in records.enumerated() {
      assertPreserved(record.toBatteryRecord(), originals[index], capacity: corrections[index].2)
      XCTAssertEqual(record.createdAt, originals[index].createdAt)
    }
    XCTAssertTrue(DeviceLibraryMigrations.repairIfNeeded(records, in: context))
    XCTAssertFalse(context.hasChanges)

    records[0].designCapacity = corrections[0].1
    let late = fixture(name: "iPad Pro 11 (M4)", capacity: 8340)
    let lateSaved = CurrentBatterySchema.BatteryRecord(from: late)
    context.insert(lateSaved)
    let custom = fixture(name: "iPad Pro 11 (M4)", capacity: 9000)
    let customSaved = CurrentBatterySchema.BatteryRecord(from: custom)
    context.insert(customSaved)
    try context.save()
    XCTAssertTrue(
      DeviceLibraryMigrations.repairIfNeeded(records + [lateSaved, customSaved], in: context))
    assertPreserved(records[0].toBatteryRecord(), originals[0], capacity: corrections[0].2)
    assertPreserved(lateSaved.toBatteryRecord(), late, capacity: 8160)
    XCTAssertEqual(lateSaved.createdAt, late.createdAt)
    assertPreserved(customSaved.toBatteryRecord(), custom, capacity: 9000)
    XCTAssertTrue(
      DeviceLibraryMigrations.repairIfNeeded(records + [lateSaved, customSaved], in: context))
    XCTAssertFalse(context.hasChanges)
    XCTAssertEqual(
      try context.fetchCount(FetchDescriptor<CurrentBatterySchema.BatteryRecord>()), 10)
  }

  func testCoreDataSaveFailureRollsBackWithoutCompletingAndCanRetry() throws {
    let model = CoreDataStore.createManagedObjectModel()
    let capacity = model.entitiesByName["CDBatteryRecord"]!.attributesByName["designCapacity"]!
    capacity.setValidationPredicates(
      [NSPredicate(format: "SELF != 8160")],
      withValidationWarnings: ["Injected iPad migration failure"])
    let container = try coreDataContainer(model: model)
    let context = container.viewContext
    let original = fixture(name: "iPad Pro 11 (M4)", capacity: 8340)
    let saved = CDBatteryRecord.from(original, context: context)
    try context.save()
    let key = Migration_v5_iPadReferenceCapacity.coreDataKey
    let previousFlag = UserDefaults.standard.object(forKey: key)
    defer { UserDefaults.standard.set(previousFlag, forKey: key) }
    UserDefaults.standard.removeObject(forKey: key)
    XCTAssertThrowsError(try Migration_v5_iPadReferenceCapacity.migrate(viewContext: context))
    assertPreserved(saved.toBatteryRecord(), original, capacity: 8340)
    XCTAssertFalse(context.hasChanges)
    XCTAssertFalse(UserDefaults.standard.bool(forKey: key))

    let retry = try coreDataContainer()
    let retried = CDBatteryRecord.from(original, context: retry.viewContext)
    try retry.viewContext.save()
    try Migration_v5_iPadReferenceCapacity.migrate(viewContext: retry.viewContext)
    assertPreserved(retried.toBatteryRecord(), original, capacity: 8160)
    XCTAssertTrue(UserDefaults.standard.bool(forKey: key))
  }

  func testNoRawMeasurementRetainsExistingDiagnosis() throws {
    let container = try coreDataContainer()
    let original = fixture(name: "iPad Pro 11 (M4)", capacity: 8340, rawCapacity: 0)
    let saved = CDBatteryRecord.from(original, context: container.viewContext)
    try container.viewContext.save()
    XCTAssertTrue(
      Migration_v5_iPadReferenceCapacity.repairIfNeeded([saved], in: container.viewContext))
    assertPreserved(saved.toBatteryRecord(), original, capacity: 8160)
    XCTAssertEqual(saved.diagnosticResult, original.diagnosticResult)
  }
}
