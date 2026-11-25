import Combine
import Foundation
import WatchConnectivity

/// iPhoneからApple Watchへデータを送信するためのWatch Connectivity Manager
/// シングルトンパターンで実装し、アプリ全体から利用可能
final class WatchConnectivityManager: NSObject, ObservableObject {
  // MARK: - シングルトン

  static let shared = WatchConnectivityManager()

  // MARK: - Published プロパティ

  /// Watchアプリが到達可能かどうか
  @Published private(set) var isReachable = false

  /// Watchアプリがインストールされているかどうか
  @Published private(set) var isWatchAppInstalled = false

  /// nil until WatchConnectivity has reported the OS pairing state.
  @Published private(set) var isWatchPaired: Bool?

  // MARK: - プライベートプロパティ

  private var session: WCSession?
  private let deliveryQueue = DispatchQueue(
    label: "net.ryuya-dev.MochiLog.watch-delivery", qos: .utility)
  // Accessed only on deliveryQueue. Keep data until activation/installation completes.
  private var pendingSnapshot: WatchRecordSnapshot<WatchBatteryRecord>?

  // MARK: - 初期化

  private override init() {
    super.init()
  }

  // MARK: - セッション管理

  /// Watch Connectivityセッションを開始
  func startSession() {
    guard WCSession.isSupported() else {
      isWatchPaired = false
      print("[WatchConnectivity] WCSessionはこのデバイスでサポートされていません")
      return
    }

    session = WCSession.default
    session?.delegate = self
    session?.activate()
    print("[WatchConnectivity] セッションをアクティベート中...")
  }

  /// Capture the published record contents in source order. Encoding and transfer
  /// share one serial queue with manual replies.
  func sendRecordsToWatch(_ records: [BatteryRecord], isSampleMode: Bool) {
    let watchRecords = records.map { WatchBatteryRecord(from: $0) }
    deliveryQueue.async {
      let previous = self.pendingSnapshot ?? self.session.flatMap {
        try? WatchRecordSnapshot<WatchBatteryRecord>(context: $0.applicationContext)
      }
      let snapshot = WatchRecordSnapshot.capture(
        watchRecords, isSampleMode: isSampleMode, after: previous,
        now: Date().timeIntervalSince1970)
      if let pending = self.pendingSnapshot, snapshot.hasSameContent(as: pending) { return }
      self.pendingSnapshot = snapshot
      self.deliverPendingSnapshot()
    }
  }

  /// Retry the latest snapshot after session activation, installation or language changes.
  func resendLatestSnapshot() {
    deliveryQueue.async { self.deliverPendingSnapshot() }
  }

  private func snapshotContext() throws -> [String: Any]? {
    try pendingSnapshot?.context(
      appLanguage: UserDefaults.standard.string(forKey: L10n.preferenceKey) ?? "system")
  }

  private func deliverPendingSnapshot() {
    guard let session = session, session.activationState == .activated,
      session.isWatchAppInstalled
    else { return }
    do {
      guard let context = try snapshotContext() else { return }
      try session.updateApplicationContext(context)
      print("[WatchConnectivity] Queued \(pendingSnapshot?.records.count ?? 0) records")
    } catch {
      print("[WatchConnectivity] Failed to send records: \(error)")
    }
  }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    Task { @MainActor in
      if let error = error {
        print("[WatchConnectivity] アクティベーション失敗: \(error)")
        return
      }

      switch activationState {
      case .activated:
        print("[WatchConnectivity] セッションがアクティベートされました")
        isWatchPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable
        resendLatestSnapshot()
      case .inactive:
        print("[WatchConnectivity] セッションが非アクティブです")
      case .notActivated:
        print("[WatchConnectivity] セッションがアクティベートされていません")
      @unknown default:
        break
      }
    }
  }

  nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
    Task { @MainActor in isWatchPaired = nil }
    print("[WatchConnectivity] セッションが非アクティブになりました")
  }

  nonisolated func sessionDidDeactivate(_ session: WCSession) {
    print("[WatchConnectivity] セッションが非アクティブ化されました")
    // 再アクティベート
    Task { @MainActor in
      self.isWatchPaired = nil
      self.session?.activate()
    }
  }

  nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor in
      isReachable = session.isReachable
      if session.isReachable { resendLatestSnapshot() }
      print("[WatchConnectivity] 到達可能性が変更されました: \(session.isReachable)")
    }
  }

  nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
    Task { @MainActor in
      isWatchPaired = session.isPaired
      isWatchAppInstalled = session.isWatchAppInstalled
      resendLatestSnapshot()
      print("[WatchConnectivity] Watchアプリのインストール状態が変更されました: \(session.isWatchAppInstalled)")
    }
  }

  /// Watchからメッセージを受信（返信ハンドラー付き）
  nonisolated func session(
    _ session: WCSession,
    didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    print("[WatchConnectivity] Watch側からメッセージを受信しました")

    guard message["request"] as? String == "syncRecords" else {
      replyHandler(["status": "ok"])
      return
    }

    deliveryQueue.async {
      do {
        // applicationContext is only the last submitted payload. Reply with the
        // current snapshot even if the background transfer has not caught up.
        replyHandler(try self.snapshotContext() ?? ["error": "No data available"])
      } catch {
        print("[WatchConnectivity] Could not encode the current snapshot: \(error)")
        replyHandler(["error": "No data available"])
      }
    }
  }
}
