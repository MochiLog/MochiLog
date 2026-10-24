import CoreData
import Foundation

// MARK: - CoreData内部マイグレーション

struct CoreDataMigrationRunner {
  private static let migrationKeyPrefix = "CoreDataMigration_Completed_"

  static func runPendingMigrations(
    viewContext: NSManagedObjectContext, onComplete: @escaping () -> Void = {}
  ) {
    Task.detached(priority: .utility) {
      await runAsync(viewContext: viewContext)
      onComplete()
    }
  }

  private static func runAsync(viewContext: NSManagedObjectContext) async {
    await runV2MagSafeMigration(viewContext: viewContext)
    await viewContext.perform {
      do {
        try DeviceLibraryMigrations.runPending(in: viewContext)
      } catch {
        print("[CoreDataMigration] Device library migration failed: \(error)")
      }
    }
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
        let isMagSafe =
          record.firstUseDate == nil
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
          print(
            "[CoreDataMigration] \(version): Migrated \(modifiedCount) records to MagSafe Battery Pack."
          )
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
