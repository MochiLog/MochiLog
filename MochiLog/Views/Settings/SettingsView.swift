import SwiftUI
import UniformTypeIdentifiers

// MARK: - 設定ビュー
struct SettingsView: View {
  @EnvironmentObject private var dataStore: DataStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @StateObject private var appSettings = AppSettings.shared

  /// DataStoreからレコードを取得（キャッシュ済み）
  private var records: [BatteryRecord] {
    dataStore.recordsDescending
  }

  /// 利用可能なデバイス名リスト（ソート済み）
  private var availableDevices: [String] {
    let deviceNames = dataStore.deviceNames

    // AppSettings.deviceSortOrderでソート
    if appSettings.deviceSortOrder.isEmpty {
      return deviceNames
    } else {
      var ordered: [String] = []
      var remaining = Set(deviceNames)

      for name in appSettings.deviceSortOrder {
        if remaining.contains(name) {
          ordered.append(name)
          remaining.remove(name)
        }
      }
      ordered.append(contentsOf: remaining.sorted())
      return ordered
    }
  }

  @State private var showingWatchPicker = false
  @State private var showingDeleteConfirmation = false
  @State private var showingNoDataToDeleteAlert = false
  @State private var showingRemoveWatchConfirmation = false
  @State private var watchToRemove: String? = nil
  @State private var showingRemoveAllWatchesConfirmation = false
  @State private var showingTutorial = false
  @State private var showingSupportForm = false
  @State private var showingDonation = false
  @ObservedObject private var donationManager = DonationManager.shared

  // デバイスごとの削除機能用の状態
  @State private var showingDeviceDeletePicker = false
  @State private var showingDeviceDeleteConfirmation = false
  @State private var selectedDeviceToDelete: String?

  // ショートカット関連のアラート
  @State private var showingShortcutSetupPrompt = false

  // エクスポート/インポート関連
  @State private var showingExportSheet = false
  @State private var showingImportSheet = false
  @State private var showingImportAlert = false
  @State private var importResultMessage = ""
  @State private var showingExportError = false
  @State private var exportErrorMessage = ""

  // インポート進捗表示
  @State private var isImporting = false
  @State private var importProgress: Double = 0.0

  // 大画面レイアウト用: 選択されたカテゴリ（状態維持のためAppSettingsから取得）
  private var selectedCategory: Binding<SettingsCategory> {
    $appSettings.selectedSettingsCategory
  }

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        settingsList(availableWidth: geometry.size.width)
      }
        .navigationDestination(isPresented: $appSettings.showingICloudSettings) {
          ICloudSettingsView(appSettings: appSettings)
        }
        .navigationTitle(L10n.string("settings_title", table: "Settings"))
        .onAppear {
          setupShortcutNotification()
        }
        .task { _ = await donationManager.checkDistribution() }
        .sheet(isPresented: $showingWatchPicker) {
          HierarchicalDevicePickerView(initialCategory: .watch, lockCategory: true) {
            name, identifier in
            appSettings.registerWatch(model: name)
          }
        }
        .sheet(isPresented: $showingTutorial) {
          TutorialView()
        }
        .sheet(isPresented: $showingSupportForm) {
          SupportFormView()
        }
        .sheet(isPresented: $showingDonation) {
          DonationView()
        }
        .alert(
          L10n.string("delete_all_data", table: "Settings"),
          isPresented: $showingDeleteConfirmation
        ) {
          Button(L10n.string("cancel", table: "Common"), role: .cancel) {}
          Button(L10n.string("delete", table: "Common"), role: .destructive) {
            deleteAllRecords()
          }
        } message: {
          Text(L10n.string("delete_all_data_confirm", table: "Settings"))
        }
        .alert(
          L10n.string("no_data_to_delete_title", table: "Settings"),
          isPresented: $showingNoDataToDeleteAlert
        ) {
          Button(L10n.string("ok", table: "Common"), role: .cancel) {}
        } message: {
          Text(L10n.string("no_data_to_delete_message", table: "Settings"))
        }
        .alert(
          L10n.string("remove_watch", table: "Settings"),
          isPresented: $showingRemoveWatchConfirmation
        ) {
          Button(L10n.string("cancel", table: "Common"), role: .cancel) {}
          Button(L10n.string("remove", table: "Common"), role: .destructive) {
            if let watch = watchToRemove {
              appSettings.removeWatch(model: watch)
            }
          }
        } message: {
          if let watch = watchToRemove {
            Text(
              String(
                format: L10n.string("remove_watch_confirm_specific", table: "Settings"), watch
              ))
          } else {
            Text(L10n.string("remove_watch_confirm", table: "Settings"))
          }
        }
        .alert(
          L10n.string("remove_all_watches", table: "Settings"),
          isPresented: $showingRemoveAllWatchesConfirmation
        ) {
          Button(L10n.string("cancel", table: "Common"), role: .cancel) {}
          Button(L10n.string("remove", table: "Common"), role: .destructive) {
            appSettings.unregisterAllWatches()
          }
        } message: {
          Text(L10n.string("remove_all_watches_confirm", table: "Settings"))
        }
        .sheet(isPresented: $showingDeviceDeletePicker) {
          DeviceDeletePickerView(availableDevices: availableDevices) { deviceName in
            selectedDeviceToDelete = deviceName
            showingDeviceDeleteConfirmation = true
          }
        }
        .alert(
          L10n.string("delete_device_data_title", table: "Settings"),
          isPresented: $showingDeviceDeleteConfirmation
        ) {
          Button(L10n.string("cancel", table: "Common"), role: .cancel) {}
          Button(L10n.string("delete", table: "Common"), role: .destructive) {
            if let deviceName = selectedDeviceToDelete {
              deleteRecordsForDevice(deviceName)
              // 削除後はデバイス選択をリセット（再選択を促す）
              selectedDeviceToDelete = nil
            }
          }
        } message: {
          if let deviceName = selectedDeviceToDelete {
            Text(
              String(
                format: L10n.string("delete_device_data_confirm", table: "Settings"),
                deviceName
              ))
          }
        }
        .alert(
          L10n.string("shortcut_required_title", table: "Settings"),
          isPresented: $showingShortcutSetupPrompt
        ) {
          Button(L10n.string("setup_now", table: "Settings"), role: .none) {
            SettingsRedirectHelper.openShortcutSetup()
          }
          Button(L10n.string("cancel", table: "Common"), role: .cancel) {}
        } message: {
          Text(L10n.string("shortcut_required_message", table: "Settings"))
        }
        .fileExporter(
          isPresented: $showingExportSheet,
          document: YAMLDocument(yaml: generateExportYAML()),
          contentType: .yaml,
          defaultFilename: DataExportService.generateFileName()
        ) { result in
          print("[SettingsView] fileExporter callback called")
          handleExportResult(result)
        }
        .onChange(of: showingExportSheet) { _ in
          print("[SettingsView] showingExportSheet changed")
        }
        .fileImporter(
          isPresented: $showingImportSheet,
          allowedContentTypes: [.yaml],
          allowsMultipleSelection: false
        ) { result in
          print("[SettingsView] fileImporter callback called")
          handleImportResult(result)
        }
        .onChange(of: showingImportSheet) { _ in
          print("[SettingsView] showingImportSheet changed")
        }
        .alert(
          L10n.string("import_result_title", table: "Settings"),
          isPresented: $showingImportAlert
        ) {
          Button("OK", role: .cancel) {}
        } message: {
          Text(importResultMessage)
        }
        .alert(
          L10n.string("export_error_title", table: "Settings"),
          isPresented: $showingExportError
        ) {
          Button("OK", role: .cancel) {}
        } message: {
          Text(exportErrorMessage)
        }
        // インポート中プログレスシート
        .sheet(isPresented: $isImporting) {
          ImportProgressSheet(progress: $importProgress)
            .interactiveDismissDisabled(true)
        }
    }
  }

  // MARK: - iPad/iPhone向けList
  @ViewBuilder
  private func settingsList(availableWidth: CGFloat) -> some View {
    if horizontalSizeClass == .regular && availableWidth >= 700 && !dynamicTypeSize.isAccessibilitySize {
      // iPad: 2カラムレイアウト（左:カテゴリ一覧、右:詳細） - スクロール分離
      HStack(alignment: .top, spacing: 0) {
        // 左側：カテゴリ一覧（独立したScrollView）
        VStack(spacing: 0) {
          Divider()  // ヘッダーとの境界線
          ScrollView {
            VStack(spacing: 16) {
              ForEach(SettingsCategory.allCases.filter { $0 != .iCloud }) { category in
                Button {
                  selectedCategory.wrappedValue = category
                } label: {
                  CategoryCardView(category: category,
                    isSelected: selectedCategory.wrappedValue == category)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(category == .language ? "settings.language" : "settings.category.\(category.rawValue)")
              }

            }
            .padding()
          }
        }
        .frame(width: min(260, availableWidth * 0.32))
        .frame(maxHeight: .infinity)
        .clipped()

        Divider()

        // 右側：選択されたカテゴリの詳細（Apple Watch・高度な設定はList表示）
        if selectedCategory.wrappedValue == .general {
          GeneralSettingsView(appSettings: appSettings)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if selectedCategory.wrappedValue == .appleWatch {
          VStack(spacing: 0) {
            Divider()  // ヘッダーとの境界線
            AppleWatchSettingsView(
              showingWatchPicker: $showingWatchPicker,
              appSettings: appSettings
            )
          }
          .frame(maxHeight: .infinity)
          .clipped()
        } else if selectedCategory.wrappedValue == .language {
          LanguageSettingsView(isEmbedded: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if selectedCategory.wrappedValue == .advanced {
          VStack(spacing: 0) {
            Divider()  // ヘッダーとの境界線
            AdvancedSettingsView(appSettings: appSettings)
          }
          .frame(maxHeight: .infinity)
          .clipped()
        } else {
          VStack(spacing: 0) {
            Divider()  // ヘッダーとの境界線
            ScrollView {
              VStack(spacing: 0) {
                switch selectedCategory.wrappedValue {
                case .general:
                  EmptyView()
                case .iCloud:
                  ICloudSettingsView(appSettings: appSettings)
                case .appleWatch:
                  AppleWatchSettingsView(
                    showingWatchPicker: $showingWatchPicker,
                    appSettings: appSettings
                  )
                case .dataManagement:
                  DataManagementSettingsView(
                    showingDeleteAllConfirmation: $showingDeleteConfirmation,
                    showingDeleteDeviceConfirmation: $showingDeviceDeleteConfirmation,
                    deletingDeviceId: $selectedDeviceToDelete,
                    appSettings: appSettings,
                    availableDevices: availableDevices,
                    records: records,
                    dataStore: dataStore,
                    showingExportSheet: $showingExportSheet,
                    showingImportSheet: $showingImportSheet,
                    showingImportAlert: $showingImportAlert,
                    importResultMessage: $importResultMessage,
                    showingExportError: $showingExportError,
                    exportErrorMessage: $exportErrorMessage
                  )
                case .support:
                  SupportSettingsView()
                case .about:
                  AboutSettingsView()
                case .debug:
                  DebugSettingsView(appSettings: appSettings)
                case .advanced, .language:
                  EmptyView()
                }
              }
              .padding(.top)
              .frame(maxWidth: 760, alignment: .leading)
              .frame(maxWidth: .infinity)
              .padding(.horizontal, 12)
            }
          }
          .groupBoxStyle(SettingsCardGroupBoxStyle())
          .frame(maxHeight: .infinity)
          .clipped()
        }
      }
      .background(Color(.systemGroupedBackground))
    } else {
      // iPhone: 通常のList
      List {
        settingsContent
      }
      .listStyle(.insetGrouped)
      .labelStyle(SettingsRowLabelStyle(color: appSettings.accentColor.color))
      .environment(\.defaultMinListRowHeight, 56)
      .scrollContentBackground(.hidden)
      .background(Color(uiColor: .systemGroupedBackground))
    }
  }

  // MARK: - 設定内容
  @ViewBuilder
  private var settingsContent: some View {
    // MARK: - 一般
    Section(L10n.string("general", table: "Settings")) {
      // iCloud同期画面へのリンク
      if #available(iOS 17, *) {
        Button {
          appSettings.showingICloudSettings = true
        } label: {
          HStack {
            HStack(spacing: 12) {
              Image(systemName: "icloud.fill")
                .foregroundColor(appSettings.accentColor.color)
              Text(L10n.string("icloud_sync_settings", defaultValue: "iCloud同期設定", table: "Settings"))
                .foregroundColor(.primary)
            }

            Spacer()

            Image(systemName: "chevron.right")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(Color(UIColor.tertiaryLabel))
          }
        }
      }

      Picker(
        L10n.string("accent_color", table: "Settings"),
        selection: $appSettings.accentColor
      ) {
        ForEach(AppSettings.ThemeColor.allCases) { theme in
          HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
              .fill(theme.color)
              .frame(width: 18, height: 18)
            Text(theme.localizedName)
          }
          .tag(theme)
        }
      }
      .pickerStyle(.menu)

      RecordInfoToggle()
      RenderingSettingsRow()

      // サンプルデータ表示
      Button {
        appSettings.showingSampleData = true
        appSettings.selectedTabIndex = 0  // ホームページへ遷移
      } label: {
        Label(L10n.string("view_sample_data", table: "Home"), systemImage: "eye")
      }
    }

    // MARK: - Apple Watch 設定
    Section {
      // 登録済みWatchのリスト
      if appSettings.registeredWatches.isEmpty {
        HStack {
          Label(
            L10n.string("registered_watch", table: "Settings"), systemImage: "applewatch")
          Spacer()
          Text(L10n.string("not_registered", table: "Settings"))
            .foregroundStyle(.secondary)
        }
      } else {
        ForEach(appSettings.registeredWatches, id: \.self) { watchModel in
          HStack {
            Label(DeviceLibrary.localizedName(for: watchModel), systemImage: "applewatch")
          }
          .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
              watchToRemove = watchModel
              showingRemoveWatchConfirmation = true
            } label: {
              Label(L10n.string("remove", table: "Common"), systemImage: "trash")
            }
            .tint(.red)
          }
        }
      }

      // Watchを追加ボタン
      Button(action: { showingWatchPicker = true }) {
        Label(
          L10n.string("add_watch", table: "Settings"),
          systemImage: "plus.circle"
        )
      }

      // すべて削除ボタン（複数登録時のみ表示）
      if appSettings.registeredWatches.count > 1 {
        Button(action: { showingRemoveAllWatchesConfirmation = true }) {
          Label(
            L10n.string("remove_all_watches", table: "Settings"),
            systemImage: "trash"
          )
          .foregroundStyle(.red)
        }
      }
    } header: {
      Text(L10n.string("apple_watch_settings", table: "Settings"))
    } footer: {
      Text(
        appSettings.registeredWatches.isEmpty
          ? L10n.string("watch_selection_description", table: "Settings")
          : L10n.string("multiple_watch_description", table: "Settings")
      )
    }

    // MARK: - データ管理
    Section(L10n.string("data_management", table: "Settings")) {
      // エクスポート
      Button {
        showingExportSheet = true
      } label: {
        Label {
          Text(L10n.string("export_data", table: "Settings"))
            .foregroundStyle(.primary)
        } icon: {
          Image(systemName: "square.and.arrow.up.fill")
            .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      // インポート
      Button {
        showingImportSheet = true
      } label: {
        Label {
          Text(L10n.string("import_data", table: "Settings"))
            .foregroundStyle(.primary)
        } icon: {
          Image(systemName: "square.and.arrow.down.fill")
            .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Button(role: .destructive) {
        if availableDevices.isEmpty {
          showingNoDataToDeleteAlert = true
        } else {
          showingDeviceDeletePicker = true
        }
      } label: {
        Label(L10n.string("delete_device_data", table: "Settings"), systemImage: "trash")
          .foregroundStyle(.red)
      }
      .tint(.red)

      Button(role: .destructive) {
        if records.isEmpty {
          showingNoDataToDeleteAlert = true
        } else {
          showingDeleteConfirmation = true
        }
      } label: {
        Label(
          L10n.string("delete_all_data", table: "Settings"), systemImage: "trash.fill"
        )
        .foregroundStyle(.red)
      }
      .tint(.red)
    }

    // MARK: - サポート
    Section(L10n.string("support", table: "Settings")) {
      Button(action: { showingTutorial = true }) {
        Label {
          Text(L10n.string("view_tutorial", table: "Home"))
            .foregroundStyle(.primary)
        } icon: {
          Image(systemName: "lightbulb.fill")
            .foregroundStyle(.yellow)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      // ショートカット未インストール時のみ表示
      if !appSettings.isShortcutInstalled {
        Button(action: {
          SettingsRedirectHelper.openShortcutSetup()
        }) {
          Label {
            Text(L10n.string("setup_shortcut", table: "Settings"))
              .foregroundStyle(.primary)
          } icon: {
            Image(systemName: "arrow.down.circle")
              .foregroundStyle(.blue)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }

      Button(action: {
        SettingsRedirectHelper.openAnalyticsViaShortcut()
      }) {
        Label {
          Text(L10n.string("view_analytics_data", table: "Settings"))
            .foregroundStyle(.primary)
        } icon: {
          Image(systemName: "doc.text.magnifyingglass")
            .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Button(action: { showingSupportForm = true }) {
        Label {
          Text(L10n.string("contact_support", table: "Support"))
            .foregroundStyle(.primary)
        } icon: {
          Image(systemName: "envelope.fill")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Button(action: {
        if let url = URL(string: AppSettings.discordURL) {
          UIApplication.shared.open(url)
        }
      }) {
        Label {
          Text(L10n.string("join_discord", table: "Settings"))
            .foregroundStyle(.primary)
        } icon: {
          Image(systemName: "bubble.left.and.bubble.right.fill")
            .foregroundStyle(.indigo)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if donationManager.purchasesAvailable {
      Button(action: { showingDonation = true }) {
        Label {
          Text(L10n.string("donation_title", table: "Settings"))
            .accessibilityIdentifier("settings.donation")
            .foregroundStyle(.primary)
        } icon: {
          Image(systemName: "heart.fill")
            .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      }
    }

    // MARK: - デバッグ
    Section(L10n.string("debug", table: "Support")) {
      Toggle(
        L10n.string("show_popup_on_load", table: "Support"),
        isOn: $appSettings.showPopupOnLoad)

      NavigationLink(destination: DebugLogsView()) {
        Label(
          L10n.string("view_error_logs", table: "Support"),
          systemImage: "exclamationmark.triangle")
      }
    }

    // MARK: - 高度な設定
    Section {
      NavigationLink(
        destination: AdvancedSettingsDetailView(appSettings: appSettings)
      ) {
        Label(
          L10n.string("advanced_settings", table: "Settings"),
          systemImage: "gearshape.2.fill"
        )
      }
      .accessibilityIdentifier("settings.advanced")
    }

    // MARK: - アプリについて
    Section {
      NavigationLink(destination: AboutView()) {
        Label(L10n.string("about_app", table: "Settings"), systemImage: "info.circle")
      }
    }

    Section {
      languageLink
    }
  }

  private var languageLink: some View {
    NavigationLink(destination: LanguageSettingsView()) {
      Label(L10n.string("language_title", table: "Language"), systemImage: "globe")
    }
    .accessibilityIdentifier("settings.language")
  }

  private func deleteAllRecords() {
    dataStore.deleteAll()
    dataStore.save()

    // Remove any persisted shared log fallback
    UserDefaults.standard.removeObject(forKey: "PendingSharedLogText")
    UserDefaults.standard.removeObject(forKey: "PendingSharedLogSilent")

    // Notify other components (HomeView etc.) to clear transient UI state
    NotificationCenter.default.post(
      name: NSNotification.Name("DeleteAllDataPerformed"), object: nil)
  }

  private func deleteRecordsForDevice(_ deviceName: String) {
    dataStore.deleteRecords(for: deviceName)
    dataStore.save()

    // Notify other components (HomeView etc.) to clear transient UI state
    NotificationCenter.default.post(
      name: NSNotification.Name("DeleteAllDataPerformed"), object: nil)
  }

  private func setupShortcutNotification() {
    NotificationCenter.default.addObserver(
      forName: NSNotification.Name("ShortcutNotFound"),
      object: nil,
      queue: .main
    ) { _ in
      // ショートカットが見つからない場合はセットアップ誘導アラートを表示
      showingShortcutSetupPrompt = true
    }
  }

  // MARK: - エクスポート/インポート処理

  /// エクスポート用YAMLを生成
  private func generateExportYAML() -> String {
    do {
      return try DataExportService.exportToYAML(records: records)
    } catch {
      return "# Export failed: \(error.localizedDescription)"
    }
  }

  /// エクスポート結果を処理
  private func handleExportResult(_ result: Result<URL, Error>) {
    switch result {
    case .success:
      // 成功時は特に何もしない（システムが保存完了を通知）
      break
    case .failure(let error):
      exportErrorMessage = error.localizedDescription
      showingExportError = true
    }
  }

  /// インポート結果を処理
  private func handleImportResult(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      guard let url = urls.first else { return }

      Task {
        // セキュリティスコープ付きリソースへのアクセスを開始
        guard url.startAccessingSecurityScopedResource() else {
          await MainActor.run {
            importResultMessage =
              L10n.string("import_error",
                table: "Settings"
              ) + ": ファイルへのアクセス権限がありません"
            showingImportAlert = true
          }
          return
        }

        defer {
          url.stopAccessingSecurityScopedResource()
        }

        // プログレスシートを表示
        await MainActor.run {
          importProgress = 0.0
          isImporting = true
        }

        do {
          let importResult = try await DataImportService.importFromYAML(
            url: url,
            dataStore: dataStore,
            existingRecords: records,
            allowDuplicates: appSettings.allowDuplicateRecords,
            progressHandler: { @MainActor progress in
              // @MainActorクロージャなのでState変数を直接更新可能
              importProgress = progress
            }
          )

          await MainActor.run {
            isImporting = false
            if importResult.hasErrors {
              importResultMessage = L10n.string("import_partial_success",
                table: "Settings"
              ).replacingOccurrences(of: "{imported}", with: "\(importResult.importedRecords)")
                .replacingOccurrences(of: "{skipped}", with: "\(importResult.skippedDuplicates)")
                .replacingOccurrences(of: "{errors}", with: "\(importResult.errors.count)")
            } else if importResult.skippedDuplicates > 0 {
              importResultMessage = L10n.string("import_success_with_duplicates",
                table: "Settings"
              ).replacingOccurrences(of: "{imported}", with: "\(importResult.importedRecords)")
                .replacingOccurrences(of: "{skipped}", with: "\(importResult.skippedDuplicates)")
            } else {
              importResultMessage = L10n.string("import_success",
                table: "Settings"
              ).replacingOccurrences(of: "{count}", with: "\(importResult.importedRecords)")
            }
            showingImportAlert = true
          }
        } catch {
          await MainActor.run {
            isImporting = false
            importResultMessage =
              L10n.string("import_error",
                table: "Settings"
              ) + ": \(error.localizedDescription)"
            showingImportAlert = true
          }
        }
      }

    case .failure(let error):
      importResultMessage =
        L10n.string("import_error",
          table: "Settings"
        ) + ": \(error.localizedDescription)"
      showingImportAlert = true
    }
  }
}

struct SettingsCardGroupBoxStyle: GroupBoxStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      configuration.label
      configuration.content
    }
    .padding()
    .mochiCard()
  }
}

#Preview {
  SettingsView()
    .environmentObject(DataStore.create(iCloudEnabled: false))
}

private struct SettingsRowLabelStyle: LabelStyle {
  let color: Color

  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 12) {
      configuration.icon
        .font(.system(size: 17, weight: .medium))
        .frame(width: 32, height: 32)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
      configuration.title
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.vertical, 3)
  }
}
