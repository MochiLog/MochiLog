#if os(iOS)
  import CoreData
  import Foundation

  extension DeviceLibraryMigrations {
    static func runPending(in context: NSManagedObjectContext) throws {
      guard !ProcessInfo.processInfo.isiOSAppOnMac else { return }
      if !UserDefaults.standard.bool(forKey: Migration_v3_WatchSeries3Capacity.coreDataKey) {
        try Migration_v3_WatchSeries3Capacity.migrate(viewContext: context)
      }
      if !UserDefaults.standard.bool(forKey: Migration_v4_DeviceLibraryIdentity.coreDataKey) {
        try Migration_v4_DeviceLibraryIdentity.migrate(viewContext: context)
      }
    }

    /// Late imports and old cloud replicas must be checked even after a
    /// migration's completion flag. Each correction matches only an old value.
    @discardableResult
    static func repairIfNeeded(_ records: [CDBatteryRecord], in context: NSManagedObjectContext)
      -> Bool
    {
      guard Migration_v3_WatchSeries3Capacity.repairIfNeeded(records, in: context) else {
        return false
      }
      return Migration_v4_DeviceLibraryIdentity.repairIfNeeded(records, in: context)
    }
  }

  extension Migration_v4_DeviceLibraryIdentity {
    @discardableResult
    static func repairIfNeeded(_ records: [CDBatteryRecord], in context: NSManagedObjectContext)
      -> Bool
    {
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
        DeviceLibraryMigrations.logCorrections(count, version: version, storage: "CoreData")
        return true
      } catch {
        context.rollback()
        Task { @MainActor in ICloudSyncManager.shared.handleSaveError(error) }
        print("[Migration \(version)] CoreData save failed; rolled back: \(error)")
        return false
      }
    }

    static func migrate(viewContext: NSManagedObjectContext) throws {
      guard !ProcessInfo.processInfo.isiOSAppOnMac else { return }
      let records = try viewContext.fetch(
        NSFetchRequest<CDBatteryRecord>(entityName: "CDBatteryRecord"))
      guard repairIfNeeded(records, in: viewContext) else { throw Failure.saveFailed }
      UserDefaults.standard.set(true, forKey: coreDataKey)
    }
  }
#endif
