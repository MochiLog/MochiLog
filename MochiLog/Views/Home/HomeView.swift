import Charts
import Combine
// HomeView.swift
// 別ファイルへ分離
import SwiftUI
import UniformTypeIdentifiers

// MARK: - メインタブビュー
struct MainTabView: View {
  @EnvironmentObject var dataStore: DataStore
  private let appSettings = AppSettings.shared
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @ObservedObject private var deviceProfiles = DeviceProfileStore.shared
  @State private var showingProfileConflicts = false
  @State private var showingTutorial = false
  @State private var showingDiscordAnnouncement = false
  @State private var showingExactDuplicates = false
  @State private var exactDuplicateExtraCount = 0
  @State private var selectedTab: AppTab
  @State private var accentColor: AppSettings.ThemeColor

  init() {
    // AppSettings.selectedTabIndexから初期値を取得
    let savedIndex = AppSettings.shared.selectedTabIndex
    _selectedTab = State(initialValue: AppTab(rawValue: savedIndex) ?? .home)
    _accentColor = State(initialValue: AppSettings.shared.accentColor)
  }

  /// タブの定義
  enum AppTab: Int, CaseIterable, Identifiable {
    case home = 0
    case analytics = 1
    case settings = 2

    var id: Int { rawValue }

    var title: String {
      switch self {
      case .home: return L10n.string("tab_home", table: "Home")
      case .analytics: return L10n.string("tab_analytics", table: "Analytics")
      case .settings: return L10n.string("tab_settings", table: "Settings")
      }
    }

    var icon: String {
      switch self {
      case .home: return "house.fill"
      case .analytics: return "chart.line.uptrend.xyaxis"
      case .settings: return "gearshape.fill"
      }
    }
  }

  var body: some View {
    let _ = print("[Performance] MainTabView.body構築開始")
    let startTime = CFAbsoluteTimeGetCurrent()

    return Group {
      if #available(iOS 18.0, *) {
        // iOS 18+: sidebarAdaptable スタイル（サイドバーを閉じると上部にタブバー）
        modernTabView
      } else if horizontalSizeClass == .regular {
        // iOS 17以下 + iPad: NavigationSplitView
        legacySplitView
      } else {
        // iOS 17以下 + iPhone: 従来のTabView
        legacyTabView
      }
    }
    .background(RecordsObserverView())
    .safeAreaInset(edge: .top) {
      VStack(spacing: 0) {
        if !deviceProfiles.conflicts.isEmpty {
          Button { showingProfileConflicts = true } label: {
            Label(L10n.string("profile_conflict_banner", table: "Settings"), systemImage: "exclamationmark.triangle")
              .font(.subheadline).padding(12).frame(maxWidth: .infinity)
              .background(.regularMaterial)
          }
        }
        if !appSettings.allowDuplicateRecords && exactDuplicateExtraCount > 0 {
          Button { showingExactDuplicates = true } label: {
            Label(String(format: L10n.string("exact_duplicates_banner", table: "ExactDuplicates"),
                         exactDuplicateExtraCount), systemImage: "square.on.square")
              .font(.subheadline).padding(12).frame(maxWidth: .infinity)
              .background(.regularMaterial)
          }
          .accessibilityIdentifier("home.exactDuplicatesBanner")
        }
      }
    }
    .sheet(isPresented: $showingProfileConflicts) {
      NavigationStack {
        DeviceProfilesView().toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(L10n.string("close", table: "Common")) { showingProfileConflicts = false }
          }
        }
      }
    }
    .sheet(isPresented: $showingExactDuplicates) {
      NavigationStack {
        ExactDuplicatesReviewView(onClose: { showingExactDuplicates = false })
      }
      .environmentObject(dataStore)
    }
    .onAppear {
      let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
      print("[Performance] MainTabView.body構築完了: \(String(format: "%.2f", elapsed))ms")

      // 初回起動時にチュートリアルを表示（データがない場合のみ）
      let hasRecords = !dataStore.recordsDescending.isEmpty
      scanExactDuplicates(in: dataStore.recordsDescending, duplicatesAllowed: appSettings.allowDuplicateRecords)

      if !appSettings.hasCompletedTutorial {
        if hasRecords {
          // データが既に存在する場合はチュートリアルをスキップし、完了済みにする
          appSettings.hasCompletedTutorial = true
          checkAndShowDiscordAnnouncement()
        } else {
          // データがない場合のみチュートリアルを表示
          showingTutorial = true
        }
      } else {
        // チュートリアル完了済みの場合、アップデート後のDiscord案内をチェック
        checkAndShowDiscordAnnouncement()
      }
    }
    .onReceive(dataStore.$recordsDescending) { newRecords in
      scanExactDuplicates(in: newRecords, duplicatesAllowed: appSettings.allowDuplicateRecords)
    }
    .onReceive(appSettings.$allowDuplicateRecords.removeDuplicates()) { duplicatesAllowed in
      scanExactDuplicates(in: dataStore.recordsDescending, duplicatesAllowed: duplicatesAllowed)
    }
    .onChange(of: selectedTab) { newValue in
      print("[Performance] タブ切り替え: -> \(newValue.rawValue)")
    }
    .sheet(isPresented: $showingTutorial) {
      TutorialView()
    }
    .sheet(isPresented: $showingDiscordAnnouncement) {
      DiscordAnnouncementView()
    }
    // AppSettings.selectedTabIndexの変更を監視してselectedTabに反映
    .onReceive(appSettings.$selectedTabIndex.removeDuplicates()) { newValue in
      if let newTab = AppTab(rawValue: newValue), newTab != selectedTab {
        selectedTab = newTab
      }
    }
    .onReceive(appSettings.$accentColor.removeDuplicates()) { newValue in
      accentColor = newValue
    }
    // selectedTabの変更をselectedTabIndexに反映
    .onChange(of: selectedTab) { newValue in
      if appSettings.selectedTabIndex != newValue.rawValue {
        appSettings.selectedTabIndex = newValue.rawValue
      }
    }
  }

  private func scanExactDuplicates(in records: [BatteryRecord], duplicatesAllowed: Bool) {
    exactDuplicateExtraCount = duplicatesAllowed ? 0 :
      ExactDuplicateRecords.groups(in: records).reduce(0) { $0 + $1.extraCount }
  }

  // MARK: - iOS 18+ sidebarAdaptable スタイル
  @available(iOS 18.0, *)
  private var modernTabView: some View {
    TabView(selection: $selectedTab) {
      Tab(AppTab.home.title, systemImage: AppTab.home.icon, value: .home) {
        HomeView()
      }
      Tab(AppTab.analytics.title, systemImage: AppTab.analytics.icon, value: .analytics) {
        AnalyticsView()
      }
      Tab(AppTab.settings.title, systemImage: AppTab.settings.icon, value: .settings) {
        SettingsView()
      }
    }
    .tabViewStyle(.sidebarAdaptable)
    .tint(accentColor.color)
  }

  // MARK: - iOS 17以下 iPad用 NavigationSplitView

  /// List(selection:) 用のオプショナルバインディング
  private var sidebarSelection: Binding<AppTab?> {
    Binding<AppTab?>(
      get: { selectedTab },
      set: { if let tab = $0 { selectedTab = tab } }
    )
  }

  private var legacySplitView: some View {
    NavigationSplitView {
      // List(selection:) を使って NavigationSplitView と正しく連携する
      // onTapGesture だと NavigationSplitView の内部選択状態と乖離し、
      // 設定画面訪問後に detail が切り替わらなくなる問題が発生する
      List(selection: sidebarSelection) {
        ForEach(AppTab.allCases) { tab in
          Label(tab.title, systemImage: tab.icon)
            .tag(tab)
        }
      }
      .navigationTitle("MochiLog")
      .listStyle(.sidebar)
    } detail: {
      // .id(selectedTab) でタブ切り替え時にビューを強制再生成し、
      // 前のタブの NavigationStack 状態が残留するのを防ぐ
      Group {
        switch selectedTab {
        case .home:
          HomeView()
        case .analytics:
          AnalyticsView()
        case .settings:
          SettingsView()
        }
      }
      .id(selectedTab)
    }
    .tint(accentColor.color)
  }

  // MARK: - iOS 17以下 iPhone用 TabView
  private var legacyTabView: some View {
    TabView(selection: $selectedTab) {
      HomeView()
        .tabItem {
          Label(AppTab.home.title, systemImage: AppTab.home.icon)
        }
        .tag(AppTab.home)
      AnalyticsView()
        .tabItem {
          Label(AppTab.analytics.title, systemImage: AppTab.analytics.icon)
        }
        .tag(AppTab.analytics)
      SettingsView()
        .tabItem {
          Label(AppTab.settings.title, systemImage: AppTab.settings.icon)
        }
        .tag(AppTab.settings)
    }
    .tint(accentColor.color)
  }

  // MARK: - Helper Methods

  /// アップデート検知：前回起動時のバージョンと現在のバージョンを比較し、Discord案内を表示
  private func checkAndShowDiscordAnnouncement() {
    guard let currentVersion = AppSettings.currentAppVersion else {
      return
    }

    let lastVersion = appSettings.lastSeenVersion

    // 初回起動（lastVersion == nil）の場合は表示しない
    // アップデート時（lastVersion != nil かつ 2.1.0以下 -> 現在のバージョン）の場合のみ表示
    if let lastVersion = lastVersion, lastVersion != currentVersion {
      // 2.1.0以下からのアップデートかチェック
      if compareVersion(lastVersion, lessThanOrEqual: "2.1.0") {
        print("[MainTabView] アップデート検知（2.1.0以下から）: \(lastVersion) -> \(currentVersion)")
        showingDiscordAnnouncement = true
      }
      // バージョンを更新（次回以降は表示しない）
      appSettings.lastSeenVersion = currentVersion
    } else if lastVersion == nil {
      // 初回起動時はバージョンを記録するだけ（チュートリアル後なので通常ここには来ない）
      appSettings.lastSeenVersion = currentVersion
    }
  }

  /// バージョン番号を比較する
  /// - Parameters:
  ///   - version: 比較元のバージョン（例: "2.0.5"）
  ///   - target: 比較対象のバージョン（例: "2.1.0"）
  /// - Returns: version <= target の場合 true
  private func compareVersion(_ version: String, lessThanOrEqual target: String) -> Bool {
    let versionComponents = version.split(separator: ".").compactMap { Int($0) }
    let targetComponents = target.split(separator: ".").compactMap { Int($0) }

    // 配列の長さを揃える
    let maxLength = max(versionComponents.count, targetComponents.count)
    let v = versionComponents + Array(repeating: 0, count: maxLength - versionComponents.count)
    let t = targetComponents + Array(repeating: 0, count: maxLength - targetComponents.count)

    // 各要素を比較
    for i in 0..<maxLength {
      if v[i] < t[i] {
        return true
      } else if v[i] > t[i] {
        return false
      }
    }

    // 完全に一致した場合も true（以下）
    return true
  }
}

// MARK: - DataStoreレコード監視（MainTabViewの再描画抑制用）
private struct RecordsObserverView: View {
  @EnvironmentObject private var dataStore: DataStore

  var body: some View {
    Color.clear
      .frame(width: 0, height: 0)
      .allowsHitTesting(false)
  }
}

// MARK: - ホームビュー本体
struct HomeView: View {
  @EnvironmentObject var dataStore: DataStore
  @Environment(\.horizontalSizeClass) var horizontalSizeClass
  let appSettings = AppSettings.shared

  /// DataStoreからレコードを取得（キャッシュ済み）
  var records: [BatteryRecord] {
    dataStore.recordsDescending
  }

  @State private var showingFilePicker = false
  @State var showingErrorAlert = false
  @State var errorMessage = ""
  @State var selectedRecord: BatteryRecord?
  /// iPadでナビゲーションによる詳細表示に使用する
  @State var navigatingRecord: BatteryRecord?
  @State var pendingParseResult: LogParser.ParseResult?
  @State var pendingSourcePhysicalDeviceID: UUID?
  @State var showingWatchSelection = false
  @State var isProcessing = false
  @State var showingMismatchAlert = false
  @State private var showingManualDevicePicker = false
  @State var showingMagSafeSelection = false

  // MARK: - バッチインポート（共有メニューからの複数ファイル処理）用
  /// バッチ処理の結果（リアルタイム更新対象）
  @ObservedObject private var sharedImports = SharedImportQueue.shared
  var batchImportResults: [FileImportResult] {
    get { sharedImports.results }
    nonmutating set { sharedImports.results = newValue }
  }
  /// バッチ結果シートの表示フラグ
  @State var showingBatchResults = false
  @State var pendingBatchReview: PendingBatchReview?
  @State private var showingRegisterWatchAlert = false
  @State private var watchNameToRegister = ""
  @State private var showingParseErrorSavedAlert = false
  @State private var showingDebugLogsSheet = false
  @State private var showingReorderSheet = false
  @State private var showingTutorial = false

  // デバイス手動選択モード用
  @State var showingDeviceSelectionFromRegistered = false
  @State var showingDeviceSelectionFullList = false

  @State private var showingSampleData = AppSettings.shared.showingSampleData
  @State private var showPopupOnLoad = AppSettings.shared.showPopupOnLoad
  @State private var registeredWatches = AppSettings.shared.registeredWatches
  @State private var allowDuplicateRecords = AppSettings.shared.allowDuplicateRecords

  @State private var viewportHeight: CGFloat = 0

  // デバッグ用：このHomeViewインスタンスを識別するID
  private let instanceID = UUID()

  /// 処理済みのログハッシュとタイムスタンプ（複数インスタンスで共有）
  private static var lastProcessedLogHash: Int?
  private static var lastProcessedTime: Date?

  /// 直近に追加されたログのキャッシュ（ログ日時: 追加時刻）。
  /// SwiftDataの反映ラグによる多重追加を防ぐために使用。
  static var recentlyAddedLogs: [String: Date] = [:]

  /// 現在処理中のcontentHash（複数のHomeViewインスタンスでの重複処理を防ぐ）
  static var processingContentHashes: Set<Int> = []
  static var processingLock = NSLock()

  var body: some View {
    let startTime = CFAbsoluteTimeGetCurrent()
    let _ = print("[Performance] HomeView.body構築開始")

    NavigationStack {
      ZStack {
        homeContent
        processingOverlay
      }
      .navigationTitle("MochiLog")
      .toolbar {
        if !records.isEmpty || showingSampleData {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showingReorderSheet = true }) {
              Image(systemName: "arrow.up.arrow.down")
            }
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: { showingFilePicker = true }) {
            Image(systemName: "plus")
          }
          .disabled(isProcessing)
        }
      }
      .sheet(isPresented: $showingReorderSheet) {
        DeviceReorderView(
          items: showingSampleData
            ? SampleDataProvider.sampleDeviceNames
            : Array(Set(records.map { $0.deviceName })).sorted(),
          onSave: { newOrder in
            appSettings.deviceSortOrder = newOrder
          }
        )
      }
      .fileImporter(
        isPresented: $showingFilePicker,
        allowedContentTypes: [
          .json,
          .plainText,
          .data,
          .folder,
          UTType(filenameExtension: "zip")!,
          UTType(filenameExtension: "ips")!,
          UTType(filenameExtension: "synced")!,  // .ips.ca.synced ファイル用
        ],
        allowsMultipleSelection: true
      ) { result in
        Task {
          await handleFileImport(result: result)
        }
      }
      .alert(L10n.string("error", table: "Common"), isPresented: $showingErrorAlert) {
        Button(L10n.string("ok", table: "Common"), role: .cancel) {}
      } message: {
        Text(errorMessage)
      }
      .sheet(item: $selectedRecord) { record in
        NavigationStack {
          RecordDetailView(record: record, showsCloseButton: true)
        }
      }
      .navigationDestination(
        isPresented: Binding(
          get: { navigatingRecord != nil },
          set: { if !$0 { navigatingRecord = nil } }
        )
      ) {
        if let record = navigatingRecord {
          RecordDetailView(record: record)
        }
      }
      .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProcessSharedLog")))
      {
        notification in
        // 通知のuserInfoから直接テキストを取得
        guard let text = notification.userInfo?["text"] as? String, !text.isEmpty else {
          print("[HomeView] Skipping notification (no text)")
          // 空の通知の場合も処理フラグをリセット
          NotificationCenter.default.post(
            name: NSNotification.Name("SharedLogProcessingCompleted"),
            object: nil
          )
          return
        }

        // Determine whether we should process silently (don't show UI)
        let silent = (notification.userInfo?["silent"] as? Bool) ?? false
        let contentHash = notification.userInfo?["contentHash"] as? Int

        // 複数のHomeViewインスタンスでの重複処理を防ぐ
        if let hash = contentHash {
          HomeView.processingLock.lock()
          let isAlreadyProcessing = HomeView.processingContentHashes.contains(hash)
          if !isAlreadyProcessing {
            HomeView.processingContentHashes.insert(hash)
          }
          HomeView.processingLock.unlock()

          if isAlreadyProcessing {
            print(
              "[HomeView] Instance \(instanceID) skipping duplicate processing for hash: \(hash)")
            return
          }

          // 10秒後に自動的にクリーンアップ（処理が失敗した場合のフェイルセーフ）
          DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            HomeView.processingLock.lock()
            HomeView.processingContentHashes.remove(hash)
            HomeView.processingLock.unlock()
          }
        }

        print(
          "[HomeView] Instance \(instanceID) processing shared log, silent=\(silent), hash=\(String(describing: contentHash))"
        )
        processLogTextAsync(text, silent: silent, contentHash: contentHash)
      }
      .task { await consumeSharedImports() }
      .onReceive(sharedImports.$revision) { _ in
        Task { await consumeSharedImports() }
      }
      .onReceive(
        NotificationCenter.default.publisher(for: NSNotification.Name("ShowRecordDetail"))
      ) { notification in
        print("[HomeView] Instance \(instanceID) received ShowRecordDetail notification")
        guard let logDate = notification.userInfo?["logDate"] as? Date,
          let deviceName = notification.userInfo?["deviceName"] as? String
        else {
          return
        }

        // recordsから該当するレコードを検索
        if let record = records.first(where: {
          $0.deviceName == deviceName && abs($0.logDate.timeIntervalSince(logDate)) < 1.0
        }) {
          print("[HomeView] Instance \(instanceID) showing detail for \(deviceName)")
          showRecordDetail(record)
        } else {
          print("[HomeView] Instance \(instanceID) record not found yet, waiting...")
        }
      }
      .onReceive(
        NotificationCenter.default.publisher(for: NSNotification.Name("ShowImportError"))
      ) { notification in
        if let error = notification.userInfo?["errorMessage"] as? String {
          errorMessage = error
          showingErrorAlert = true
        }
      }
      .onReceive(
        NotificationCenter.default.publisher(for: NSNotification.Name("DeleteAllDataPerformed"))
      ) { _ in
        // Clear transient UI and pending state when all data is removed
        pendingParseResult = nil
        selectedRecord = nil
        showingMismatchAlert = false
        showingWatchSelection = false
        showingManualDevicePicker = false
        showingRegisterWatchAlert = false
        showingDeviceSelectionFromRegistered = false
        showingDeviceSelectionFullList = false
      }
      .onReceive(
        NotificationCenter.default.publisher(for: NSNotification.Name("ParseErrorSaved"))
      ) {
        _ in
        // デバッグログ表示設定がオンの場合のみアラートを表示
        if showPopupOnLoad {
          showingParseErrorSavedAlert = true
        }
      }
      .alert(
        L10n.string("log_saved", table: "Home"), isPresented: $showingParseErrorSavedAlert
      ) {
        Button(L10n.string("view_log", table: "Records")) {
          // アラートが閉じた後にシートを開く
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingDebugLogsSheet = true
          }
        }
        Button(L10n.string("ok", table: "Common"), role: .cancel) {}
      } message: {
        Text(L10n.string("log_saved_message", table: "Home"))
      }
      .sheet(isPresented: $showingDebugLogsSheet) {
        DebugLogsView()
      }
      .sheet(isPresented: $showingTutorial) {
        TutorialView()
      }
      .onAppear {
        let bodyElapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("[Performance] HomeView.body構築完了: \(String(format: "%.2f", bodyElapsed))ms")
        print("[Performance] HomeView.onAppear開始")

        reconcileUnknownDeviceNames()
        reconcileMissingDesignCapacities()
        // UserDefaultsフォールバックは廃止（MochiLogAppから直接Notificationが送信される）

        // Apple WatchにデータをNシンク
        syncRecordsToWatch()
      }
      .onChange(of: records.count) { _ in
        // レコード数が変更されたらWatchに同期
        syncRecordsToWatch()
      }
      .onReceive(dataStore.$recordsDescending) { updatedRecords in
        finishBatchReviewIfSaved(in: updatedRecords)
      }
      .onChange(of: showingSampleData) { newValue in
        // サンプルモードが変更されたらWatchに同期
        syncRecordsToWatch()

        if appSettings.showingSampleData != newValue {
          appSettings.showingSampleData = newValue
        }
      }
      .onReceive(appSettings.$showingSampleData.removeDuplicates()) { newValue in
        if showingSampleData != newValue {
          showingSampleData = newValue
        }
      }
      .onReceive(appSettings.$showPopupOnLoad.removeDuplicates()) { newValue in
        if showPopupOnLoad != newValue {
          showPopupOnLoad = newValue
        }
      }
      .onReceive(appSettings.$registeredWatches.removeDuplicates()) { newValue in
        if registeredWatches != newValue {
          registeredWatches = newValue
        }
      }
      .onReceive(appSettings.$allowDuplicateRecords.removeDuplicates()) { newValue in
        if allowDuplicateRecords != newValue {
          allowDuplicateRecords = newValue
        }
      }
      .sheet(isPresented: $showingWatchSelection) {
        // 登録済みWatchがある場合は登録済みリストから選択
        // ない場合は全Watchモデルから選択
        if registeredWatches.isEmpty {
          HierarchicalDevicePickerView(initialCategory: .watch, lockCategory: true) {
            name, identifier in
            guard let result = pendingParseResult else { return }
            let record = createRecord(
              from: result,
              deviceName: name,
              deviceModelCodeOverride: identifier,
              designCapacityOverride: DeviceLibrary.getCapacity(for: name)
            )
            record.physicalDeviceID = pendingSourcePhysicalDeviceID
            withAnimation(.snappy) {
              dataStore.insert(record)
            }
            // 保存はアニメーション外で行う
            Task.detached(priority: .userInitiated) {
              await MainActor.run {
                self.dataStore.save()
              }
            }
            selectedRecord = nil
            pendingParseResult = nil
            pendingSourcePhysicalDeviceID = nil

            // 初回登録を提案
            watchNameToRegister = name
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
              showingRegisterWatchAlert = true
            }
          }
        } else {
          RegisteredWatchSelectSheet { selectedWatch in
            guard let result = pendingParseResult else { return }
            let logDate = result.logDate ?? Date()

            // 重複チェック
            if !allowDuplicateRecords,
              hasDuplicateRecord(on: logDate, deviceName: selectedWatch,
                physicalDeviceID: pendingSourcePhysicalDeviceID)
            {
              DispatchQueue.main.async {
                NotificationCenter.default.post(
                  name: NSNotification.Name("ShowImportError"),
                  object: nil,
                  userInfo: ["errorMessage": L10n.string("duplicate_record", table: "Home")]
                )
              }
              selectedRecord = nil
              pendingParseResult = nil
              pendingSourcePhysicalDeviceID = nil
              return
            }

            let identifier = DeviceLibrary.getIdentifierForDeviceName(selectedWatch)
            let record = createRecord(
              from: result,
              deviceName: selectedWatch,
              deviceModelCodeOverride: identifier,
              designCapacityOverride: DeviceLibrary.getCapacity(for: selectedWatch)
            )
            record.physicalDeviceID = pendingSourcePhysicalDeviceID
            withAnimation(.snappy) {
              dataStore.insert(record)
            }
            // 保存はアニメーション外で行う
            Task.detached(priority: .userInitiated) {
              await MainActor.run {
                self.dataStore.save()
              }
            }
            selectedRecord = nil
            pendingParseResult = nil
            pendingSourcePhysicalDeviceID = nil
          }
        }
      }
      .alert(
        L10n.string("register_watch_title", table: "Settings"),
        isPresented: $showingRegisterWatchAlert
      ) {
        Button(L10n.string("register", table: "Common")) {
          appSettings.registerWatch(model: watchNameToRegister)
        }
        Button(L10n.string("cancel", table: "Common"), role: .cancel) {}
      } message: {
        Text(L10n.string("register_watch_message", table: "Settings"))
      }
      .alert(
        L10n.string("mismatch_warning_title", table: "Home"),
        isPresented: $showingMismatchAlert
      ) {
        Button(L10n.string("select_manually", table: "Home")) {
          showingManualDevicePicker = true
        }
        Button(L10n.string("cancel", table: "Common"), role: .cancel) {
          pendingParseResult = nil
        }
      } message: {
        Text(L10n.string("mismatch_warning_message", table: "Home"))
      }
      .alert(
        "デバイスの選択",
        isPresented: $showingMagSafeSelection
      ) {
        Button("iPhone Air") {
          completeRecordWithSelectedDevice(name: "iPhone Air", identifier: "iPhone18,4")
        }
        Button("iPhone Air MagSafeバッテリー") {
          completeRecordWithSelectedDevice(name: "iPhone Air MagSafeバッテリー", identifier: "A3385")
        }
        Button(L10n.string("cancel", table: "Common"), role: .cancel) {
          pendingParseResult = nil
        }
      } message: {
        Text("このログはiPhone Airのものですか、それともiPhone Air MagSafeバッテリーのものですか？")
      }
      .sheet(isPresented: $showingManualDevicePicker) {
        HierarchicalDevicePickerView { name, identifier in
          guard let result = pendingParseResult else { return }
          let record = createRecord(
            from: result,
            deviceName: name,
            deviceModelCodeOverride: identifier,
            designCapacityOverride: DeviceLibrary.getCapacity(for: name)
          )
          record.physicalDeviceID = pendingSourcePhysicalDeviceID
          withAnimation(.snappy) {
            dataStore.insert(record)
          }
          // 保存はアニメーション外で行う
          Task.detached(priority: .userInitiated) {
            await MainActor.run {
              self.dataStore.save()
            }
          }
          selectedRecord = nil
          pendingParseResult = nil
          pendingSourcePhysicalDeviceID = nil

          if name.contains("Apple Watch") && registeredWatches.isEmpty {
            watchNameToRegister = name
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
              showingRegisterWatchAlert = true
            }
          }
        }
      }
      // MARK: - デバイス手動選択モード用シート
      .sheet(isPresented: $showingDeviceSelectionFromRegistered) {
        // 登録済みデバイスから選択
        RegisteredDeviceSelectSheet { selectedDevice in
          completeRecordWithSelectedDevice(
            name: selectedDevice,
            identifier: DeviceLibrary.getIdentifierForDeviceName(selectedDevice)
          )
        }
      }
      .sheet(isPresented: $showingDeviceSelectionFullList) {
        // 全端末リストから選択（iPhone/iPadのみ）
        HierarchicalDevicePickerView(allowedCategories: [.iphone, .ipad]) { name, identifier in
          completeRecordWithSelectedDevice(name: name, identifier: identifier)
        }
      }
      // MARK: - バッチインポート結果シート
      .sheet(isPresented: $showingBatchResults) {
        BatchImportResultView(results: $sharedImports.results) { result in
          // 1. シートを閉じる
          showingBatchResults = false

          // 2. 少し待ってから、選択されたファイルの手動インポートを開始
          if let text = result.rawText {
            if let sourceURL = result.sourceURL, let signature = result.reviewSignature {
              pendingBatchReview = PendingBatchReview(sourceURL: sourceURL,
                signature: signature, existingRecordIDs: Set(records.map(\.id)))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
              processLogTextAsync(text, silent: false, contentHash: text.hashValue,
                physicalDeviceID: result.physicalDeviceID)
            }
          }
        } onDismiss: {
          showingBatchResults = false
        }
      }
    }
  }

  @ViewBuilder
  private var homeContent: some View {
    if showingSampleData {
      SampleDataHomeView(
        showingSampleData: $showingSampleData,
        onRecordTap: { record in
          showRecordDetail(record)
        },
        openFilePicker: {
          showingFilePicker = true
        })
    } else if !records.isEmpty {
      RecordListView(
        records: records,
        onRecordTap: { record in
          showRecordDetail(record)
        },
        onRecordDelete: { record in
          deleteRecords([record])
        },
        showContextMenu: true
      )
    } else {
      noDataView
    }
  }

  private var noDataView: some View {
    GeometryReader { geo in
      ScrollView {
        VStack(spacing: 12) {
          Image(systemName: "battery.0")
            .font(.system(size: 48))
            .foregroundColor(.secondary)
          Text(L10n.string("no_data", table: "Home"))
            .font(.title2)
            .fontWeight(.semibold)
          Text(L10n.string("no_data_description", table: "Home"))
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
          VStack(spacing: 12) {
            Button {
              showingTutorial = true
            } label: {
              Label(L10n.string("view_tutorial", table: "Home"), systemImage: "play.circle")
            }
            .buttonStyle(.bordered)

            Button {
              withAnimation { showingSampleData = true }
            } label: {
              Label(L10n.string("view_sample_data", table: "Home"), systemImage: "eye")
            }
            .buttonStyle(.borderedProminent)
          }
        }
        .frame(maxWidth: .infinity)
        // 「実スクロール」を作らないため、viewportより 1pt 小さくする
        .frame(minHeight: max(0, viewportHeight - 1))
      }
      .modifier(ScrollBounceBehaviorModifier())
      .onAppear {
        viewportHeight = geo.size.height
      }
      .onChange(of: geo.size.height) { newValue in
        // 回転など「大きい変化」だけ追従。Large Title の伸縮由来の揺れは無視。
        if abs(newValue - viewportHeight) > 80 {
          viewportHeight = newValue
        }
      }
    }
  }

  @ViewBuilder
  private var processingOverlay: some View {
    if isProcessing {
      Color.black.opacity(0.3)
        .ignoresSafeArea()
      VStack(spacing: 16) {
        ProgressView()
          .scaleEffect(1.5)
          .tint(.white)
        Text(L10n.string("parsing_log", table: "Home"))
          .font(.headline)
          .foregroundColor(.white)
      }
      .padding(32)
      .mochiLoadingSurface()
    }
  }
}
