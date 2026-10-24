import Foundation
import SwiftData

// MARK: - SwiftData内部マイグレーション

/// SwiftData向けマイグレーション実行ヘルパー
@available(iOS 17, *)
struct SwiftDataMigrationRunner {
  private typealias SDBatteryRecord = CurrentBatterySchema.BatteryRecord
  private static let migrationKeyPrefix = "Migration_Completed_"

  /// SDBatteryRecord向けマイグレーション（Migration_v1_iPhone16e_AvgTemp と同等のロジック）
  static func runPendingMigrations(
    modelContext: ModelContext, onComplete: @escaping @MainActor () -> Void = {}
  ) {
    Task { @MainActor in
      runV1Migration(modelContext: modelContext)
      runV2MagSafeMigration(modelContext: modelContext)
      if !UserDefaults.standard.bool(forKey: Migration_v3_WatchSeries3Capacity.swiftDataKey) {
        do {
          try Migration_v3_WatchSeries3Capacity.migrate(modelContext: modelContext)
        } catch {
          print("[SwiftDataMigration] Watch reference migration failed: \(error)")
        }
      }
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
      let isMagSafe =
        record.firstUseDate == nil
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
        print(
          "[SwiftDataMigration] \(version): Migrated \(modifiedCount) records to MagSafe Battery Pack."
        )
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
