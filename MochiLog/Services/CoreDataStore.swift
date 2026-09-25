import CoreData
import Foundation

// MARK: - CoreData エンティティ（iOS 16 用）

/// CoreData の NSManagedObject サブクラス
/// プログラマティックにモデルを定義するため .xcdatamodeld は不要
final class CDBatteryRecord: NSManagedObject {
  @NSManaged var recordID: UUID
  @NSManaged var logDate: Date
  @NSManaged var deviceName: String
  @NSManaged var deviceModelCode: String?
  @NSManaged var osVersion: String?
  @NSManaged var productSku: String?
  @NSManaged var physicalDeviceID: UUID?
  @NSManaged var storage: String?
  @NSManaged var ram: String?
  @NSManaged var manufactureDate: String?
  @NSManaged var firstUseDate: Date?
  @NSManaged var cycleCount: Int64
  @NSManaged var designCapacity: Int64
  @NSManaged var nominalCapacity: Int64
  @NSManaged var rawCapacity: Int64
  @NSManaged var lowRateCapacity: NSNumber?
  @NSManaged var deflator: NSNumber?
  @NSManaged var settingsDisplayPercent: NSNumber?
  @NSManaged var diagnosticResult: String?
  @NSManaged var avgTemp: NSNumber?
  @NSManaged var maxTemp: NSNumber?
  @NSManaged var minTemp: NSNumber?
  @NSManaged var maxVoltage: NSNumber?
  @NSManaged var minVoltage: NSNumber?
  @NSManaged var minSoC: NSNumber?
  @NSManaged var maxSoC: NSNumber?
  @NSManaged var createdAt: Date

  /// BatteryRecord から CDBatteryRecord を生成
  static func from(_ record: BatteryRecord, context: NSManagedObjectContext) -> CDBatteryRecord {
    let entity = NSEntityDescription.entity(forEntityName: "CDBatteryRecord", in: context)!
    let cd = CDBatteryRecord(entity: entity, insertInto: context)
    cd.recordID = record.id
    cd.logDate = record.logDate
    cd.deviceName = record.deviceName
    cd.deviceModelCode = record.deviceModelCode
    cd.osVersion = record.osVersion
    cd.productSku = record.productSku
    cd.physicalDeviceID = record.physicalDeviceID
    cd.storage = record.storage
    cd.ram = record.ram
    cd.manufactureDate = record.manufactureDate
    cd.firstUseDate = record.firstUseDate
    cd.cycleCount = Int64(record.cycleCount)
    cd.designCapacity = Int64(record.designCapacity)
    cd.nominalCapacity = Int64(record.nominalCapacity)
    cd.rawCapacity = Int64(record.rawCapacity)
    cd.lowRateCapacity = record.lowRateCapacity.map { NSNumber(value: $0) }
    cd.deflator = record.deflator.map { NSNumber(value: $0) }
    cd.settingsDisplayPercent = record.settingsDisplayPercent.map { NSNumber(value: $0) }
    cd.diagnosticResult = record.diagnosticResult
    cd.avgTemp = record.avgTemp.map { NSNumber(value: $0) }
    cd.maxTemp = record.maxTemp.map { NSNumber(value: $0) }
    cd.minTemp = record.minTemp.map { NSNumber(value: $0) }
    cd.maxVoltage = record.maxVoltage.map { NSNumber(value: $0) }
    cd.minVoltage = record.minVoltage.map { NSNumber(value: $0) }
    cd.minSoC = record.minSoC.map { NSNumber(value: $0) }
    cd.maxSoC = record.maxSoC.map { NSNumber(value: $0) }
    cd.createdAt = record.createdAt
    return cd
  }

  /// CDBatteryRecord → BatteryRecord 変換
  func toBatteryRecord() -> BatteryRecord {
    BatteryRecord(
      id: recordID,
      logDate: logDate,
      deviceName: deviceName,
      deviceModelCode: deviceModelCode,
      osVersion: osVersion,
      productSku: productSku,
      physicalDeviceID: physicalDeviceID,
      storage: storage,
      ram: ram,
      manufactureDate: manufactureDate,
      firstUseDate: firstUseDate,
      cycleCount: Int(cycleCount),
      designCapacity: Int(designCapacity),
      nominalCapacity: Int(nominalCapacity),
      rawCapacity: Int(rawCapacity),
      lowRateCapacity: lowRateCapacity?.intValue,
      deflator: deflator?.doubleValue,
      settingsDisplayPercent: settingsDisplayPercent?.intValue,
      diagnosticResult: diagnosticResult,
      avgTemp: avgTemp?.doubleValue,
      maxTemp: maxTemp?.doubleValue,
      minTemp: minTemp?.doubleValue,
      maxVoltage: maxVoltage?.doubleValue,
      minVoltage: minVoltage?.doubleValue,
      minSoC: minSoC?.intValue,
      maxSoC: maxSoC?.intValue
    )
  }
}

// MARK: - CoreDataStore（iOS 16 用）

final class CoreDataStore: DataStore {
  private let persistentContainer: NSPersistentContainer
  private var viewContext: NSManagedObjectContext {
    persistentContainer.viewContext
  }

  init() {
    // プログラマティックに CoreData モデルを構築
    let model = CoreDataStore.createManagedObjectModel()
    persistentContainer = NSPersistentContainer(name: "MochiLogCoreData", managedObjectModel: model)

    // SQLite ファイルを明示的に指定（SwiftData とは別ファイル）
    let storeURL = CoreDataStore.coreDataStoreURL()
    let description = NSPersistentStoreDescription(url: storeURL)
    description.shouldInferMappingModelAutomatically = true
    description.shouldMigrateStoreAutomatically = true
    persistentContainer.persistentStoreDescriptions = [description]

    super.init(isICloudEnabled: AppSettings.shared.iCloudSyncEnabled)

    persistentContainer.loadPersistentStores { _, error in
      if let error = error {
        print("[CoreDataStore] Failed to load persistent store: \(error)")
      }
    }
    persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
    persistentContainer.viewContext.mergePolicy = NSMergePolicy.error

    refreshRecords()
  }

  // MARK: - モデル定義

  /// CoreData エンティティを動的に構築
  private static func createManagedObjectModel() -> NSManagedObjectModel {
    let model = NSManagedObjectModel()

    let entity = NSEntityDescription()
    entity.name = "CDBatteryRecord"
    entity.managedObjectClassName = NSStringFromClass(CDBatteryRecord.self)

    var attributes: [NSAttributeDescription] = []

    func attr(
      _ name: String, _ type: NSAttributeType, optional: Bool = false, defaultValue: Any? = nil
    ) -> NSAttributeDescription {
      let a = NSAttributeDescription()
      a.name = name
      a.attributeType = type
      a.isOptional = optional
      if let dv = defaultValue { a.defaultValue = dv }
      return a
    }

    attributes.append(attr("recordID", .UUIDAttributeType))
    attributes.append(attr("logDate", .dateAttributeType))
    attributes.append(attr("deviceName", .stringAttributeType, defaultValue: "Unknown"))
    attributes.append(attr("deviceModelCode", .stringAttributeType, optional: true))
    attributes.append(attr("osVersion", .stringAttributeType, optional: true))
    attributes.append(attr("productSku", .stringAttributeType, optional: true))
    attributes.append(attr("physicalDeviceID", .UUIDAttributeType, optional: true))
    attributes.append(attr("storage", .stringAttributeType, optional: true))
    attributes.append(attr("ram", .stringAttributeType, optional: true))
    attributes.append(attr("manufactureDate", .stringAttributeType, optional: true))
    attributes.append(attr("firstUseDate", .dateAttributeType, optional: true))
    attributes.append(attr("cycleCount", .integer64AttributeType, defaultValue: Int64(0)))
    attributes.append(attr("designCapacity", .integer64AttributeType, defaultValue: Int64(0)))
    attributes.append(attr("nominalCapacity", .integer64AttributeType, defaultValue: Int64(0)))
    attributes.append(attr("rawCapacity", .integer64AttributeType, defaultValue: Int64(0)))
    attributes.append(attr("lowRateCapacity", .integer64AttributeType, optional: true))
    attributes.append(attr("deflator", .doubleAttributeType, optional: true))
    attributes.append(attr("settingsDisplayPercent", .integer64AttributeType, optional: true))
    attributes.append(attr("diagnosticResult", .stringAttributeType, optional: true))
    attributes.append(attr("avgTemp", .doubleAttributeType, optional: true))
    attributes.append(attr("maxTemp", .doubleAttributeType, optional: true))
    attributes.append(attr("minTemp", .doubleAttributeType, optional: true))
    attributes.append(attr("maxVoltage", .doubleAttributeType, optional: true))
    attributes.append(attr("minVoltage", .doubleAttributeType, optional: true))
    attributes.append(attr("minSoC", .integer64AttributeType, optional: true))
    attributes.append(attr("maxSoC", .integer64AttributeType, optional: true))
    attributes.append(attr("createdAt", .dateAttributeType))

    entity.properties = attributes
    model.entities = [entity]
    return model
  }

  /// CoreData SQLite ファイルの URL（SwiftData とは別ファイル）
  private static func coreDataStoreURL() -> URL {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
    return appSupport.appendingPathComponent("MochiLogCoreData.sqlite")
  }

  // MARK: - CRUD

  override func insert(_ record: BatteryRecord) {
    _ = CDBatteryRecord.from(record, context: viewContext)
  }

  override func delete(_ record: BatteryRecord) {
    let request = NSFetchRequest<CDBatteryRecord>(entityName: "CDBatteryRecord")
    request.predicate = NSPredicate(format: "recordID == %@", record.id as CVarArg)
    if let results = try? viewContext.fetch(request), let cdRecord = results.first {
      viewContext.delete(cdRecord)
    }
  }

  override func deleteAll() {
    let request = NSFetchRequest<CDBatteryRecord>(entityName: "CDBatteryRecord")
    guard let all = try? viewContext.fetch(request) else { return }
    for record in all {
      viewContext.delete(record)
    }
    do {
      try viewContext.save()
    } catch {
      print("[CoreDataStore] Save failed in deleteAll: \(error)")
      let e = error
      Task { @MainActor in ICloudSyncManager.shared.handleSaveError(e) }
      viewContext.rollback()
    }
    refreshRecords()
  }

  override func deleteRecords(for deviceName: String) {
    let request = NSFetchRequest<CDBatteryRecord>(entityName: "CDBatteryRecord")
    request.predicate = NSPredicate(format: "deviceName == %@", deviceName)
    guard let records = try? viewContext.fetch(request) else { return }
    for record in records {
      viewContext.delete(record)
    }
    do {
      try viewContext.save()
    } catch {
      print("[CoreDataStore] Save failed in deleteRecords: \(error)")
      let e = error
      Task { @MainActor in ICloudSyncManager.shared.handleSaveError(e) }
      viewContext.rollback()
    }
    refreshRecords()
  }

  override func save() {
    do {
      try viewContext.save()
    } catch {
      print("[CoreDataStore] Save failed (conflict?): \(error)")
      let e = error
      Task { @MainActor in ICloudSyncManager.shared.handleSaveError(e) }
      viewContext.rollback()
    }
    refreshRecords()
  }

  override func saveChanges() throws {
    do {
      try viewContext.save()
      refreshRecords()
    } catch {
      viewContext.rollback()
      refreshRecords()
      Task { @MainActor in ICloudSyncManager.shared.handleSaveError(error) }
      throw error
    }
  }

  override func fetchRecords(for deviceName: String, ascending: Bool = true) -> [BatteryRecord] {
    let request = NSFetchRequest<CDBatteryRecord>(entityName: "CDBatteryRecord")
    request.predicate = NSPredicate(format: "deviceName == %@", deviceName)
    request.sortDescriptors = [NSSortDescriptor(key: "logDate", ascending: ascending)]
    let cdRecords = (try? viewContext.fetch(request)) ?? []
    return cdRecords.map { $0.toBatteryRecord() }
  }

  override func applyDeviceProfile(_ profile: DeviceProfile, names: Set<String>, identifiers: Set<String>) throws -> Int {
    let all = try viewContext.fetch(NSFetchRequest<CDBatteryRecord>(entityName: "CDBatteryRecord"))
    let matches = all.filter { names.contains($0.deviceName) || identifiers.contains($0.deviceModelCode ?? "") }
    for record in matches {
      record.deviceName = profile.name
      record.designCapacity = Int64(profile.capacity)
      // Keep existing model identifiers and every measured field unchanged.
    }
    do {
      try viewContext.save()
    } catch {
      viewContext.rollback()
      refreshRecords()
      throw error
    }
    refreshRecords()
    return matches.count
  }

  override func refreshRecords() {
    let request = NSFetchRequest<CDBatteryRecord>(entityName: "CDBatteryRecord")
    request.sortDescriptors = [NSSortDescriptor(key: "logDate", ascending: false)]
    let cdRecords = (try? viewContext.fetch(request)) ?? []
    let records = cdRecords.map { $0.toBatteryRecord() }
    updateCachedRecords(records)
  }

  // MARK: - マイグレーション

  override func runMigrations() {
    CoreDataMigrationRunner.runPendingMigrations(viewContext: viewContext) { [weak self] in
      DispatchQueue.main.async {
        self?.refreshRecords()
      }
    }
  }
}

// MARK: - CoreData内部マイグレーション

struct CoreDataMigrationRunner {
  private static let migrationKeyPrefix = "CoreDataMigration_Completed_"

  static func runPendingMigrations(viewContext: NSManagedObjectContext, onComplete: @escaping () -> Void = {}) {
    Task.detached(priority: .utility) {
      await runAsync(viewContext: viewContext)
      onComplete()
    }
  }

  private static func runAsync(viewContext: NSManagedObjectContext) async {
    await runV2MagSafeMigration(viewContext: viewContext)
  }

  private static func runV2MagSafeMigration(viewContext: NSManagedObjectContext) async {
    let version = "v2_MagSafe_Battery"
    let key = migrationKeyPrefix + version

    guard !UserDefaults.standard.bool(forKey: key) else { return }

    print("[CoreDataMigration] Running \(version)...")

    await viewContext.perform {
      let request = NSFetchRequest<CDBatteryRecord>(entityName: "CDBatteryRecord")
      request.predicate = NSPredicate(format: "deviceName == %@", "iPhone Air")

      guard let airRecords = try? viewContext.fetch(request) else { return }

      var modifiedCount = 0
      for record in airRecords {
        let isMagSafe = record.firstUseDate == nil
          && record.deflator == nil
          && (record.lowRateCapacity == nil || record.lowRateCapacity?.intValue == 0)
          && record.rawCapacity == 0

        if isMagSafe {
          record.deviceName = "iPhone Air MagSafeバッテリー"
          record.deviceModelCode = "A3385"
          modifiedCount += 1
        }
      }

      if modifiedCount > 0 {
        do {
          try viewContext.save()
          print("[CoreDataMigration] \(version): Migrated \(modifiedCount) records to MagSafe Battery Pack.")
        } catch {
          print("[CoreDataMigration] Save failed in \(version): \(error)")
          let e = error
          Task { @MainActor in ICloudSyncManager.shared.handleSaveError(e) }
          viewContext.rollback()
        }
      }

      UserDefaults.standard.set(true, forKey: key)
      print("[CoreDataMigration] \(version) completed.")
    }
  }

  private static func compareVersion(_ version: String, lessThanOrEqual target: String) -> Bool {
    let v1 = version.split(separator: ".").compactMap { Int($0) }
    let v2 = target.split(separator: ".").compactMap { Int($0) }
    let maxCount = max(v1.count, v2.count)
    for i in 0..<maxCount {
      let a = i < v1.count ? v1[i] : 0
      let b = i < v2.count ? v2[i] : 0
      if a < b { return true }
      if a > b { return false }
    }
    return true
  }
}
