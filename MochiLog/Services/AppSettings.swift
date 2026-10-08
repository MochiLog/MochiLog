import CloudKit
import Combine
import Foundation
import SwiftUI

/// アプリ全体の設定を管理するクラス
final class AppSettings: ObservableObject {
  static let shared = AppSettings()

  // MARK: - UserDefaults Keys
  enum Keys {
    static let registeredWatchModel = "registeredWatchModel"
    static let registeredWatches = "registeredWatches"
    static let hasCompletedTutorial = "hasCompletedTutorial"
    static let enableCapacityValidation = "enableCapacityValidation"
    static let capacityValidationThreshold = "capacityValidationThreshold"
    static let mismatchBehavior = "mismatchBehavior"

    // 新規: チャートとiCloud設定
    static let defaultChartUnit = "defaultChartUnit"
    static let iCloudSyncEnabled = "iCloudSyncEnabled"
    static let iCloudStorageThresholdMB = "iCloudStorageThresholdMB"
    static let lastICloudSyncDate = "lastICloudSyncDate"
    static let accentColor = "accentColor"
    static let showPopupOnLoad = "showPopupOnLoad"

    // 新規: 共有インポート時にアプリを開くかどうか
    static let openAppAfterShareImport = "openAppAfterShareImport"

    // 新規: デバイスの並び順
    static let deviceSortOrder = "deviceSortOrder"

    // 新規: 分析データの計算基準
    static let analysisDataSource = "analysisDataSource"

    // 新規: 重複ログ記録を許可
    static let allowDuplicateRecords = "allowDuplicateRecords"

    // 新規: 選択されたチャートレンジ
    static let selectedChartRange = "selectedChartRange"

    // 新規: ショートカット関連
    static let isShortcutInstalled = "isShortcutInstalled"

    // 新規: バージョン管理（マイグレーションと統一）
    static let lastSeenVersion = "LastKnownAppVersion"  // マイグレーションと同じキーを使用

    // 新規: 開発者オプションの表示状態
    static let showingDeveloperOptions = "showingDeveloperOptions"

    // 新規: デバイス選択モード
    static let deviceSelectionMode = "deviceSelectionMode"
    static let registeredDevices = "registeredDevices"

    // 新規: MagSafeバッテリー自動選択
    static let autoSelectMagSafeBattery = "autoSelectMagSafeBattery"

    // 新規: デバイス識別子の上書き（開発者用）
    static let overrideLocalModelIdentifier = "overrideLocalModelIdentifier"
  }

  // MARK: - Constants

  /// DiscordサーバーのURL
  static let discordURL = "https://discord.gg/fbdmX7EHKA"

  /// 現在のアプリバージョンを取得
  static var currentAppVersion: String? {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
  }

  /// iPhone/iPadのデバイス選択モード
  enum DeviceSelectionMode: String, CaseIterable, Identifiable {
    case automatic = "automatic"
    case preRegistered = "preRegistered"
    case fullManual = "fullManual"

    var id: String { self.rawValue }

    var localizedName: String {
      switch self {
      case .automatic: return L10n.string("device_mode_automatic", table: "Settings")
      case .preRegistered: return L10n.string("device_mode_pre_registered", table: "Settings")
      case .fullManual: return L10n.string("device_mode_full_manual", table: "Settings")
      }
    }

    var description: String {
      switch self {
      case .automatic: return L10n.string("device_mode_automatic_desc", table: "Settings")
      case .preRegistered:
        return L10n.string("device_mode_pre_registered_desc", table: "Settings")
      case .fullManual: return L10n.string("device_mode_full_manual_desc", table: "Settings")
      }
    }

    var iconName: String {
      switch self {
      case .automatic: return "iphone.gen3"
      case .preRegistered: return "star.fill"
      case .fullManual: return "list.bullet"
      }
    }
  }

  /// 容量不一致時の挙動
  enum MismatchBehavior: String, CaseIterable, Identifiable {
    case manualSelection = "manualSelection"
    case error = "error"

    var id: String { self.rawValue }

    var localizedName: String {
      switch self {
      case .manualSelection: return L10n.string("mismatch_behavior_manual", table: "Settings")
      case .error: return L10n.string("mismatch_behavior_error", table: "Settings")
      }
    }
  }

  /// 分析データの計算基準
  enum AnalysisDataSource: String, CaseIterable, Identifiable {
    case actual = "actual"
    case nominal = "nominal"

    var id: String { self.rawValue }

    var localizedName: String {
      switch self {
      case .actual: return L10n.string("analysis_source_actual", table: "Settings")
      case .nominal: return L10n.string("analysis_source_nominal", table: "Settings")
      }
    }
  }

  /// チャートで利用する単位
  enum ChartUnit: String, CaseIterable, Identifiable {
    case hour
    case day
    case week
    case month

    var id: String { self.rawValue }

    var localizedName: String {
      switch self {
      case .hour: return L10n.string("chart_unit_hour", table: "Analytics")
      case .day: return L10n.string("chart_unit_day", table: "Analytics")
      case .week: return L10n.string("chart_unit_week", table: "Analytics")
      case .month: return L10n.string("chart_unit_month", table: "Analytics")
      }
    }

    var calendarComponent: Calendar.Component {
      switch self {
      case .hour: return .hour
      case .day: return .day
      case .week: return .weekOfYear
      case .month: return .month
      }
    }
  }

  /// アプリのアクセントカラー（テーマ色）
  enum ThemeColor: String, CaseIterable, Identifiable {
    case green
    case blue
    case orange
    case purple

    var id: String { self.rawValue }

    var localizedName: String {
      switch self {
      case .green: return L10n.string("theme_color_green", table: "Settings")
      case .blue: return L10n.string("theme_color_blue", table: "Settings")
      case .orange: return L10n.string("theme_color_orange", table: "Settings")
      case .purple: return L10n.string("theme_color_purple", table: "Settings")
      }
    }

    var color: Color {
      switch self {
      case .green: return .green
      case .blue: return .blue
      case .orange: return .orange
      case .purple: return .purple
      }
    }
  }

  // MARK: - Published Properties

  /// 登録済みのApple Watchモデル名のリスト
  @Published var registeredWatches: [String] = []

  /// 後方互換性のため: 最初の登録Watchを返す（読み取り専用）
  var registeredWatchModel: String? {
    registeredWatches.first
  }

  /// チュートリアル完了済みフラグ
  @Published var hasCompletedTutorial: Bool

  /// バッテリー容量のバリデーションを有効にするか
  @Published var enableCapacityValidation: Bool

  /// バッテリー容量バリデーションの閾値（倍率）
  @Published var capacityValidationThreshold: Double

  /// 容量不一致時の挙動
  @Published var mismatchBehavior: MismatchBehavior

  /// デフォルトのチャート単位
  @Published var defaultChartUnit: ChartUnit

  /// iCloud同期を有効にするか（設定）
  @Published var iCloudSyncEnabled: Bool

  /// iCloud同期を抑制するための容量閾値（MB）
  @Published var iCloudStorageThresholdMB: Double

  /// 最後に同期（強制同期など）を行った日時（timeIntervalSince1970）
  @Published var lastICloudSyncDate: Double

  /// iCloud 同期がブロックされた際の説明（ユーザ表示用）
  @Published var iCloudSyncBlockedReason: String?

  /// 読み込み後すぐにポップアップを表示するか
  @Published var showPopupOnLoad: Bool

  /// 共有インポート時にアプリを開くかどうか（true = 開く、false = 開かない）
  @Published var openAppAfterShareImport: Bool

  /// アプリのアクセント（テーマ）カラー
  @Published var accentColor: ThemeColor

  /// セッション内（アプリ再起動まで）にチャートのレンジ初期化を自動で行ったかどうか
  /// - 注意: 永続化しない。一度 true になるとアプリが再起動するまで上書きしない（ユーザーの選択を尊重するため）
  @Published var hasAutoInitializedChartRange: Bool = false

  /// サンプルデータ表示モード（タブ間で共有、非永続化）
  @Published var showingSampleData: Bool = false

  /// 選択されているタブのインデックス（0: Home, 1: Analytics, 2: Settings）
  /// 選択されているタブのインデックス（0: Home, 1: Analytics, 2: Settings）
  @Published var selectedTabIndex: Int = 0

  @Published var pcAutomaticCollectionEnabled = UserDefaults.standard.object(forKey: "pcAutomaticCollectionEnabled") as? Bool ?? true {
    didSet {
      UserDefaults.standard.set(pcAutomaticCollectionEnabled, forKey: "pcAutomaticCollectionEnabled")
      if #available(iOS 27, *) {
        if pcAutomaticCollectionEnabled { MacTransferManager.shared.start() }
        else { MacTransferManager.shared.stopForBackground() }
      }
    }
  }
  @Published var localAutomaticCollectionEnabled = UserDefaults.standard.bool(forKey: "localAutomaticCollectionEnabled") {
    didSet {
      UserDefaults.standard.set(localAutomaticCollectionEnabled, forKey: "localAutomaticCollectionEnabled")
      if #available(iOS 27, *) { LocalDiagnosticsManager.shared.updateActivity() }
    }
  }

  @Published var liveBatteryEnabled = UserDefaults.standard.bool(forKey: "liveBatteryEnabled") {
    didSet {
      UserDefaults.standard.set(liveBatteryEnabled, forKey: "liveBatteryEnabled")
      if !liveBatteryEnabled && selectedTabIndex == 3 { selectedTabIndex = 0 }
      if #available(iOS 27, *) { LiveBatteryManager.shared.updateActivity(); LocalDiagnosticsManager.shared.updateActivity() }
    }
  }


  /// デバイスの並び順（名前の配列）
  @Published var deviceSortOrder: [String] = []

  /// 分析データの計算基準
  @Published var analysisDataSource: AnalysisDataSource

  /// 重複したログの記録を許可するかどうか
  @Published var allowDuplicateRecords: Bool

  /// 選択されたチャートレンジ（nil = 自動選択）
  @Published var selectedChartRange: String?

  /// ショートカット「解析データを開く」がインストール済みかどうか
  @Published var isShortcutInstalled: Bool

  /// 最後に確認したアプリバージョン（アップデート検知用）
  @Published var lastSeenVersion: String?
  @Published var showingDeveloperOptions: Bool

  /// iPhone/iPadのデバイス選択モード
  @Published var deviceSelectionMode: DeviceSelectionMode

  /// 登録済みのiPhone/iPadデバイス名のリスト（preRegisteredモード用）
  @Published var registeredDevices: [String] = []

  /// MagSafeバッテリーの自動選択
  @Published var autoSelectMagSafeBattery: Bool

  // 新規: iCloud設定画面の表示状態（iPhone用）
  @Published var showingICloudSettings: Bool = false

  // 新規: 設定画面の選択カテゴリ（iPad用）
  @Published var selectedSettingsCategory: SettingsCategory = .general

  /// デバイス識別子の上書き（開発者用、空文字の場合はシステム値を使用）
  @Published var overrideLocalModelIdentifier: String

  // MARK: - Initialization

  private init() {
    let releaseVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    let releaseBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    RecordInfoPreferences.prepareForLaunch(release: releaseVersion + "(" + releaseBuild + ")")

    // Watchデータのマイグレーション: 旧形式（単一）から新形式（複数）へ
    if let savedWatches = UserDefaults.standard.stringArray(forKey: Keys.registeredWatches) {
      self.registeredWatches = savedWatches
    } else if let legacyWatch = UserDefaults.standard.string(forKey: Keys.registeredWatchModel) {
      // 旧データをマイグレーション
      self.registeredWatches = [legacyWatch]
      UserDefaults.standard.set([legacyWatch], forKey: Keys.registeredWatches)
    } else {
      self.registeredWatches = []
    }
    self.hasCompletedTutorial = UserDefaults.standard.bool(forKey: Keys.hasCompletedTutorial)

    // デフォルト値の設定
    if UserDefaults.standard.object(forKey: Keys.enableCapacityValidation) == nil {
      self.enableCapacityValidation = true
    } else {
      self.enableCapacityValidation = UserDefaults.standard.bool(
        forKey: Keys.enableCapacityValidation)
    }

    let threshold = UserDefaults.standard.double(forKey: Keys.capacityValidationThreshold)
    self.capacityValidationThreshold = threshold == 0 ? 10.0 : threshold

    if let behaviorString = UserDefaults.standard.string(forKey: Keys.mismatchBehavior),
      let behavior = MismatchBehavior(rawValue: behaviorString)
    {
      self.mismatchBehavior = behavior
    } else {
      self.mismatchBehavior = .manualSelection
    }

    // 新規: チャート単位とiCloud設定の初期値
    if let chartUnitString = UserDefaults.standard.string(forKey: Keys.defaultChartUnit),
      let unit = ChartUnit(rawValue: chartUnitString)
    {
      self.defaultChartUnit = unit
    } else {
      self.defaultChartUnit = .day
    }

    if UserDefaults.standard.object(forKey: Keys.iCloudSyncEnabled) == nil {
      self.iCloudSyncEnabled = false
    } else {
      self.iCloudSyncEnabled = UserDefaults.standard.bool(forKey: Keys.iCloudSyncEnabled)
    }

    let storageThreshold = UserDefaults.standard.double(forKey: Keys.iCloudStorageThresholdMB)
    self.iCloudStorageThresholdMB = storageThreshold == 0 ? 100.0 : storageThreshold

    self.lastICloudSyncDate = UserDefaults.standard.double(forKey: Keys.lastICloudSyncDate)

    // 読み込み後すぐにポップアップを表示するか: デフォルトは false
    if UserDefaults.standard.object(forKey: Keys.showPopupOnLoad) == nil {
      self.showPopupOnLoad = false
    } else {
      self.showPopupOnLoad = UserDefaults.standard.bool(forKey: Keys.showPopupOnLoad)
    }

    // 共有インポート時にアプリを開くかどうか: デフォルトは true
    if UserDefaults.standard.object(forKey: Keys.openAppAfterShareImport) == nil {
      self.openAppAfterShareImport = true
    } else {
      self.openAppAfterShareImport = UserDefaults.standard.bool(
        forKey: Keys.openAppAfterShareImport)
    }

    // アクセントカラー: 永続化された値があれば読み込む
    if let colorString = UserDefaults.standard.string(forKey: Keys.accentColor),
      let theme = ThemeColor(rawValue: colorString)
    {
      self.accentColor = theme
    } else {
      self.accentColor = .green
    }

    // ブロック理由は起動時には空
    self.iCloudSyncBlockedReason = nil

    // デバイス並び順の読み込み
    self.deviceSortOrder = UserDefaults.standard.stringArray(forKey: Keys.deviceSortOrder) ?? []

    // 分析データソースの初期化
    if let sourceString = UserDefaults.standard.string(forKey: Keys.analysisDataSource),
      let source = AnalysisDataSource(rawValue: sourceString)
    {
      self.analysisDataSource = source
    } else {
      self.analysisDataSource = .nominal
    }

    // 重複ログ記録許可の初期化（デフォルトは false）
    self.allowDuplicateRecords = UserDefaults.standard.bool(forKey: Keys.allowDuplicateRecords)

    // チャートレンジの初期化（nil = 自動選択）
    self.selectedChartRange = UserDefaults.standard.string(forKey: Keys.selectedChartRange)

    // ショートカットインストール状態の初期化（デフォルトは false）
    self.isShortcutInstalled = UserDefaults.standard.bool(forKey: Keys.isShortcutInstalled)

    // 最後に確認したバージョンの初期化
    self.lastSeenVersion = UserDefaults.standard.string(forKey: Keys.lastSeenVersion)
    self.showingDeveloperOptions = UserDefaults.standard.bool(forKey: Keys.showingDeveloperOptions)

    // デバイス選択モードの初期化
    if let modeString = UserDefaults.standard.string(forKey: Keys.deviceSelectionMode),
      let mode = DeviceSelectionMode(rawValue: modeString)
    {
      self.deviceSelectionMode = mode
    } else {
      self.deviceSelectionMode = .automatic
    }

    // 登録済みデバイスの読み込み
    self.registeredDevices = UserDefaults.standard.stringArray(forKey: Keys.registeredDevices) ?? []

    // MagSafeバッテリー自動選択の初期化（デフォルトは true: 自動判定）
    if UserDefaults.standard.object(forKey: Keys.autoSelectMagSafeBattery) == nil {
      self.autoSelectMagSafeBattery = true
      UserDefaults.standard.set(true, forKey: Keys.autoSelectMagSafeBattery)
    } else {
      self.autoSelectMagSafeBattery = UserDefaults.standard.bool(forKey: Keys.autoSelectMagSafeBattery)
    }

    // デバイス識別子の上書きの初期化
    self.overrideLocalModelIdentifier = UserDefaults.standard.string(forKey: Keys.overrideLocalModelIdentifier) ?? ""

    // プロパティの変更を監視してUserDefaultsに保存
    setupObservers()

    // 起動時に iCloud 同期が有効な場合は再評価して必要なら無効化する
    if self.iCloudSyncEnabled {
      _ = attemptSetICloudSync(true)
    }
  }

  private var cancellables = Set<AnyCancellable>()

  private func setupObservers() {
    $registeredWatches
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.registeredWatches)
      }
      .store(in: &cancellables)

    $hasCompletedTutorial
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.hasCompletedTutorial)
      }
      .store(in: &cancellables)

    $enableCapacityValidation
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.enableCapacityValidation)
      }
      .store(in: &cancellables)

    $capacityValidationThreshold
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.capacityValidationThreshold)
      }
      .store(in: &cancellables)

    $mismatchBehavior
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value.rawValue, forKey: Keys.mismatchBehavior)
      }
      .store(in: &cancellables)

    // 新規: チャート単位の永続化
    $defaultChartUnit
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value.rawValue, forKey: Keys.defaultChartUnit)
      }
      .store(in: &cancellables)

    // 新規: iCloud 同期設定の永続化・検証
    $iCloudSyncEnabled
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.iCloudSyncEnabled)
        // NOTE: Do NOT call `attemptSetICloudSync` here to avoid re-entrant calls that can
        // lead to infinite recursion (setting the published property from within its own sink).
        // Validation/activation should be triggered explicitly from UI (SettingsView) or during init.
      }
      .store(in: &cancellables)

    $iCloudStorageThresholdMB
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.iCloudStorageThresholdMB)
      }
      .store(in: &cancellables)

    $lastICloudSyncDate
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.lastICloudSyncDate)
      }
      .store(in: &cancellables)

    // Persist show popup on load setting
    $showPopupOnLoad
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.showPopupOnLoad)
      }
      .store(in: &cancellables)

    // Persist 'open app after share import' setting
    $openAppAfterShareImport
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.openAppAfterShareImport)
      }
      .store(in: &cancellables)

    // Persist accent color changes
    $accentColor
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value.rawValue, forKey: Keys.accentColor)
      }
      .store(in: &cancellables)

    $deviceSortOrder
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.deviceSortOrder)
      }
      .store(in: &cancellables)

    $analysisDataSource
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value.rawValue, forKey: Keys.analysisDataSource)
      }
      .store(in: &cancellables)

    $allowDuplicateRecords
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.allowDuplicateRecords)
      }
      .store(in: &cancellables)

    $selectedChartRange
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.selectedChartRange)
      }
      .store(in: &cancellables)

    $isShortcutInstalled
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.isShortcutInstalled)
      }
      .store(in: &cancellables)

    $lastSeenVersion
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.lastSeenVersion)
      }
      .store(in: &cancellables)

    $showingDeveloperOptions
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.showingDeveloperOptions)
      }
      .store(in: &cancellables)

    $deviceSelectionMode
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value.rawValue, forKey: Keys.deviceSelectionMode)
      }
      .store(in: &cancellables)

    $registeredDevices
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.registeredDevices)
      }
      .store(in: &cancellables)

    $autoSelectMagSafeBattery
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.autoSelectMagSafeBattery)
      }
      .store(in: &cancellables)

    $overrideLocalModelIdentifier
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.overrideLocalModelIdentifier)
      }
      .store(in: &cancellables)
  }

  // MARK: - Methods

  /// Apple Watchモデルを登録（配列に追加）
  func registerWatch(model: String) {
    // 重複登録を防止
    guard !registeredWatches.contains(model) else { return }
    registeredWatches.append(model)
  }

  /// 特定のApple Watchを登録解除
  func removeWatch(model: String) {
    registeredWatches.removeAll { $0 == model }
  }

  /// すべてのApple Watch登録を解除
  func unregisterAllWatches() {
    registeredWatches.removeAll()
  }

  /// 後方互換性のため: 最初のWatchを解除
  @available(*, deprecated, message: "Use removeWatch(model:) instead")
  func unregisterWatch() {
    if !registeredWatches.isEmpty {
      registeredWatches.removeFirst()
    }
  }

  /// iPhone/iPadデバイスを登録（preRegisteredモード用）
  func registerDevice(name: String) {
    guard !registeredDevices.contains(name) else { return }
    registeredDevices.append(name)
  }

  /// 特定のiPhone/iPadデバイスを登録解除
  func removeDevice(name: String) {
    registeredDevices.removeAll { $0 == name }
  }

  /// すべてのiPhone/iPad登録を解除
  func unregisterAllDevices() {
    registeredDevices.removeAll()
  }

  /// チュートリアル完了を記録
  func completeTutorial() {
    hasCompletedTutorial = true
  }

  /// 利用可能なApple Watchモデル一覧を取得
  func availableWatchModels() -> [String] {
    return Array(Set(DeviceLibrary.deviceNames.values))
      .filter { $0.contains("Apple Watch") }
      .sorted()
  }

  /// デバイス情報を取得（サポート問い合わせ用）
  func getDeviceInfo() -> String {
    let device = UIDevice.current
    let appVersion =
      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    let systemVersion = device.systemVersion
    let modelIdentifier = DeviceLibrary.localModelIdentifier() ?? "Unknown"
    let modelName = DeviceLibrary.getDeviceName(for: modelIdentifier) ?? modelIdentifier

    return """
      ---
      デバイス情報 / Device Info:
      アプリバージョン / App Version: \(appVersion) (\(buildNumber))
      iOS バージョン / iOS Version: \(systemVersion)
      デバイス / Device: \(modelName) (\(modelIdentifier))
      言語 / Language: \(Locale.current.language.languageCode?.identifier ?? "Unknown")
      ---
      """
  }

  // MARK: - iCloud / Storage helpers

  /// デバイスの空き容量をMBで取得
  func deviceFreeSpaceMB() -> Double {
    do {
      let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
      if let free = attrs[.systemFreeSize] as? NSNumber {
        return free.doubleValue / 1024.0 / 1024.0
      }
    } catch {
      return 0
    }
    return 0
  }

  /// iCloud 有効化時の失敗理由
  enum ICloudError: LocalizedError {
    case lowSpace(requiredMB: Int)
    case accountNotSignedIn
    case accountRestricted
    case accountTemporarilyUnavailable
    case unknown

    var errorDescription: String? {
      switch self {
      case .lowSpace(let requiredMB):
        return String(
          format: L10n.string("icloud_sync_blocked_low_space", table: "Settings"), requiredMB)
      case .accountNotSignedIn:
        return L10n.string("icloud_account_not_signed_in", table: "Settings")
      case .accountRestricted:
        return L10n.string("icloud_account_restricted", table: "Settings")
      case .accountTemporarilyUnavailable:
        return L10n.string("icloud_account_temporarily_unavailable", table: "Settings")
      case .unknown:
        return L10n.string("icloud_sync_failed", table: "Settings")
      }
    }
  }

  /// iCloud アカウントの状態を非同期でチェック
  private func checkICloudAccountStatus() async -> Result<Void, ICloudError> {
    let container = CKContainer.default()

    do {
      let status = try await container.accountStatus()
      switch status {
      case .available:
        return .success(())
      case .noAccount:
        return .failure(.accountNotSignedIn)
      case .restricted:
        return .failure(.accountRestricted)
      case .temporarilyUnavailable:
        return .failure(.accountTemporarilyUnavailable)
      case .couldNotDetermine:
        return .failure(.unknown)
      @unknown default:
        return .failure(.unknown)
      }
    } catch {
      return .failure(.unknown)
    }
  }

  /// iCloud 同期を有効化する前に容量を評価する。
  func canEnableICloudSync() -> Result<Void, ICloudError> {
    let freeMB = deviceFreeSpaceMB()
    if freeMB < iCloudStorageThresholdMB {
      return .failure(.lowSpace(requiredMB: Int(iCloudStorageThresholdMB)))
    }
    return .success(())
  }

  /// 互換性用: 古い evaluateStorageAndMaybeBlockSync 呼び出しを解決するヘルパー
  private func evaluateStorageAndMaybeBlockSync() {
    _ = attemptSetICloudSync(true)
  }

  /// ユーザーが iCloud 同期を切り替えようとしたときに呼ぶ（非同期版）
  func attemptSetICloudSyncAsync(_ enabled: Bool) async -> Result<Void, ICloudError> {
    // 既に同じ状態なら何もしない
    if iCloudSyncEnabled == enabled { return .success(()) }

    if enabled {
      // 1. アカウント状態をチェック
      let accountResult = await checkICloudAccountStatus()
      if case .failure(let err) = accountResult {
        await MainActor.run {
          iCloudSyncBlockedReason = err.errorDescription
          iCloudSyncEnabled = false
        }
        return .failure(err)
      }

      // 2. 空き容量をチェック
      switch canEnableICloudSync() {
      case .success:
        await MainActor.run {
          iCloudSyncEnabled = true
          iCloudSyncBlockedReason = nil
        }
        // TODO: 実際の iCloud / CloudKit 同期処理の開始
        return .success(())
      case .failure(let err):
        await MainActor.run {
          iCloudSyncBlockedReason = err.errorDescription
          iCloudSyncEnabled = false
        }
        return .failure(err)
      }
    } else {
      // 無効化
      await MainActor.run {
        iCloudSyncEnabled = false
        iCloudSyncBlockedReason = nil
      }
      // TODO: 停止処理
      return .success(())
    }
  }

  /// ユーザーが iCloud 同期を切り替えようとしたときに呼ぶ。失敗時はエラーを返す（UI側でアラート等を表示する）
  /// - Note: 互換性のための同期版。新しいコードではattemptSetICloudSyncAsyncを使用してください。
  func attemptSetICloudSync(_ enabled: Bool) -> Result<Void, ICloudError> {
    // Short-circuit if state is already the desired one to avoid unnecessary sinks and re-entry
    if iCloudSyncEnabled == enabled { return .success(()) }

    if enabled {
      switch canEnableICloudSync() {
      case .success:
        iCloudSyncEnabled = true
        iCloudSyncBlockedReason = nil
        // TODO: 実際の iCloud / CloudKit 同期処理の開始
        // 注意: アカウント状態チェックは非同期が必要なのでこのメソッドでは実行できません
        return .success(())
      case .failure(let err):
        // do not enable and record reason
        iCloudSyncBlockedReason = err.errorDescription
        iCloudSyncEnabled = false
        return .failure(err)
      }
    } else {
      // Disable sync
      iCloudSyncEnabled = false
      iCloudSyncBlockedReason = nil
      // TODO: 停止処理
      return .success(())
    }
  }
}
