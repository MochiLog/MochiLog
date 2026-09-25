import SwiftUI

// MARK: - アプリについて（iPad用）
struct AboutSettingsView: View {
  @State private var showingPrivacyPolicy = false
  @State private var showingTermsOfUse = false
  @State private var showingLicenses = false
  @State private var showingDeveloperOptions = false
  @StateObject private var appSettings = AppSettings.shared
  @State private var tapCount: Int = 0

  private var appVersion: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    return "Version \(version) (Build \(build))"
  }

  var body: some View {
    VStack(spacing: 16) {
      // アプリ情報
      GroupBox {
        Button {
          if !appSettings.showingDeveloperOptions {
            tapCount += 1
            if tapCount >= 7 {
              appSettings.showingDeveloperOptions = true
              tapCount = 0
            }
          }
        } label: {
          HStack(spacing: 20) {
            Image(systemName: "info.circle.fill")
              .font(.system(size: 32))
              .foregroundStyle(.blue)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(L10n.string("app_version", table: "Settings"))
                .font(.headline)

              Text(appVersion)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if tapCount > 0 && !appSettings.showingDeveloperOptions {
              Text("\(tapCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .clipShape(Capsule())
            }
          }
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }

      // 開発者オプション（7回タップで表示）
      if appSettings.showingDeveloperOptions {
        GroupBox {
          Button {
            showingDeveloperOptions = true
          } label: {
            HStack(spacing: 20) {
              Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 32))
                .foregroundStyle(.red)
                .frame(width: 60)

              VStack(alignment: .leading, spacing: 4) {
                Text("開発者オプション")
                  .font(.headline)
                  .foregroundStyle(.primary)

                Text("デバッグ用の設定とツール")
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

      // 利用規約
      GroupBox {
        Button(action: { showingTermsOfUse = true }) {
          HStack(spacing: 20) {
            Image(systemName: "doc.plaintext")
              .font(.system(size: 32))
              .foregroundStyle(.purple)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(L10n.string("terms_of_use", table: "Legal"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text(L10n.string("terms_of_use_description", table: "Settings"))
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

      // プライバシーポリシー
      GroupBox {
        Button(action: { showingPrivacyPolicy = true }) {
          HStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
              .font(.system(size: 32))
              .foregroundStyle(.orange)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(L10n.string("privacy_policy", table: "Legal"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text(L10n.string("privacy_policy_description", table: "Settings"))
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

      // ライセンス
      GroupBox {
        Button(action: { showingLicenses = true }) {
          HStack(spacing: 20) {
            Image(systemName: "doc.text")
              .font(.system(size: 32))
              .foregroundStyle(.teal)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(L10n.string("licenses", table: "Settings"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text(L10n.string("licenses_description", table: "Settings"))
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

      // リンク
      GroupBox {
        Link(destination: URL(string: "https://github.com/MochiLog/MochiLog")!) {
          HStack(spacing: 20) {
            Image(systemName: "link")
              .font(.system(size: 32))
              .foregroundStyle(.blue)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(L10n.string("view_on_github", table: "Support"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text(L10n.string("github_description", table: "Settings"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
              .foregroundStyle(.secondary)
          }
        }
        .tint(.primary)
        .padding(.vertical, 8)
      }
    }
    .padding(.horizontal)
    .sheet(isPresented: $showingPrivacyPolicy) {
      PrivacyPolicyView()
    }
    .sheet(isPresented: $showingTermsOfUse) {
      TermsOfUseView()
    }
    .sheet(isPresented: $showingLicenses) {
      LicenseView()
    }
    .sheet(isPresented: $showingDeveloperOptions) {
      NavigationStack {
        DeveloperOptionsView()
      }
    }
  }
}

#Preview {
  AboutSettingsView()
}
