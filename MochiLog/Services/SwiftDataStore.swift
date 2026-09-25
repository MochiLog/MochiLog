import Foundation
import SwiftData

// MARK: - SwiftData スキーマ定義（VersionedSchema でエンティティ名 "BatteryRecord" を維持）

@available(iOS 17, *)
enum CurrentBatterySchema: VersionedSchema {
  static var versionIdentifier = Schema.Version(1, 0, 0)
  static var models: [any PersistentModel.Type] { [BatteryRecord.self] }

  @Model
  final class BatteryRecord {
    var recordID: UUID?  // Optional: 旧レコードには存在しない
    var logDate: Date = Date()
    var deviceName: String = "Unknown"
    var deviceModelCode: String?
    var osVersion: String?
    var productSku: String?
    var physicalDeviceID: UUID?
    var storage: String?
    var ram: String?
    var manufactureDate: String?
    var firstUseDate: Date?
    var cycleCount: Int = 0
    var designCapacity: Int = 0
    var nominalCapacity: Int = 0
    var rawCapacity: Int = 0
    var lowRateCapacity: Int?
    var deflator: Double?
    var settingsDisplayPercent: Int?
    var diagnosticResult: String?
    var avgTemp: Double?
    var maxTemp: Double?
    var minTemp: Double?
    var maxVoltage: Double?
    var minVoltage: Double?
    var minSoC: Int?
    var maxSoC: Int?
    var createdAt: Date = Date()

    init() {}

    /// プレーン BatteryRecord から SwiftData モデルを生成
    convenience init(from record: MochiLog.BatteryRecord) {
      self.init()
      self.recordID = record.id
      self.logDate = record.logDate
      self.deviceName = record.deviceName
      self.deviceModelCode = record.deviceModelCode
      self.osVersion = record.osVersion
      self.productSku = record.productSku
      self.physicalDeviceID = record.physicalDeviceID
      self.storage = record.storage
      self.ram = record.ram
      self.manufactureDate = record.manufactureDate
      self.firstUseDate = record.firstUseDate
      self.cycleCount = record.cycleCount
      self.designCapacity = record.designCapacity
      self.nominalCapacity = record.nominalCapacity
      self.rawCapacity = record.rawCapacity
      self.lowRateCapacity = record.lowRateCapacity
      self.deflator = record.deflator
      self.settingsDisplayPercent = record.settingsDisplayPercent
      self.diagnosticResult = record.diagnosticResult
      self.avgTemp = record.avgTemp
      self.maxTemp = record.maxTemp
      self.minTemp = record.minTemp
      self.maxVoltage = record.maxVoltage
      self.minVoltage = record.minVoltage
      self.minSoC = record.minSoC
      self.maxSoC = record.maxSoC
      self.createdAt = record.createdAt
    }

    /// SwiftData モデル → プレーン BatteryRecord 変換
    func toBatteryRecord() -> MochiLog.BatteryRecord {
      // recordID が nil (旧データ) の場合は UUID を生成して保持
      if recordID == nil {
        recordID = UUID()
      }
      return MochiLog.BatteryRecord(
        id: recordID!,
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
        cycleCount: cycleCount,
        designCapacity: designCapacity,
        nominalCapacity: nominalCapacity,
        rawCapacity: rawCapacity,
        lowRateCapacity: lowRateCapacity,
        deflator: deflator,
        settingsDisplayPercent: settingsDisplayPercent,
        diagnosticResult: diagnosticResult,
        avgTemp: avgTemp,
        maxTemp: maxTemp,
        minTemp: minTemp,
        maxVoltage: maxVoltage,
        minVoltage: minVoltage,
        minSoC: minSoC,
        maxSoC: maxSoC
      )
    }

    /// BatteryRecord の変更を反映
    func update(from record: MochiLog.BatteryRecord) {
      self.logDate = record.logDate
      self.deviceName = record.deviceName
      self.deviceModelCode = record.deviceModelCode
      self.osVersion = record.osVersion
      self.productSku = record.productSku
      self.physicalDeviceID = record.physicalDeviceID
      self.storage = record.storage
      self.ram = record.ram
      self.manufactureDate = record.manufactureDate
      self.firstUseDate = record.firstUseDate
      self.cycleCount = record.cycleCount
      self.designCapacity = record.designCapacity
      self.nominalCapacity = record.nominalCapacity
      self.rawCapacity = record.rawCapacity
      self.lowRateCapacity = record.lowRateCapacity
      self.deflator = record.deflator
      self.settingsDisplayPercent = record.settingsDisplayPercent
      self.diagnosticResult = record.diagnosticResult
      self.avgTemp = record.avgTemp
      self.maxTemp = record.maxTemp
      self.minTemp = record.minTemp
      self.maxVoltage = record.maxVoltage
      self.minVoltage = record.minVoltage
      self.minSoC = record.minSoC
      self.maxSoC = record.maxSoC
    }
  }
}

// MARK: - SwiftDataStore

@available(iOS 17, *)
final class SwiftDataStore: DataStore {
  /// VersionedSchema内のBatteryRecord型への便利エイリアス
  private typealias SDBatteryRecord = CurrentBatterySchema.BatteryRecord

  private let modelContainer: ModelContainer
  private let modelContext: ModelContext

  private struct ImportFingerprint: Hashable {
    let deviceID: UUID
    let logSecond: Int64
    let model: String?
    let cycles: Int
    let nominal: Int
    let raw: Int
  }

  init(iCloudEnabled: Bool) {
    let schema = Schema(versionedSchema: CurrentBatterySchema.self)
    let config: ModelConfiguration

    if iCloudEnabled {
      config = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false
      )
    } else {
      config = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .none
      )
    }

    do {
      modelContainer = try ModelContainer(for: schema, configurations: [config])
    } catch {
      fatalError("SwiftData ModelContainer の作成に失敗: \(error)")
    }
    modelContext = modelContainer.mainContext

    super.init(isICloudEnabled: iCloudEnabled)
    refreshRecords()
  }

  /// インメモリ用（Preview / テスト）
  init(inMemory: Bool) {
    let schema = Schema(versionedSchema: CurrentBatterySchema.self)
    let config = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: true
    )
    do {
      modelContainer = try ModelContainer(for: schema, configurations: [config])
    } catch {
      fatalError("SwiftData ModelContainer (inMemory) の作成に失敗: \(error)")
    }
    modelContext = modelContainer.mainContext
    super.init(isICloudEnabled: false)
  }

  // MARK: - CRUD

  override func insert(_ record: BatteryRecord) {
    let sdRecord = SDBatteryRecord(from: record)
    modelContext.insert(sdRecord)
  }

  override func delete(_ record: BatteryRecord) {
    let targetID = record.id
    // recordID is Optional<UUID>, compare with Optional value
    let optionalTargetID: UUID? = targetID
    let descriptor = FetchDescriptor<SDBatteryRecord>(
      predicate: #Predicate { $0.recordID == optionalTargetID }
    )
    if let sdRecord = try? modelContext.fetch(descriptor).first {
      modelContext.delete(sdRecord)
    } else {
      // Fallback: recordIDが未保存の旧レコードをlogDate+deviceNameで検索
      let logDate = record.logDate
      let deviceName = record.deviceName
      let fallbackDescriptor = FetchDescriptor<SDBatteryRecord>(
        predicate: #Predicate { $0.logDate == logDate && $0.deviceName == deviceName }
      )
      if let sdRecord = try? modelContext.fetch(fallbackDescriptor).first {
        modelContext.delete(sdRecord)
      }
    }
  }

  override func deleteAll() {
    let descriptor = FetchDescriptor<SDBatteryRecord>()
    guard let all = try? modelContext.fetch(descriptor) else { return }
    for record in all {
      modelContext.delete(record)
    }
    do {
      try modelContext.save()
    } catch {
      print("[SwiftDataStore] Save failed in deleteAll (conflict?): \(error)")
      ICloudSyncManager.shared.handleSaveError(error)
      modelContext.rollback()
    }
    refreshRecords()
  }

  override func deleteRecords(for deviceName: String) {
    let descriptor = FetchDescriptor<SDBatteryRecord>(
      predicate: #Predicate { $0.deviceName == deviceName }
    )
    guard let records = try? modelContext.fetch(descriptor) else { return }
    for record in records {
      modelContext.delete(record)
    }
    do {
      try modelContext.save()
    } catch {
      print("[SwiftDataStore] Save failed in deleteRecords (conflict?): \(error)")
      ICloudSyncManager.shared.handleSaveError(error)
      modelContext.rollback()
    }
    refreshRecords()
  }

  override func save() {
    do {
      try modelContext.save()
    } catch {
      print("[SwiftDataStore] Save failed (conflict?): \(error)")
      ICloudSyncManager.shared.handleSaveError(error)
      // コンフリクト等のエラーでcontextがdirtyな状態のままになり、以降の保存・同期が停止するのを防ぐためrollbackする
      modelContext.rollback()
    }
    refreshRecords()
  }

  override func saveChanges() throws {
    do {
      try modelContext.save()
      refreshRecords()
    } catch {
      modelContext.rollback()
      refreshRecords()
      ICloudSyncManager.shared.handleSaveError(error)
      throw error
    }
  }

  override func reassignPhysicalDeviceID(from oldID: UUID, to newID: UUID,
    matchingModelCode: String) throws -> Int {
    let all = try modelContext.fetch(FetchDescriptor<SDBatteryRecord>())
    let matches = all.filter {
      $0.physicalDeviceID == oldID && $0.deviceModelCode == matchingModelCode
    }
    for record in matches { record.physicalDeviceID = newID }
    do { try modelContext.save() }
    catch {
      modelContext.rollback()
      refreshRecords()
      throw error
    }
    refreshRecords()
    return matches.count
  }

  override func fetchRecords(for deviceName: String, ascending: Bool = true) -> [BatteryRecord] {
    let descriptor = FetchDescriptor<SDBatteryRecord>(
      predicate: #Predicate { $0.deviceName == deviceName },
      sortBy: [SortDescriptor(\.logDate, order: ascending ? .forward : .reverse)]
    )
    let sdRecords = (try? modelContext.fetch(descriptor)) ?? []
    return sdRecords.map { $0.toBatteryRecord() }
  }

  override func applyDeviceProfile(_ profile: DeviceProfile, names: Set<String>, identifiers: Set<String>) throws -> Int {
    let all = try modelContext.fetch(FetchDescriptor<SDBatteryRecord>())
    let matches = all.filter { names.contains($0.deviceName) || identifiers.contains($0.deviceModelCode ?? "") }
    for record in matches {
      record.deviceName = profile.name
      record.designCapacity = profile.capacity
      // Keep existing model identifiers and every measured field unchanged.
    }
    do {
      try modelContext.save()
    } catch {
      modelContext.rollback()
      refreshRecords()
      throw error
    }
    refreshRecords()
    return matches.count
  }

  override func refreshRecords() {
    let descriptor = FetchDescriptor<SDBatteryRecord>(
      sortBy: [SortDescriptor(\.logDate, order: .reverse)]
    )
    var sdRecords = (try? modelContext.fetch(descriptor)) ?? []
    // CloudKit and the Mac can deliver the same source log in either order.
    // Converge only exact, ID-tagged copies; same-model legacy data stays intact.
    var keeper: [ImportFingerprint: SDBatteryRecord] = [:]
    var duplicates: [SDBatteryRecord] = []
    for record in sdRecords {
      guard let deviceID = record.physicalDeviceID else { continue }
      let key = ImportFingerprint(deviceID: deviceID,
        logSecond: Int64(record.logDate.timeIntervalSince1970.rounded()),
        model: record.deviceModelCode, cycles: record.cycleCount,
        nominal: record.nominalCapacity, raw: record.rawCapacity)
      if let existing = keeper[key] {
        let existingID = existing.recordID?.uuidString ?? ""
        let recordID = record.recordID?.uuidString ?? ""
        if recordID < existingID {
          duplicates.append(existing)
          keeper[key] = record
        } else {
          duplicates.append(record)
        }
      } else {
        keeper[key] = record
      }
    }
    if !duplicates.isEmpty {
      for record in duplicates { modelContext.delete(record) }
      do {
        try modelContext.save()
        sdRecords = (try? modelContext.fetch(descriptor)) ?? []
      } catch {
        modelContext.rollback()
        ICloudSyncManager.shared.handleSaveError(error)
        sdRecords = (try? modelContext.fetch(descriptor)) ?? []
      }
    }
    let records = sdRecords.map { $0.toBatteryRecord() }
    // toBatteryRecord() が旧レコードに recordID を付与した場合、変更を保存
    if modelContext.hasChanges {
      do {
        try modelContext.save()
      } catch {
        print("[SwiftDataStore] Save failed in refreshRecords (conflict?): \(error)")
        ICloudSyncManager.shared.handleSaveError(error)
        modelContext.rollback()
      }
    }
    updateCachedRecords(records)
  }

  // MARK: - マイグレーション

  override func runMigrations() {
    // SwiftData用のマイグレーションをModelContext経由で実行
    SwiftDataMigrationRunner.runPendingMigrations(modelContext: modelContext) { [weak self] in
      self?.refreshRecords()
    }
  }

  // MARK: - SwiftData内部マイグレーション

  /// SwiftData向けマイグレーション実行ヘルパー
  struct SwiftDataMigrationRunner {
    private static let migrationKeyPrefix = "Migration_Completed_"

    /// SDBatteryRecord向けマイグレーション（Migration_v1_iPhone16e_AvgTemp と同等のロジック）
    static func runPendingMigrations(modelContext: ModelContext, onComplete: @escaping @MainActor () -> Void = {}) {
      Task { @MainActor in
        runV1Migration(modelContext: modelContext)
        runV2MagSafeMigration(modelContext: modelContext)
        onComplete()
      }
    }

    @MainActor
    private static func runV1Migration(modelContext: ModelContext) {
      let version = "v1_iPhone16e_AvgTemp"
      let key = migrationKeyPrefix + version

      guard !UserDefaults.standard.bool(forKey: key) else { return }

      print("[SwiftDataMigration] Running \(version)...")
      let currentVersion = AppSettings.currentAppVersion
      let previousVersion = UserDefaults.standard.string(forKey: AppSettings.Keys.lastSeenVersion)

      if let currentVersion = currentVersion {
        UserDefaults.standard.set(currentVersion, forKey: AppSettings.Keys.lastSeenVersion)
      }

      let descriptor = FetchDescriptor<SDBatteryRecord>()
      guard let allRecords = try? modelContext.fetch(descriptor) else { return }

      for record in allRecords {
        var needsSave = false

        // avgTemp修正（2.0.0以下からのアップデートのみ）
        if previousVersion == nil
          || (previousVersion != nil && compareVersion(previousVersion!, lessThanOrEqual: "2.0.0"))
        {
          if let avgTemp = record.avgTemp, avgTemp < 10.0 {
            record.avgTemp = avgTemp * 10.0
            needsSave = true
          }
        }

        // iPhone 16e設計容量修正
        if record.deviceName == "iPhone 16e", record.designCapacity == 3961 {
          record.designCapacity = 4005
          needsSave = true
        }

        if needsSave {
          do {
            try modelContext.save()
          } catch {
            print("[SwiftDataMigration] Save failed in v1: \(error)")
            ICloudSyncManager.shared.handleSaveError(error)
            modelContext.rollback()
          }
        }
      }

      UserDefaults.standard.set(true, forKey: key)
      print("[SwiftDataMigration] \(version) completed.")
    }

    @MainActor
    private static func runV2MagSafeMigration(modelContext: ModelContext) {
      let version = "v2_MagSafe_Battery"
      let key = migrationKeyPrefix + version

      guard !UserDefaults.standard.bool(forKey: key) else { return }

      print("[SwiftDataMigration] Running \(version)...")

      let descriptor = FetchDescriptor<SDBatteryRecord>(
        predicate: #Predicate { $0.deviceName == "iPhone Air" }
      )
      guard let airRecords = try? modelContext.fetch(descriptor) else { return }

      var modifiedCount = 0
      for record in airRecords {
        let isMagSafe = record.firstUseDate == nil
          && record.deflator == nil
          && (record.lowRateCapacity == nil || record.lowRateCapacity == 0)
          && record.rawCapacity == 0

        if isMagSafe {
          record.deviceName = "iPhone Air MagSafeバッテリー"
          record.deviceModelCode = "A3385"
          modifiedCount += 1
        }
      }

      if modifiedCount > 0 {
        do {
          try modelContext.save()
          print("[SwiftDataMigration] \(version): Migrated \(modifiedCount) records to MagSafe Battery Pack.")
        } catch {
          print("[SwiftDataMigration] Save failed in \(version): \(error)")
          ICloudSyncManager.shared.handleSaveError(error)
          modelContext.rollback()
        }
      }

      UserDefaults.standard.set(true, forKey: key)
      print("[SwiftDataMigration] \(version) completed.")
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
}
