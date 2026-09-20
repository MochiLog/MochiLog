import Combine
import SwiftUI
import UIKit
import WatchConnectivity

/// UIKit owns URL delivery so every URL in a single Open In request reaches the queue.
/// All app screens remain SwiftUI views.
@main
final class MochiLogApp: UIResponder, UIApplicationDelegate {
  private static let appGroupIdentifier = "group.net.ryuya-dev.MochiLog"

  func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    prepareApplicationSupportDirectories()
    WatchConnectivityManager.shared.startSession()
    return true
  }

  func application(_ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    // Keep the name in sync with Info.plist so UIKit can validate restored sessions
    // against our current lifecycle instead of restoring SwiftUI.AppSceneDelegate.
    let configuration = UISceneConfiguration(
      name: "MochiLog Main Scene", sessionRole: connectingSceneSession.role)
    configuration.sceneClass = UIWindowScene.self
    configuration.delegateClass = MochiLogSceneDelegate.self
    return configuration
  }

  static func route(_ urls: [URL]) {
    let files = urls.filter(\.isFileURL)
    if !files.isEmpty {
      ErrorLogStore.shared.saveLog(
        message: "[Import receipt] Received \(files.count) file URL(s): "
          + files.map(\.lastPathComponent).joined(separator: ", "), rawText: nil)
    }
    for url in urls {
      if url.scheme == "mochilog" {
        handleShortcutCallback(url)
      } else {
        let interactive = AppSettings.shared.openAppAfterShareImport
        SharedImportQueue.shared.enqueue(url,
          presentsResults: interactive && files.count > 1,
          opensDetail: interactive && files.count == 1)
      }
    }
  }

  private func prepareApplicationSupportDirectories() {
    do {
      let fileManager = FileManager.default
      let appSupportURL = try fileManager.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
      print("Database path checked: \(appSupportURL.path)")
      try ensureAppGroupApplicationSupport(in: fileManager)
    } catch {
      print("Failed to create Application Support directory: \(error)")
    }
  }

  private func ensureAppGroupApplicationSupport(in fileManager: FileManager) throws {
    guard
      let containerURL = fileManager.containerURL(
        forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)
    else {
      return
    }
    let libraryURL = containerURL.appendingPathComponent("Library", isDirectory: true)
    let appGroupSupportURL = libraryURL.appendingPathComponent(
      "Application Support", isDirectory: true)
    try fileManager.createDirectory(at: appGroupSupportURL, withIntermediateDirectories: true)
    print("App Group database path checked: \(appGroupSupportURL.path)")
  }

  private static func handleShortcutCallback(_ url: URL) {
    switch url.host {
    case "shortcut-success":
      // 注: 現在はx-successコールバックを使用していないため、このケースは呼ばれない
      // ショートカット成功時はアプリに戻らず、解析データ画面に留まるようにするため
      print("✅ ショートカット実行成功")
      DispatchQueue.main.async {
        AppSettings.shared.isShortcutInstalled = true
      }

    case "shortcut-error":
      print("❌ ショートカットが存在しないか、エラー発生")
      DispatchQueue.main.async {
        AppSettings.shared.isShortcutInstalled = false
        // エラー通知を送信
        NotificationCenter.default.post(
          name: NSNotification.Name("ShortcutNotFound"), object: nil)
      }

    case "setup-complete":
      print("✅ ショートカットセットアップ完了")
      DispatchQueue.main.async {
        AppSettings.shared.isShortcutInstalled = true
        // セットアップ完了通知を送信
        NotificationCenter.default.post(
          name: NSNotification.Name("ShortcutSetupComplete"), object: nil)
      }

    default:
      break
    }
  }
}

final class MochiLogSceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    #if DEBUG && targetEnvironment(simulator)
    // Screenshot automation must be dark even if Xcode supplies a light trait override.
    if ProcessInfo.processInfo.environment["MOCHI_STORE_SCREENSHOTS"] == "1" {
      window.overrideUserInterfaceStyle = .dark
      // Export the same sample records for the companion's isolated screenshot fixture.
      do {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let records = SampleDataProvider.generateSampleRecords().map { WatchBatteryRecord(from: $0) }
        let destination = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
          .appendingPathComponent("store-screenshot-records.json")
        try encoder.encode(records).write(to: destination, options: .atomic)
      } catch { print("Screenshot fixture export failed: \(error)") }
    }
    if ProcessInfo.processInfo.environment["MOCHI_LAYOUT_TEST"] == "1" {
      window.rootViewController = UIHostingController(rootView: LayoutValidationHost())
    } else {
      window.rootViewController = UIHostingController(rootView: MochiLogRootView())
    }
    #else
    window.rootViewController = UIHostingController(rootView: MochiLogRootView())
    #endif
    self.window = window
    window.makeKeyAndVisible()
    open(connectionOptions.urlContexts)
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    open(URLContexts)
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    guard let root = SharedLogInbox.root else { return }
    do {
      let files = try SharedLogInbox.pendingFiles(at: root)
      if !files.isEmpty {
        ErrorLogStore.shared.saveLog(message: "[Share extension receipt] \(files.count) file(s)", rawText: nil)
      }
      for file in files { SharedImportQueue.shared.enqueue(file, presentsResults: true) }
    } catch {
      ErrorLogStore.shared.saveLog(message: "Shared import inbox: \(error.localizedDescription)", rawText: nil)
    }
  }

  private func open(_ contexts: Set<UIOpenURLContext>) {
    MochiLogApp.route(contexts.map(\.url).sorted { $0.absoluteString < $1.absoluteString })
  }
}

/// アプリのルートビュー。iCloud設定に応じてDataStoreを動的に切り替える責務を持つ。
struct MochiLogRootView: View {
  @ObservedObject private var languageSettings = LanguageSettings.shared
  private let appSettings = AppSettings.shared
  @StateObject private var dataStore: DataStore
  @State private var viewID = UUID()
  @State private var isReloading = false

  init() {
    let store = DataStore.create(iCloudEnabled: AppSettings.shared.iCloudSyncEnabled)
    _dataStore = StateObject(wrappedValue: store)
    // CloudKitのインポートイベント完了時に自動refreshできるよう登録
    ICloudSyncManager.shared.register(dataStore: store)
    WatchConnectivityManager.shared.sendRecordsToWatch(store.recordsDescending)
  }

  var body: some View {
    ZStack {
      // メインコンテンツ
      MainTabView()
        .environmentObject(dataStore)
        .environment(\.locale, L10n.locale)
        .id("\(viewID)-\(languageSettings.selection.rawValue)")
        .allowsHitTesting(!isReloading)  // リロード中は操作無効（見た目は変えない）
        .blur(radius: isReloading ? 1.5 : 0)  // 少しぼかす
        .animation(.easeInOut(duration: 0.5), value: isReloading)  // ぼかしのアニメーション
        .task {
          // アプリ起動時にマイグレーションを実行
          dataStore.runMigrations()
        }

      // ローディングオーバーレイ
      // 再読込時のみ出る。
      if isReloading {
        ZStack {
          // 背景が消えても違和感がないように、ベースカラーを敷く
          Color(uiColor: .systemGroupedBackground)
            .ignoresSafeArea()

          // すりガラス効果
          Rectangle()
            .fill(.ultraThinMaterial)
            .ignoresSafeArea()

          VStack(spacing: 24) {
            ProgressView()
              .controlSize(.large)
              .scaleEffect(1.2)

            Text(L10n.string("applying_settings", table: "Settings"))
              .font(.headline)
              .foregroundStyle(.secondary)
          }
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
      }
    }
    .onReceive(languageSettings.$selection.removeDuplicates().dropFirst()) { _ in
      // @Published emits before didSet persists the new preference.
      Task { @MainActor in
        WatchConnectivityManager.shared.resendLatestSnapshot()
      }
    }
    .onReceive(appSettings.$iCloudSyncEnabled.removeDuplicates().dropFirst()) { _ in
      print("iCloud設定変更検知 - RootView再構築開始")
      // タブインデックスを保存してリロード後に復元
      let currentTabIndex = appSettings.selectedTabIndex
      withAnimation(.easeInOut(duration: 0.2)) {
        isReloading = true
      }
      reloadDataStore(delay: 0.1, preserveTabIndex: currentTabIndex)
    }
  }

  private func reloadDataStore(delay: Double = 0.1, preserveTabIndex: Int? = nil) {
    // 遅延実行
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {

      // ある程度待機してから新しいストアを作成・適用
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        let isEnabled = appSettings.iCloudSyncEnabled
        print("DataStore再生成開始: iCloud \(isEnabled ? "有効" : "無効")")

        // 注: iOS 17+ ではストア再生成、iOS 16 では iCloud 未サポートなので影響なし
        // DataStore は @StateObject なので直接差し替えは不可
        // 代わりにリフレッシュで対応
        dataStore.refreshRecords()
        self.viewID = UUID()
        print("DataStore再生成完了: ID \(self.viewID)")

        // タブインデックスを復元
        if let tabIndex = preserveTabIndex {
          appSettings.selectedTabIndex = tabIndex
        }

        // 完了したら、文字が読める程度の時間を確保してから消す
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          withAnimation(.easeInOut(duration: 0.5)) {
            self.isReloading = false
          }
        }
      }
    }
  }
}
