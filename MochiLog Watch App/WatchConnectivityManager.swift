import Combine
import Foundation
import WatchConnectivity

/// Apple Watch側でiPhoneからのデータを受信するためのWatch Connectivity Manager
final class WatchConnectivityManager: NSObject, ObservableObject {
  // MARK: - シングルトン

  static let shared = WatchConnectivityManager()

  // MARK: - Published プロパティ

  /// iPhoneアプリが到達可能かどうか
  @Published private(set) var isReachable = false

  /// 受信したバッテリーレコード
  @Published private(set) var records: [WatchBatteryRecord] = []

  /// 最後の同期日時
  @Published private(set) var lastSyncDate: Date?

  /// 同期エラーメッセージ
  @Published private(set) var syncError: String?

  /// 同期中かどうか
  @Published private(set) var isSyncing = false

  /// サンプルモードかどうか（iPhone側の設定を同期）
  @Published private(set) var isSampleMode = false

  // MARK: - プライベートプロパティ

  private var session: WCSession?
  private var receivedSnapshot: WatchRecordSnapshot<WatchBatteryRecord>?

  // MARK: - 初期化

  private override init() {
    super.init()
  }

  // MARK: - セッション管理

  /// Watch Connectivityセッションを開始
  func startSession() {
    #if DEBUG && targetEnvironment(simulator)
      if ProcessInfo.processInfo.environment["MOCHI_STORE_SCREENSHOTS"] == "1" {
        // Same Codable payload as WatchConnectivity, supplied by the screenshot script.
        // Keep asynchronous sync from replacing the fixture midway through a capture.
        do {
          let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("store-screenshot-records.json")
          let decoder = JSONDecoder()
          decoder.dateDecodingStrategy = .iso8601
          records = try decoder.decode([WatchBatteryRecord].self, from: Data(contentsOf: file))
            .sorted { $0.logDate > $1.logDate }
          isSampleMode = true
        } catch { print("Screenshot fixture load failed: \(error)") }
        return
      }
    #endif
    guard WCSession.isSupported() else {
      print("[WatchConnectivity] WCSessionはこのデバイスでサポートされていません")
      return
    }

    session = WCSession.default
    session?.delegate = self
    session?.activate()
    print("[WatchConnectivity] セッションをアクティベート中...")
  }

  // MARK: - データ取得

  /// iPhoneにデータ更新をリクエスト
  func requestDataFromiPhone() {
    guard let session = session,
      session.activationState == .activated,
      session.isReachable
    else {
      syncError = L10n.string("watch_connection_failed", table: "Language")
      return
    }

    // 既に同期中の場合は何もしない
    guard !isSyncing else { return }

    isSyncing = true
    syncError = nil

    session.sendMessage(
      ["request": "syncRecords"],
      replyHandler: { [weak self] reply in
        Task { @MainActor in
          self?.isSyncing = false
          self?.handleReceivedData(reply)
        }
      },
      errorHandler: { [weak self] error in
        Task { @MainActor in
          self?.isSyncing = false
          self?.syncError = String(
            format: L10n.string("watch_sync_error", table: "Language"), error.localizedDescription)
          print("[WatchConnectivity] データリクエストエラー: \(error)")
        }
      }
    )
  }

  // MARK: - データ処理

  /// 受信したデータを処理
  private func handleReceivedData(_ data: [String: Any]) {
    if data["error"] != nil {
      syncError = L10n.string("watch_no_data", table: "Language")
      return
    }
    guard !data.isEmpty else { return } // No cached context on the first activation.

    do {
      let snapshot = try WatchRecordSnapshot<WatchBatteryRecord>(context: data)
      guard snapshot.canFollow(receivedSnapshot) else {
        print("[WatchConnectivity] Ignored a superseded record snapshot")
        return
      }
      let unchanged = receivedSnapshot.map { snapshot.hasSameContent(as: $0) } ?? false
      receivedSnapshot = snapshot
      if !unchanged {
        records = snapshot.records.sorted { $0.logDate > $1.logDate }
        isSampleMode = snapshot.isSampleMode
        lastSyncDate = snapshot.syncTimestamp.map { Date(timeIntervalSince1970: $0) }
        print("[WatchConnectivity] Applied \(snapshot.records.count) records")
      }
      if let language = data["appLanguage"] as? String,
        let selection = AppLanguage(rawValue: language)
      {
        LanguageSettings.shared.selection = selection
      }
      syncError = nil
    } catch {
      syncError = L10n.string("watch_load_failed", table: "Language")
      print("[WatchConnectivity] データのデコードに失敗: \(error)")
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
        syncError = String(
          format: L10n.string("watch_sync_error", table: "Language"), error.localizedDescription)
        print("[WatchConnectivity] アクティベーション失敗: \(error)")
        return
      }

      switch activationState {
      case .activated:
        print("[WatchConnectivity] セッションがアクティベートされました")
        isReachable = session.isReachable
        // アクティベート後、Application Contextから既存データを読み込む
        handleReceivedData(session.receivedApplicationContext)
      case .inactive:
        print("[WatchConnectivity] セッションが非アクティブです")
      case .notActivated:
        print("[WatchConnectivity] セッションがアクティベートされていません")
      @unknown default:
        break
      }
    }
  }

  nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor in
      isReachable = session.isReachable
      print("[WatchConnectivity] 到達可能性が変更されました: \(session.isReachable)")
    }
  }

  /// Application Contextを受信したとき
  nonisolated func session(
    _ session: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    Task { @MainActor in
      print("[WatchConnectivity] Application Contextを受信しました")
      handleReceivedData(applicationContext)
    }
  }

  /// メッセージを受信したとき
  nonisolated func session(
    _ session: WCSession,
    didReceiveMessage message: [String: Any]
  ) {
    Task { @MainActor in
      print("[WatchConnectivity] メッセージを受信しました")
      handleReceivedData(message)
    }
  }

  /// メッセージを受信したとき（返信ハンドラー付き）
  nonisolated func session(
    _ session: WCSession,
    didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    Task { @MainActor in
      print("[WatchConnectivity] メッセージを受信しました（返信ハンドラー付き）")
      handleReceivedData(message)
      replyHandler(["status": "received"])
    }
  }
}
