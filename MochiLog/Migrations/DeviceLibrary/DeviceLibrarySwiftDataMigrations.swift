#if os(iOS)
  import Foundation
  import SwiftData

  @available(iOS 17, *)
  extension DeviceLibraryMigrations {
    static func runPending(in context: ModelContext) throws {
      guard !ProcessInfo.processInfo.isiOSAppOnMac else { return }
      if !UserDefaults.standard.bool(forKey: Migration_v3_WatchSeries3Capacity.swiftDataKey) {
        try Migration_v3_WatchSeries3Capacity.migrate(modelContext: context)
      }
      if !UserDefaults.standard.bool(forKey: Migration_v4_DeviceLibraryIdentity.swiftDataKey) {
        try Migration_v4_DeviceLibraryIdentity.migrate(modelContext: context)
      }
    }

    @discardableResult
    static func repairIfNeeded(
      _ records: [CurrentBatterySchema.BatteryRecord], in context: ModelContext
    ) -> Bool {
      guard Migration_v3_WatchSeries3Capacity.repairIfNeeded(records, in: context) else {
        return false
      }
      return Migration_v4_DeviceLibraryIdentity.repairIfNeeded(records, in: context)
    }
  }

  @available(iOS 17, *)
  extension Migration_v4_DeviceLibraryIdentity: Migration {
    @discardableResult
    static func repairIfNeeded(
      _ records: [CurrentBatterySchema.BatteryRecord], in context: ModelContext
    ) -> Bool {
      guard !ProcessInfo.processInfo.isiOSAppOnMac else { return true }
      var count = 0
      for record in records {
        guard
          let corrected = correction(
            name: record.deviceName, modelCode: record.deviceModelCode, osVersion: record.osVersion)
        else { continue }
        record.deviceName = corrected.name
        record.deviceModelCode = corrected.modelCode
        count += 1
      }
      guard count > 0 else { return true }
      do {
        try context.save()
        DeviceLibraryMigrations.logCorrections(count, version: version, storage: "SwiftData")
        return true
      } catch {
        context.rollback()
        ICloudSyncManager.shared.handleSaveError(error)
        print("[Migration \(version)] SwiftData save failed; rolled back: \(error)")
        return false
      }
    }

    static func migrate(modelContext: ModelContext) throws {
      guard !ProcessInfo.processInfo.isiOSAppOnMac else { return }
      let records = try modelContext.fetch(FetchDescriptor<CurrentBatterySchema.BatteryRecord>())
      guard repairIfNeeded(records, in: modelContext) else { throw Failure.saveFailed }
      UserDefaults.standard.set(true, forKey: swiftDataKey)
    }
  }
#endif
