import BackgroundTasks
import UIKit

@available(iOS 17, *)
@MainActor
enum LocalCollectionScheduler {
  static let identifier = "net.ryuya-dev.MochiLog.local-scheduled-collection"
  static let refreshIdentifier = "net.ryuya-dev.MochiLog.local-scheduled-refresh"
  private static let identifiers = [identifier, refreshIdentifier]
  private static var revision = 0

  /// Unlike continued-processing tasks, OS-wake handlers must be registered at launch.
  static func register() {
    guard !ProcessInfo.processInfo.isiOSAppOnMac else { return }
    for id in identifiers {
      let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: .main) { task in
        guard task is BGProcessingTask || task is BGAppRefreshTask else { task.setTaskCompleted(success: false); return }
        Task { @MainActor in await run(task) }
      }
      MacTransferManager.appendDebugEvent("Local scheduler: launch registration; identifier=\(id), accepted=\(registered)")
    }
  }

  static func reschedule() {
    revision += 1
    let currentRevision = revision
    guard !ProcessInfo.processInfo.isiOSAppOnMac,
      AppSettings.shared.localAutomaticCollectionEnabled,
      LocalDiagnosticsManager.shared.hasStoredCredential else {
      for id in identifiers { BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: id) }
      MacTransferManager.appendDebugEvent("Local scheduler: cancelled; disabled or no pairing")
      return
    }
    let decision = LocalDiagnosticsManager.shared.backgroundSchedule()
    Task { @MainActor in
      let pending = await BGTaskScheduler.shared.pendingTaskRequests()
      guard revision == currentRevision else { return }
      for id in identifiers {
        if let existing = pending.first(where: { $0.identifier == id }),
          let date = existing.earliestBeginDate,
          (abs(date.timeIntervalSince(decision.earliest)) < 60 || (decision.reason == .retry && date <= decision.earliest)) {
          continue // Opening settings must not keep postponing a pending wake.
        }
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: id)
        let request: BGTaskRequest
        if id == identifier {
          let processing = BGProcessingTaskRequest(identifier: id)
          processing.requiresNetworkConnectivity = true
          processing.requiresExternalPower = false
          request = processing
        } else { request = BGAppRefreshTaskRequest(identifier: id) }
        request.earliestBeginDate = decision.earliest
        do {
          try BGTaskScheduler.shared.submit(request)
          MacTransferManager.appendDebugEvent("Local scheduler: requested; identifier=\(id), reason=\(decision.reason.rawValue), earliest=\(LocalCollectionSchedule.timestamp(decision.earliest)), unlocked+VPN required; OS selects execution time")
        } catch {
          let error = error as NSError
          MacTransferManager.appendDebugEvent("Local scheduler: request rejected; identifier=\(id), domain=\(error.domain), code=\(error.code), refreshStatus=\(UIApplication.shared.backgroundRefreshStatus.rawValue)")
        }
      }
    }
  }

  private static func run(_ task: BGTask) async {
    let completion = LocalCollectionTaskCompletion()
    let cancellation = LocalCollectionCancellation()
    task.expirationHandler = {
      // Cancel immediately, even if MainActor is busy. Native read checks at safe boundaries.
      cancellation.cancel()
      if completion.claim() { task.setTaskCompleted(success: false) }
      Task { @MainActor in
        LocalDiagnosticsManager.shared.cancelScheduledCollection(cancellation)
        MacTransferManager.appendDebugEvent("Local scheduler: OS budget expired; complete checkpoints retained")
        reschedule()
      }
    }
    MacTransferManager.appendDebugEvent("Local scheduler: OS wake; identifier=\(task.identifier), protectedDataAvailable=\(UIApplication.shared.isProtectedDataAvailable), appState=\(UIApplication.shared.applicationState.rawValue)")
    let success = await LocalDiagnosticsManager.shared.collectNow(manual: false, scheduled: cancellation)
    if completion.claim() { task.setTaskCompleted(success: success && !cancellation.isCancelled) }
    MacTransferManager.appendDebugEvent("Local scheduler: wake ended; success=\(success), cancelled=\(cancellation.isCancelled)")
    reschedule()
  }
}
