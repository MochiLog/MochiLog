import Foundation

/// Correct the bundled Series 3 Cellular references without reclassifying a
/// device or changing any measurement, record ID, physical ID or date.
struct Migration_v3_WatchSeries3Capacity {
  static let version = "v3_WatchSeries3Capacity"
  static let description = "Apple Watch Series 3 Cellularの基準容量を補正"
  static let swiftDataKey = "Migration_Completed_" + version
  static let coreDataKey = "CoreDataMigration_Completed_" + version
  private enum Failure: Error { case saveFailed }

  static func correctedDesignCapacity(
    for name: String, storedCapacity: Int, profiles: DeviceProfileStore = .shared
  ) -> Int? {
    let corrections = [
      "Apple Watch 3 (42mm) Cellular": (previous: 279, corrected: 352),
      "Apple Watch 3 (38mm) Cellular": (previous: 262, corrected: 279),
    ]
    // Match the saved name. An old manual selection may have assigned an
    // incorrect model code, which cannot safely identify a historical Watch.
    guard let correction = corrections[name], storedCapacity == correction.previous,
      profiles.capacity(name) == correction.corrected,
      !profiles.entries.contains(where: {
        $0.current.name == name || $0.previousNames.contains(name)
      })
    else { return nil }
    return correction.corrected
  }

  private static func diagnostic(rawCapacity: Int, designCapacity: Int) -> String {
    let percent = Double(rawCapacity) / Double(designCapacity) * 100
    return L10n.string(
      percent < 80
        ? "diag_replace_recommended"
        : percent < 90 ? "diag_slightly_degraded" : "diag_normal",
      table: "Records")
  }
}

#if os(iOS)
  import CoreData
  import SwiftData

  extension Migration_v3_WatchSeries3Capacity {
    /// Called again for later imports/cloud arrivals. The exact old-value
    /// predicate makes this idempotent even after the initial migration flag.
    @discardableResult
    static func repairIfNeeded(_ records: [CDBatteryRecord], in context: NSManagedObjectContext)
      -> Bool
    {
      guard !ProcessInfo.processInfo.isiOSAppOnMac else { return true }
      var count = 0
      for record in records {
        guard
          let capacity = correctedDesignCapacity(
            for: record.deviceName, storedCapacity: Int(record.designCapacity))
        else { continue }
        record.designCapacity = Int64(capacity)
        if record.rawCapacity > 0 {
          record.diagnosticResult = diagnostic(
            rawCapacity: Int(record.rawCapacity), designCapacity: capacity)
        }
        count += 1
      }
      guard count > 0 else { return true }
      do {
        try context.save()
        logCorrections(count, storage: "CoreData")
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

    private static func logCorrections(_ count: Int, storage: String) {
      let event =
        "[Migration \(version)] \(storage): corrected \(count) Watch reference capacities; measurements and identities unchanged"
      print(event)
      if #available(iOS 17, *) {
        MacTransferManager.appendDebugEvent(event)
      }
    }
  }

  @available(iOS 17, *)
  extension Migration_v3_WatchSeries3Capacity: Migration {
    @discardableResult
    static func repairIfNeeded(
      _ records: [CurrentBatterySchema.BatteryRecord], in context: ModelContext
    ) -> Bool {
      guard !ProcessInfo.processInfo.isiOSAppOnMac else { return true }
      var count = 0
      for record in records {
        guard
          let capacity = correctedDesignCapacity(
            for: record.deviceName, storedCapacity: record.designCapacity)
        else { continue }
        record.designCapacity = capacity
        if record.rawCapacity > 0 {
          record.diagnosticResult = diagnostic(
            rawCapacity: record.rawCapacity, designCapacity: capacity)
        }
        count += 1
      }
      guard count > 0 else { return true }
      do {
        try context.save()
        logCorrections(count, storage: "SwiftData")
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
