import SwiftUI
import UIKit

@available(iOS 27, *)
struct MacTransferDebugLogView: View {
  @StateObject private var manager = MacTransferManager.shared
  @State private var revision = 0

  private var days: [String] {
    _ = revision
    return manager.debugLogDays()
  }

  private var hasComputerLog: Bool {
    _ = revision
    return !manager.macDebugLogText().isEmpty
  }

  var body: some View {
    List {
      Section {
        Text(L10n.text("mt_087", table: "MacTransfer"))
          .foregroundStyle(.secondary)
      }

      Section(L10n.text("mt_log_days_title", table: "MacTransfer")) {
        if days.isEmpty {
          Label(L10n.text("mt_log_no_days", table: "MacTransfer"),
            systemImage: "calendar.badge.exclamationmark")
            .foregroundStyle(.secondary)
        } else {
          ForEach(days, id: \.self) { day in
            NavigationLink {
              MacTransferLogDayView(day: day)
            } label: {
              Label(Self.displayDate(day), systemImage: "calendar")
                .padding(.vertical, 5)
            }
          }
        }
      }

      Section(L10n.text("mt_log_remote_title", table: "MacTransfer")) {
        if hasComputerLog {
          NavigationLink {
            MacTransferLogDayView(day: nil)
          } label: {
            Label(L10n.text("mt_log_remote_title", table: "MacTransfer"),
              systemImage: "desktopcomputer")
              .padding(.vertical, 5)
          }
        } else {
          Label(L10n.text("mt_047", table: "MacTransfer"),
            systemImage: "desktopcomputer")
            .foregroundStyle(.secondary)
        }
      }

      Section {
        NavigationLink {
          MacTransferLogStorageView()
        } label: {
          LabeledContent(
            L10n.text("mt_log_storage_title", table: "MacTransfer"),
            value: String(format: L10n.text("mt_log_days_count", table: "MacTransfer"),
              manager.debugRetentionDays)
          )
          .padding(.vertical, 5)
        }
      } footer: {
        Text(L10n.text("mt_log_retention_help", table: "MacTransfer"))
      }
    }
    .navigationTitle(L10n.text("mt_026", table: "MacTransfer"))
    .onAppear { revision += 1 }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          revision += 1
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .accessibilityLabel(L10n.text("mt_015", table: "MacTransfer"))
      }
    }
  }

  fileprivate static func displayDate(_ day: String) -> String {
    let parser = DateFormatter()
    parser.calendar = Calendar(identifier: .gregorian)
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.timeZone = .current
    parser.dateFormat = "yyyy-MM-dd"
    guard let date = parser.date(from: day) else { return day }
    return date.formatted(.dateTime.year().month().day())
  }
}

@available(iOS 27, *)
private struct MacTransferLogDayView: View {
  @StateObject private var manager = MacTransferManager.shared
  @State private var logText = ""
  let day: String?

  private var title: String {
    if let day { return MacTransferDebugLogView.displayDate(day) }
    return L10n.text("mt_log_remote_title", table: "MacTransfer")
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 6) {
        if logText.isEmpty {
          Text(L10n.text("mt_047", table: "MacTransfer"))
            .foregroundStyle(.secondary)
        } else {
          ForEach(Array(logText.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()), id: \.offset) { _, line in
            Text(String(line))
              .font(.system(.caption, design: .monospaced))
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
      .padding(16)
      .frame(maxWidth: 1000, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationTitle(title)
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button {
          reload()
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .accessibilityLabel(L10n.text("mt_015", table: "MacTransfer"))
        Button(L10n.text("mt_046", table: "MacTransfer")) {
          UIPasteboard.general.string = logText
        }
        .disabled(logText.isEmpty)
      }
    }
    .onAppear(perform: reload)
  }

  private func reload() {
    logText = day.map { manager.debugLogText(for: $0) }
      ?? manager.macDebugLogText()
  }
}

@available(iOS 27, *)
private struct MacTransferLogStorageView: View {
  @StateObject private var manager = MacTransferManager.shared
  @State private var revision = 0
  @State private var showingDeleteConfirmation = false

  private let choices = [7, 30, 90, 180, 365]

  private var hasLogs: Bool {
    _ = revision
    return !manager.debugLogDays().isEmpty
  }

  var body: some View {
    List {
      Section {
        Text(L10n.text("mt_log_retention_help", table: "MacTransfer"))
          .foregroundStyle(.secondary)
      }

      Section(L10n.text("mt_log_retention", table: "MacTransfer")) {
        ForEach(choices, id: \.self) { duration in
          Button {
            manager.debugRetentionDays = duration
            revision += 1
          } label: {
            HStack {
              Text(String(format: L10n.text("mt_log_days_count", table: "MacTransfer"),
                duration))
                .foregroundStyle(.primary)
              Spacer()
              if manager.debugRetentionDays == duration {
                Image(systemName: "checkmark")
                  .fontWeight(.semibold)
              }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
          }
          .buttonStyle(.plain)
        }
      }

      Section {
        Button(L10n.text("mt_log_delete", table: "MacTransfer"),
          role: .destructive) {
          showingDeleteConfirmation = true
        }
        .disabled(!hasLogs)
      } footer: {
        Text(L10n.text("mt_log_delete_help", table: "MacTransfer"))
      }
    }
    .navigationTitle(L10n.text("mt_log_storage_title", table: "MacTransfer"))
    .confirmationDialog(
      L10n.text("mt_log_delete_confirm", table: "MacTransfer"),
      isPresented: $showingDeleteConfirmation
    ) {
      Button(L10n.text("mt_log_delete", table: "MacTransfer"),
        role: .destructive) {
        manager.clearDebugLogs()
        revision += 1
      }
    }
  }
}
