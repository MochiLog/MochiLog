import SwiftUI

// MARK: - 高度な設定詳細ビュー（iPhone 専用ナビゲーション遷移先）
struct AdvancedSettingsDetailView: View {
  @ObservedObject var appSettings: AppSettings

  @State private var showingDevicePickerForRegistration = false
  @State private var showingRemoveConfirmation = false
  @State private var deviceToRemove: String?
  @State private var showingRemoveAllConfirmation = false

  var body: some View {
    Form {
      if #available(iOS 27, *) {
        Section {
          NavigationLink(destination: MacTransferSettingsView()) {
            Label("Mac連携（ベータ）", systemImage: "laptopcomputer.and.iphone")
          }
        }
      }
      Section {
        NavigationLink(destination: DeviceProfilesView()) {
          Label(L10n.string("profile_library", table: "Settings"), systemImage: "cpu")
        }
        .accessibilityIdentifier("settings.deviceProfiles")
      }
      // MARK: - デバイス選択
      Section {
        Picker(
          L10n.string("device_selection_mode", table: "Settings"),
          selection: $appSettings.deviceSelectionMode
        ) {
          ForEach(AppSettings.DeviceSelectionMode.allCases) { mode in
            Text(mode.localizedName).tag(mode)
          }
        }
        .pickerStyle(.menu)
      } header: {
        Text(L10n.string("device_selection_settings", table: "Settings"))
      } footer: {
        Text(appSettings.deviceSelectionMode.description)
      }

      if appSettings.deviceSelectionMode == .preRegistered {
        Section {
          if appSettings.registeredDevices.isEmpty {
            HStack {
              Label(
                L10n.string("registered_devices", table: "Settings"),
                systemImage: "iphone.gen3"
              )
              Spacer()
              Text(L10n.string("not_registered", table: "Settings"))
                .foregroundStyle(.secondary)
            }
          } else {
            ForEach(appSettings.registeredDevices, id: \.self) { deviceName in
              let icon = deviceName.contains("iPad") ? "ipad.gen2" : "iphone.gen3"
              Label(DeviceLibrary.localizedName(for: deviceName), systemImage: icon)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                  Button(role: .destructive) {
                    deviceToRemove = deviceName
                    showingRemoveConfirmation = true
                  } label: {
                    Label(L10n.string("remove", table: "Common"), systemImage: "trash")
                  }
                  .tint(.red)
                }
            }
          }

          Button(action: { showingDevicePickerForRegistration = true }) {
            Label(
              L10n.string("add_device", table: "Settings"),
              systemImage: "plus.circle"
            )
          }

          if appSettings.registeredDevices.count > 1 {
            Button(action: { showingRemoveAllConfirmation = true }) {
              Label(
                L10n.string("remove_all_devices", table: "Settings"),
                systemImage: "trash"
              )
              .foregroundStyle(.red)
            }
          }
        } header: {
          Text(L10n.string("registered_devices", table: "Settings"))
        } footer: {
          Text(
            appSettings.registeredDevices.isEmpty
              ? L10n.string("registered_devices_empty_footer", table: "Settings")
              : L10n.string("registered_devices_footer", table: "Settings")
          )
        }
      }

      // MARK: - 分析データの計算基準
      Section {
        Picker(
          L10n.string("analysis_source", table: "Settings"),
          selection: $appSettings.analysisDataSource
        ) {
          ForEach(AppSettings.AnalysisDataSource.allCases) { source in
            Text(source.localizedName).tag(source)
          }
        }
        .pickerStyle(.menu)
      } header: {
        Text(L10n.string("analysis_source", table: "Settings"))
      }

      // MARK: - 共有インポート設定
      Section {
        Toggle(
          L10n.string("open_app_after_share_import", table: "Settings"),
          isOn: $appSettings.openAppAfterShareImport
        )
      } footer: {
        Text(L10n.string("open_app_after_share_import_description", table: "Settings"))
      }

      // MARK: - MagSafe設定
      Section {
        VStack(alignment: .leading, spacing: 8) {
          Text("iPhone Air / MagSafeバッテリー判定")
          Picker("", selection: $appSettings.autoSelectMagSafeBattery) {
            Text("自動で区別").tag(true)
            Text("手動で毎回選ぶ").tag(false)
          }
          .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
      } footer: {
        Text("iPhone Airのログにおいて、MagSafeバッテリー特有の条件に合致した場合、自動的に「iPhone Air MagSafeバッテリー」として登録するか、毎回手動で選ぶかを設定します。")
      }

      // MARK: - 容量検証設定
      Section {
        Toggle(
          L10n.string("enable_capacity_validation", table: "Settings"),
          isOn: $appSettings.enableCapacityValidation
        )

        if appSettings.enableCapacityValidation {
          HStack {
            Text(L10n.string("validation_threshold", table: "Settings"))
            Spacer()
            Text(String(format: "%.1f x", appSettings.capacityValidationThreshold))
              .monospacedDigit()
              .foregroundStyle(.secondary)
          }

          Slider(value: $appSettings.capacityValidationThreshold, in: 2...20, step: 0.5)

          Picker(
            L10n.string("mismatch_behavior", table: "Settings"),
            selection: $appSettings.mismatchBehavior
          ) {
            ForEach(AppSettings.MismatchBehavior.allCases) { behavior in
              Text(behavior.localizedName).tag(behavior)
            }
          }
          .pickerStyle(.menu)
        }
      } header: {
        Text(L10n.string("enable_capacity_validation", table: "Settings"))
      } footer: {
        Text(L10n.string("validation_threshold_description", table: "Settings"))
      }

      // MARK: - 重複ログ設定
      Section {
        Toggle(
          L10n.string("allow_duplicate_records", table: "Settings"),
          isOn: $appSettings.allowDuplicateRecords
        )
      } footer: {
        Text(L10n.string("allow_duplicate_records_description", table: "Settings"))
      }

      // MARK: - iCloud ストレージ設定
      Section {
        HStack {
          Text(L10n.string("threshold_label", table: "Settings"))
          Spacer()
          Text(String(format: "%.0f MB", appSettings.iCloudStorageThresholdMB))
            .foregroundStyle(.secondary)
        }

        Slider(value: $appSettings.iCloudStorageThresholdMB, in: 10...1024, step: 10)

        if let blocked = appSettings.iCloudSyncBlockedReason {
          Label(blocked, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundColor(.red)
        }
      } header: {
        Text(L10n.string("icloud_storage_threshold", table: "Settings"))
      } footer: {
        Text(L10n.string("icloud_storage_description", table: "Settings"))
      }
    }
    .scrollContentBackground(.hidden)
    .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    .navigationTitle(L10n.string("advanced_settings", table: "Settings"))
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showingDevicePickerForRegistration) {
      HierarchicalDevicePickerView(allowedCategories: [.iphone, .ipad]) { name, _ in
        appSettings.registerDevice(name: name)
      }
    }
    .alert(
      L10n.string("remove_device", table: "Settings"),
      isPresented: $showingRemoveConfirmation
    ) {
      Button(L10n.string("cancel", table: "Common"), role: .cancel) {}
      Button(L10n.string("remove", table: "Common"), role: .destructive) {
        if let device = deviceToRemove {
          appSettings.removeDevice(name: device)
        }
      }
    } message: {
      if let device = deviceToRemove {
        Text(
          String(
            format: L10n.string("remove_device_confirm_specific", table: "Settings"),
            device
          ))
      }
    }
    .alert(
      L10n.string("remove_all_devices", table: "Settings"),
      isPresented: $showingRemoveAllConfirmation
    ) {
      Button(L10n.string("cancel", table: "Common"), role: .cancel) {}
      Button(L10n.string("remove", table: "Common"), role: .destructive) {
        appSettings.registeredDevices.forEach { appSettings.removeDevice(name: $0) }
      }
    } message: {
      Text(L10n.string("remove_all_devices_confirm", table: "Settings"))
    }
  }
}
