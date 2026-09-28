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

  /// 最後の同期日時
  @Published private(set) var lastSyncDate: Date?

  // MARK: - プライベートプロパティ

  private var session: WCSession?
  private let deliveryQueue = DispatchQueue(label: "net.ryuya-dev.MochiLog.watch-delivery", qos: .utility)
  // Accessed only on deliveryQueue. Keep data until activation/installation completes.
  private var pendingSnapshot: (records: [WatchBatteryRecord], isSampleMode: Bool)?

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

  /// バッテリーレコードをApple Watchに送信（バックグラウンドで実行）
  /// - Parameters:
  ///   - records: 送信するBatteryRecordの配列
  ///   - isSampleMode: サンプルモードかどうか
  func sendRecordsToWatch(_ records: [BatteryRecord], isSampleMode: Bool = false) {
    let watchRecords = records.map { WatchBatteryRecord(from: $0) }
    sendWatchRecordsToWatch(watchRecords, isSampleMode: isSampleMode)
  }

  /// WatchBatteryRecordをApple Watchに送信（バックグラウンドで実行）
  /// - Parameters:
  ///   - records: 送信するWatchBatteryRecordの配列
  ///   - isSampleMode: サンプルモードかどうか
  func sendWatchRecordsToWatch(_ records: [WatchBatteryRecord], isSampleMode: Bool = false) {
    deliveryQueue.async {
      self.pendingSnapshot = (records, isSampleMode)
      self.deliverPendingSnapshot()
    }
  }

  /// Retry the latest snapshot after session activation, installation or language changes.
  func resendLatestSnapshot() {
    deliveryQueue.async { self.deliverPendingSnapshot() }
  }

  private func deliverPendingSnapshot() {
    guard let snapshot = pendingSnapshot, let session = session,
      session.activationState == .activated, session.isWatchAppInstalled else { return }
    do {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(snapshot.records)
      let context: [String: Any] = [
        "records": data,
        "syncDate": Date().timeIntervalSince1970,
        "appLanguage": UserDefaults.standard.string(forKey: L10n.preferenceKey) ?? "system",
        "isSampleMode": snapshot.isSampleMode,
      ]
      try session.updateApplicationContext(context)
      Task { @MainActor in self.lastSyncDate = Date() }
      print("[WatchConnectivity] Sent \(snapshot.records.count) records")
    } catch {
      print("[WatchConnectivity] Failed to send records: \(error)")
    }
  }

  /// 即座にデータを送信（Watchが到達可能な場合のみ）
  /// - Parameter records: 送信するBatteryRecordの配列
  func sendRecordsImmediately(_ records: [BatteryRecord]) {
    sendRecordsToWatch(records)
    guard let session = session,
      session.activationState == .activated,
      session.isReachable
    else {
      // 到達不可能な場合はApplication Contextにフォールバック
      sendRecordsToWatch(records)
      return
    }

    let watchRecords = records.map { WatchBatteryRecord(from: $0) }

    do {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(watchRecords)

      let message: [String: Any] = [
        "records": data,
        "syncDate": Date().timeIntervalSince1970,
          "appLanguage": UserDefaults.standard.string(forKey: L10n.preferenceKey) ?? "system",
      ]

      session.sendMessage(
        message,
        replyHandler: { reply in
          Task { @MainActor in
            self.lastSyncDate = Date()
            print("[WatchConnectivity] Watchからの応答を受信: \(reply)")
          }
        },
        errorHandler: { error in
          print("[WatchConnectivity] メッセージ送信エラー: \(error)")
          // エラー時はApplication Contextにフォールバック
          Task { @MainActor in
            self.resendLatestSnapshot()
          }
        })
    } catch {
      print("[WatchConnectivity] データのエンコードに失敗: \(error)")
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

    // 同期リクエストの場合、Application Contextを返す
    if message["request"] as? String == "syncRecords" {
      Task { @MainActor in
        // 現在のApplication Contextを返す
        let context = session.applicationContext
        if !context.isEmpty {
          print("[WatchConnectivity] Application Contextを返信します")
          replyHandler(context)
        } else {
          print("[WatchConnectivity] Application Contextが空です")
          replyHandler(["error": "No data available"])
        }
      }
    } else {
      replyHandler(["status": "ok"])
    }
  }
}
