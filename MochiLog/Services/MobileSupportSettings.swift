import AVFoundation
import CoreTelephony
import Foundation
import UIKit
import UserNotifications

@available(iOS 17, *)
@MainActor enum MobileSupportSettings {
  private static let cellularData: CTCellularData = {
    let probe = CTCellularData()
    probe.cellularDataRestrictionDidUpdateNotifier = { state in
      let status =
        state.rawValue == 1 ? "restricted" : (state.rawValue == 2 ? "not-restricted" : "unknown")
      Task { @MainActor in
        cachedCellular = .init(status, source: "CTCellularData restriction update")
      }
    }
    return probe
  }()
  private static var cachedCellular: SupportSettingsSnapshot.Permission?
  private static var notification: SupportSettingsSnapshot.Permission?

  static func refreshPermissions() async {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    let status: String
    switch settings.authorizationStatus {
    case .authorized: status = "authorized"
    case .denied: status = "denied"
    case .notDetermined: status = "not-determined"
    case .provisional: status = "provisional"
    case .ephemeral: status = "ephemeral"
    @unknown default: status = "unknown"
    }
    notification = .init(status, source: "UNUserNotificationCenter.notificationSettings")
  }

  static func capture(manager: MacTransferManager) -> Data {
    let settings = AppSettings.shared
    let defaults = UserDefaults.standard
    let camera: String
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: camera = "authorized"
    case .denied: camera = "denied"
    case .restricted: camera = "restricted"
    case .notDetermined: camera = "not-determined"
    @unknown default: camera = "unknown"
    }
    let background: String
    switch UIApplication.shared.backgroundRefreshStatus {
    case .available: background = "available"
    case .denied: background = "denied"
    case .restricted: background = "restricted"
    @unknown default: background = "unknown"
    }
    let cellular: String
    if ProcessInfo.processInfo.isiOSAppOnMac {
      cellular = "not-applicable"
    } else {
      switch cellularData.restrictedState.rawValue {
      case 1: cellular = "restricted"
      case 2: cellular = "not-restricted"
      default: cellular = "unknown"
      }
    }
    return SupportSettingsSnapshot.encode(
      platform: "iOS",
      toggles: [
        "pcAutomaticCollection": settings.pcAutomaticCollectionEnabled,
        "onDeviceCollection": settings.localAutomaticCollectionEnabled,
        "liveBatteryTab": settings.liveBatteryEnabled,
        "allowCellularTransfer": manager.allowsCellularTransfer,
        "iCloudSync": settings.iCloudSyncEnabled,
        "allowDuplicateRecords": settings.allowDuplicateRecords,
        "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
        "runningIOSAppOnMac": ProcessInfo.processInfo.isiOSAppOnMac,
        "localCredentialPresenceHint": defaults.bool(forKey: "LocalDiagnosticsHasCredential"),
      ],
      limits: [
        "debugRetentionDays": manager.debugRetentionDays,
        "pairedComputerCount": manager.pairings.count,
        "registeredWatchCount": settings.registeredWatches.count,
      ],
      selections: ["deviceSelectionMode": settings.deviceSelectionMode.rawValue],
      permissions: [
        "camera": .init(camera, source: "AVCaptureDevice.authorizationStatus"),
        "cellularData": cachedCellular ?? .init(cellular, source: "CTCellularData.restrictedState"),
        "notifications": notification ?? .init("unknown", source: "not-yet-queried"),
        "backgroundRefresh": .init(background, source: "UIApplication.backgroundRefreshStatus"),
        "localNetwork": .init(
          "unknown", source: "no-general-public-query-API; see networkObservations"),
        "analyticsSharing": .init("unknown", source: "no-public-query-API"),
        "developerMode": .init("unknown", source: "not-probed-by-settings-export"),
        "otherVPNApps": .init("unknown", source: "no-general-public-query-API"),
      ])
  }
}
