import SwiftUI

struct DeviceCatalogSettingsView: View {
  var body: some View {
    Form { DeviceCatalogSettingsSection() }
      .modifier(SettingsListTopMargin())
      .modifier(
        SettingsInlineNavigationTitle(
          title: L10n.string("catalog_title", table: "Settings")))
  }
}

private struct DeviceCatalogSettingsSection: View {
  @ObservedObject private var updater = DeviceCatalogUpdater.shared

  private func text(_ key: String) -> String {
    L10n.string(String.LocalizationValue(key), table: "Settings")
  }

  var body: some View {
    Section {
      Toggle(text("catalog_automatic"), isOn: $updater.automaticUpdates)
        .accessibilityIdentifier("catalog.automatic")
        .onChange(of: updater.automaticUpdates) { enabled in
          if enabled { Task { await updater.checkIfDue() } }
        }
      HStack {
        Text(text("catalog_version"))
        Spacer()
        Text(String(updater.dataRevision)).foregroundStyle(.secondary)
      }
      .accessibilityIdentifier("catalog.version")
      HStack {
        Text(text("catalog_last_checked"))
        Spacer()
        if let date = updater.lastChecked {
          Text(date, format: .dateTime.year().month().day().hour().minute())
            .foregroundStyle(.secondary)
        } else {
          Text(text("catalog_never_checked")).foregroundStyle(.secondary)
        }
      }
      Button {
        Task { await updater.check() }
      } label: {
        HStack {
          Label(text("catalog_check_now"), systemImage: "arrow.triangle.2.circlepath")
          Spacer()
          if updater.isChecking { ProgressView() }
        }
      }
      .disabled(updater.isChecking)
      .accessibilityIdentifier("catalog.checkNow")
      if let key = updater.messageKey {
        Text(text(key)).font(.footnote).foregroundStyle(.secondary)
          .accessibilityIdentifier("catalog.result")
      }
    } header: {
      Text(text("catalog_title"))
    } footer: {
      Text(text("catalog_footer"))
    }
  }
}
