import SwiftUI

// MARK: - サポート設定ビュー
struct SupportSettingsView: View {
  @StateObject private var appSettings = AppSettings.shared
  @State private var showingSupportForm = false
  @State private var showingTutorial = false
  @State private var showingDonation = false
  @ObservedObject private var donationManager = DonationManager.shared
  @State private var showingShortcutSetupPrompt = false

  var body: some View {
    VStack(spacing: 16) {
      // チュートリアル
      GroupBox {
        Button {
          showingTutorial = true
        } label: {
          HStack(spacing: 20) {
            Image(systemName: "lightbulb.fill")
              .font(.system(size: 32))
              .foregroundStyle(.yellow)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(L10n.string("tutorial", table: "Onboarding"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text(L10n.string("tutorial_description", table: "Settings"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
          .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
      }

      // ショートカットをセットアップ（未インストール時のみ表示）
      if !appSettings.isShortcutInstalled {
        GroupBox {
          Button(
            action: { SettingsRedirectHelper.openShortcutSetup() },
            label: {
              HStack(spacing: 20) {
                Image(systemName: "arrow.down.circle")
                  .font(.system(size: 32))
                  .foregroundStyle(.blue)
                  .frame(width: 60)

                VStack(alignment: .leading, spacing: 4) {
                  Text(L10n.string("setup_shortcut", table: "Settings"))
                    .font(.headline)
                    .foregroundStyle(.primary)

                  Text(L10n.string("setup_shortcut_description", table: "Settings"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                  .foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .contentShape(Rectangle())
              .padding(.vertical, 8)
            }
          )
          .buttonStyle(.plain)
        }
      }

      // 解析データページへ移動
      GroupBox {
        Button {
          SettingsRedirectHelper.openAnalyticsViaShortcut()
        } label: {
          HStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
              .font(.system(size: 32))
              .foregroundStyle(.blue)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(L10n.string("view_analytics_data", table: "Settings"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text(L10n.string("view_analytics_data_description", table: "Settings"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
          .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
      }

      // フィードバック
      GroupBox {
        Button {
          showingSupportForm = true
        } label: {
          HStack(spacing: 20) {
            Image(systemName: "envelope.fill")
              .font(.system(size: 32))
              .foregroundStyle(.green)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(L10n.string("contact_support", table: "Support"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text(L10n.string("contact_support_description", table: "Settings"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
          .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
      }

      // Discord
      GroupBox {
        Button {
          if let url = URL(string: AppSettings.discordURL) {
            UIApplication.shared.open(url)
          }
        } label: {
          HStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
              .font(.system(size: 32))
              .foregroundStyle(.indigo)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(L10n.string("join_discord", table: "Settings"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text(L10n.string("join_discord_description", table: "Settings"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.up.right.square")
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
          .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
      }

      if donationManager.purchasesAvailable {
      // 支援
      GroupBox {
        Button {
          showingDonation = true
        } label: {
          HStack(spacing: 20) {
            Image(systemName: "heart.fill")
              .font(.system(size: 32))
              .foregroundStyle(.pink)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(L10n.string("donation_title", table: "Settings"))
            .accessibilityIdentifier("settings.donation")
                .font(.headline)
                .foregroundStyle(.primary)

              Text(L10n.string("donation_description_short", table: "Settings"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
          .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
      }
      }

    }
    .padding(.horizontal)
    .task { _ = await donationManager.checkDistribution() }
    .onAppear {
      setupShortcutNotification()
    }
    .sheet(isPresented: $showingSupportForm) {
      SupportFormView()
    }
    .sheet(isPresented: $showingTutorial) {
      TutorialView()
    }
    .sheet(isPresented: $showingDonation) {
      DonationView()
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
}
