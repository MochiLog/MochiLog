import SwiftUI

// MARK: - アプリについて画面
struct AboutView: View {
  @State private var showingPrivacyPolicy = false
  @State private var showingTermsOfUse = false
  @State private var showingLicenses = false
  @StateObject private var appSettings = AppSettings.shared
  @State private var tapCount: Int = 0

  private var appVersion: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    return "\(version) (\(build))"
  }

  var body: some View {
    List {
      // MARK: - 法的情報
      Section {
        Button(action: { showingTermsOfUse = true }) {
          Label {
            Text(L10n.string("terms_of_use", table: "Legal"))
              .foregroundStyle(.primary)
          } icon: {
            Image(systemName: "doc.plaintext")
              .foregroundStyle(.purple)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        Button(action: { showingPrivacyPolicy = true }) {
          Label {
            Text(L10n.string("privacy_policy", table: "Legal"))
              .foregroundStyle(.primary)
          } icon: {
            Image(systemName: "hand.raised.fill")
              .foregroundStyle(.orange)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        Button(action: { showingLicenses = true }) {
          Label {
            Text(L10n.string("licenses", table: "Settings"))
              .foregroundStyle(.primary)
          } icon: {
            Image(systemName: "doc.text")
              .foregroundStyle(.teal)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }

      // MARK: - アプリ情報
      Section {
        HStack {
          Label {
            Text(L10n.string("app_version", table: "Settings"))
              .foregroundStyle(.primary)
          } icon: {
            Image(systemName: "info.circle.fill")
              .foregroundStyle(.blue)
          }
          Spacer()
          Text(appVersion)
            .foregroundStyle(.secondary)

          if tapCount > 0 && !appSettings.showingDeveloperOptions {
            Text("\(tapCount)")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.secondary.opacity(0.2))
              .clipShape(Capsule())
          }
        }
        .contentShape(Rectangle())
        .onTapGesture {
          if !appSettings.showingDeveloperOptions {
            tapCount += 1
            if tapCount >= 7 {
              appSettings.showingDeveloperOptions = true
              tapCount = 0
            }
          }
        }

        Link(destination: URL(string: "https://github.com/MochiLog/MochiLog")!) {
          Label {
            Text(L10n.string("view_on_github", table: "Support"))
              .foregroundStyle(.primary)
          } icon: {
            Image(systemName: "link")
              .foregroundStyle(.blue)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }

      // MARK: - 開発者オプション（7回タップで表示）
      if appSettings.showingDeveloperOptions {
        Section {
          NavigationLink {
            DeveloperOptionsView()
          } label: {
            HStack {
              Label {
                Text("開発者オプション")
                  .foregroundStyle(.primary)
              } icon: {
                Image(systemName: "wrench.and.screwdriver.fill")
                  .foregroundStyle(.red)
              }
              Spacer()
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        } header: {
          Text("デバッグ")
        }
      }
    }
    .navigationTitle(L10n.string("about_app", table: "Settings"))
    .sheet(isPresented: $showingPrivacyPolicy) {
      PrivacyPolicyView()
    }
    .sheet(isPresented: $showingTermsOfUse) {
      TermsOfUseView()
    }
    .sheet(isPresented: $showingLicenses) {
      LicenseView()
    }
  }
}

#Preview {
  NavigationStack {
    AboutView()
  }
}
