import SwiftUI

/// 開発者向けデバッグオプション
struct DeveloperOptionsView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var appSettings = AppSettings.shared

  @State private var lastSeenVersionInput: String = ""
  @State private var showingDiscordPopupResetAlert = false
  @State private var showingMigrationResetAlert = false
  @State private var showingDiscordPopup = false

  var body: some View {
    NavigationStack {
      Form {
        // デバイス識別子の上書きセクション
        Section {
          HStack {
            TextField("例: iPhone16,1", text: $appSettings.overrideLocalModelIdentifier)
              .textFieldStyle(.roundedBorder)
              .autocorrectionDisabled()
              .textInputAutocapitalization(.never)

            if !appSettings.overrideLocalModelIdentifier.isEmpty {
              Button(role: .destructive) {
                appSettings.overrideLocalModelIdentifier = ""
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .foregroundStyle(.secondary)
              }
              .buttonStyle(.plain)
            }
          }
        } header: {
          Label("デバイス識別子の上書き", systemImage: "iphone.badge.play")
        } footer: {
          Text("自動判定時に使われる端末自体のモデル番号（hw.machine）を手動で上書きします。空にすると実際の端末の値を使用します。")
            .font(.caption)
        }

        // バージョン管理セクション
        Section {
          VStack(alignment: .leading, spacing: 8) {
            Text("現在のアプリバージョン")
              .font(.caption)
              .foregroundStyle(.secondary)

            Text(AppSettings.currentAppVersion ?? "Unknown")
              .font(.headline)
          }
          .padding(.vertical, 4)

          VStack(alignment: .leading, spacing: 8) {
            Text("最後に確認したバージョン")
              .font(.caption)
              .foregroundStyle(.secondary)

            if let lastVersion = appSettings.lastSeenVersion {
              Text(lastVersion)
                .font(.headline)
            } else {
              Text("未設定")
                .font(.headline)
                .foregroundStyle(.secondary)
            }
          }
          .padding(.vertical, 4)

          HStack {
            TextField("バージョン番号", text: $lastSeenVersionInput)
              .textFieldStyle(.roundedBorder)

            Button("変更") {
              if !lastSeenVersionInput.isEmpty {
                appSettings.lastSeenVersion = lastSeenVersionInput
                lastSeenVersionInput = ""
              }
            }
            .buttonStyle(.borderedProminent)
            .disabled(lastSeenVersionInput.isEmpty)
          }
        } header: {
          Label("バージョン管理", systemImage: "number.circle")
        } footer: {
          Text("lastSeenVersionを任意の値に変更できます。Discord告知の再表示テストなどに使用してください。")
            .font(.caption)
        }

        // Discord告知セクション
        Section {
          Button {
            showingDiscordPopup = true
          } label: {
            Label("Discord告知を表示", systemImage: "bubble.left.and.bubble.right")
          }

          Button(role: .destructive) {
            showingDiscordPopupResetAlert = true
          } label: {
            Label("Discord告知をリセット", systemImage: "arrow.counterclockwise")
          }
        } header: {
          Label("Discord告知", systemImage: "message.badge")
        } footer: {
          Text("Discord告知は通常2.1.0以下からアップデートした際に一度だけ表示されます。")
            .font(.caption)
        }

        // マイグレーションセクション
        Section {
          VStack(alignment: .leading, spacing: 8) {
            Text("実行済みマイグレーション")
              .font(.caption)
              .foregroundStyle(.secondary)

            ForEach(getMigrationStatuses(), id: \.version) { status in
              HStack {
                Image(systemName: status.completed ? "checkmark.circle.fill" : "circle")
                  .foregroundStyle(status.completed ? .green : .secondary)

                Text(status.version)
                  .font(.caption)
                  .monospaced()
              }
            }
          }
          .padding(.vertical, 4)

          Button(role: .destructive) {
            showingMigrationResetAlert = true
          } label: {
            Label("全マイグレーションをリセット", systemImage: "arrow.counterclockwise")
          }
        } header: {
          Label("マイグレーション", systemImage: "arrow.triangle.branch")
        } footer: {
          Text("マイグレーションをリセットすると、次回起動時に再実行されます。データ破損の可能性があるため注意してください。")
            .font(.caption)
        }

        // iCloud同期セクション
        Section {
          Button(action: {
            ICloudSyncManager.shared.simulateConflict()
          }) {
            Label("同期コンフリクトを発生させる", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
              .foregroundColor(.red)
          }
        } header: {
          Label("iCloud同期", systemImage: "icloud")
        } footer: {
          Text("テスト用の擬似的な競合を発生させます。その後、iCloud同期設定画面を開いて動作を確認してください。")
            .font(.caption)
        }

        // UserDefaultsセクション
        Section {
          Button(role: .destructive) {
            clearAllUserDefaults()
          } label: {
            Label("全UserDefaultsをリセット", systemImage: "trash")
          }
        } header: {
          Label("危険な操作", systemImage: "exclamationmark.triangle")
        } footer: {
          Text("全ての設定とフラグがリセットされます。アプリを再起動してください。")
            .font(.caption)
        }

        // 開発者オプションをロックするセクション
        Section {
          Button(role: .destructive) {
            appSettings.showingDeveloperOptions = false
            dismiss()
          } label: {
            Label("開発者オプションをロックする", systemImage: "lock.fill")
          }
        } header: {
          Label("開発者オプション", systemImage: "wrench.and.screwdriver")
        } footer: {
          Text("開発者オプションをロックすると、アプリバージョンを7回タップすることで再度開放できます。")
            .font(.caption)
        }
      }
      .navigationTitle("開発者オプション")
      .navigationBarTitleDisplayMode(.inline)
      .alert("Discord告知をリセット", isPresented: $showingDiscordPopupResetAlert) {
        Button("キャンセル", role: .cancel) {}
        Button("リセット", role: .destructive) {
          resetDiscordAnnouncement()
        }
      } message: {
        Text("lastSeenVersionを削除して、次回起動時にDiscord告知が表示されるようにします。")
      }
      .alert("マイグレーションをリセット", isPresented: $showingMigrationResetAlert) {
        Button("キャンセル", role: .cancel) {}
        Button("リセット", role: .destructive) {
          if #available(iOS 17, *) {
            MigrationManager.resetAllMigrations()
          }
          UserDefaults.standard.removeObject(forKey: "Migration_Completed_v2_MagSafe_Battery")
          UserDefaults.standard.removeObject(
            forKey: "CoreDataMigration_Completed_v2_MagSafe_Battery")
          UserDefaults.standard.removeObject(forKey: Migration_v3_WatchSeries3Capacity.coreDataKey)
        }
      } message: {
        Text("全てのマイグレーションフラグをリセットします。次回起動時に再実行されます。")
      }
      .sheet(isPresented: $showingDiscordPopup) {
        DiscordAnnouncementView()
      }
    }
    .onAppear {
      lastSeenVersionInput = appSettings.lastSeenVersion ?? ""
    }
  }

  // MARK: - Helper Methods

  private struct MigrationStatus {
    let version: String
    let completed: Bool
  }

  private func getMigrationStatuses() -> [MigrationStatus] {
    let migrationVersions = [
      "v1_iPhone16e_AvgTemp", "v2_MagSafe_Battery", Migration_v3_WatchSeries3Capacity.version,
    ]

    return migrationVersions.map { version in
      let key =
        version == Migration_v3_WatchSeries3Capacity.version
          && ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 17
        ? Migration_v3_WatchSeries3Capacity.coreDataKey : "Migration_Completed_\(version)"
      let completed = UserDefaults.standard.bool(forKey: key)
      return MigrationStatus(version: version, completed: completed)
    }
  }

  private func resetDiscordAnnouncement() {
    UserDefaults.standard.removeObject(forKey: AppSettings.Keys.lastSeenVersion)
    appSettings.lastSeenVersion = nil
  }

  private func clearAllUserDefaults() {
    if let bundleID = Bundle.main.bundleIdentifier {
      UserDefaults.standard.removePersistentDomain(forName: bundleID)
    }
  }
}

#Preview {
  DeveloperOptionsView()
}
