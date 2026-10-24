import Foundation

/// Persistence adapters and versioned corrections for bundled device metadata
/// live in this folder. Stores only invoke this entry point.
enum DeviceLibraryMigrations {
  static func logCorrections(_ count: Int, version: String, storage: String) {
    let event =
      "[Migration \(version)] \(storage): corrected \(count) device metadata records; capacities, measurements, dates and IDs unchanged"
    print(event)
    #if os(iOS)
      if #available(iOS 17, *) {
        MacTransferManager.appendDebugEvent(event)
      }
    #endif
  }
}
