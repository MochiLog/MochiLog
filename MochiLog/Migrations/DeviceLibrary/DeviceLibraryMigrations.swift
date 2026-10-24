import Foundation

/// Persistence adapters and versioned corrections for bundled device metadata
/// live in this folder. Stores only invoke this entry point.
enum DeviceLibraryMigrations {
  static func diagnostic(rawCapacity: Int, designCapacity: Int) -> String {
    let percent = Double(rawCapacity) / Double(designCapacity) * 100
    return L10n.string(
      percent < 80
        ? "diag_replace_recommended"
        : percent < 90 ? "diag_slightly_degraded" : "diag_normal",
      table: "Records")
  }

  static func logCapacityCorrections(_ count: Int, version: String, storage: String) {
    log(
      "[Migration \(version)] \(storage): corrected \(count) iPad reference capacities; measurements, dates and IDs unchanged"
    )
  }

  static func logCorrections(_ count: Int, version: String, storage: String) {
    log(
      "[Migration \(version)] \(storage): corrected \(count) device metadata records; capacities, measurements, dates and IDs unchanged"
    )
  }

  private static func log(_ event: String) {
    print(event)
    #if os(iOS)
      if #available(iOS 17, *) {
        MacTransferManager.appendDebugEvent(event)
      }
    #endif
  }
}
