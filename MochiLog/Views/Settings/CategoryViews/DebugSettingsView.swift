import SwiftUI

// MARK: - デバッグ設定ビュー
struct DebugSettingsView: View {
  @ObservedObject var appSettings: AppSettings

  var body: some View {
    VStack(spacing: 16) {
      // デバッグログ
      GroupBox {
        HStack(spacing: 20) {
          Image(systemName: "ant.fill")
            .font(.system(size: 36))
            .foregroundStyle(.purple)
            .frame(width: 60)

          VStack(alignment: .leading, spacing: 8) {
            Toggle(
              L10n.string("show_popup_on_load", table: "Support"),
              isOn: $appSettings.showPopupOnLoad
            )
            .font(.headline)

            Text(L10n.string("debug_popup_description", table: "Settings"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 8)
      }

      if #available(iOS 17, *), !ProcessInfo.processInfo.isiOSAppOnMac {
        GroupBox {
          DiagnosticLogSettingsLink(expanded: true)
            .buttonStyle(.plain)
        }
      }

      // エラーログ
      GroupBox {
        NavigationLink(destination: DebugLogsView()) {
          HStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
              .font(.system(size: 32))
              .foregroundStyle(.orange)
              .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
              Text(L10n.string("view_error_logs", table: "Support"))
                .font(.headline)
                .foregroundStyle(.primary)

              Text(L10n.string("error_logs_description", table: "Settings"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 8)
          .contentShape(Rectangle())
        }
        .accessibilityIdentifier("settings.errorLogs")
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal)
  }
}


// Both settings layouts open the same daily archives and storage controls.
@available(iOS 17, *)
struct DiagnosticLogSettingsLink: View {
  var expanded = false

  var body: some View {
    NavigationLink {
      MacTransferDebugLogView()
    } label: {
      if expanded {
        HStack(spacing: 20) {
          Image(systemName: "calendar.badge.clock")
            .font(.system(size: 32))
            .foregroundStyle(.blue)
            .frame(width: 60)
          VStack(alignment: .leading, spacing: 4) {
            Text(L10n.text("diagnostic_logs_title", table: "Settings"))
              .font(.headline).foregroundStyle(.primary)
            Text(L10n.text("diagnostic_logs_description", table: "Settings"))
              .font(.subheadline).foregroundStyle(.secondary)
          }
          Spacer()
          Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }.padding(.vertical, 8)
      } else {
        Label(L10n.text("diagnostic_logs_title", table: "Settings"),
          systemImage: "calendar.badge.clock")
      }
    }.accessibilityIdentifier("settings.diagnosticLogs")
  }
}
