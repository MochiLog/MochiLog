import SwiftUI
import UIKit

@available(iOS 17, *)
struct MacTransferDebugLogView: View {
  @StateObject private var manager = MacTransferManager.shared
  @State private var revision = 0

  @State private var days: [String] = []
  @State private var computerDays: [UUID: [String]] = [:]
  @State private var loading = true

  var body: some View {
    List {
      Section {
        Text(L10n.text("diagnostic_logs_description", table: "Settings"))
          .foregroundStyle(.secondary)
      }

      Section(L10n.text("mt_log_days_title", table: "MacTransfer")) {
        if loading {
          ProgressView(L10n.text("mt_log_loading", table: "MacTransfer"))
        } else if days.isEmpty {
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

      ForEach(manager.pairings, id: \.hostID) { computer in
        Section(computerTitle(computer)) {
          let computerDays = computerDays[computer.hostID] ?? []
          if computerDays.isEmpty {
            Label(L10n.text("mt_log_no_days", table: "MacTransfer"),
              systemImage: "desktopcomputer")
              .foregroundStyle(.secondary)
          } else {
            ForEach(computerDays, id: \.self) { day in
              NavigationLink {
                MacTransferLogDayView(day: day, hostID: computer.hostID)
              } label: {
                Label(Self.displayDate(day), systemImage: "desktopcomputer")
                  .padding(.vertical, 5)
              }
            }
          }
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
        }.accessibilityIdentifier("diagnosticLogs.storage")
      } footer: {
        Text(L10n.text("mt_log_retention_help", table: "MacTransfer"))
      }
    }
    .navigationTitle(L10n.text("diagnostic_logs_title", table: "Settings"))
    .accessibilityIdentifier("diagnosticLogs.list")
    .task(id: revision) {
      loading = true
      let root = manager.debugLogDirectory()
      let roots = manager.pairings.map { ($0.hostID, manager.debugLogDirectory(for: $0.hostID)) }
      let catalog = await Task.detached(priority: .userInitiated) {
        (DiagnosticLogViewer.days(in: root), Dictionary(uniqueKeysWithValues:
          roots.map { ($0.0, DiagnosticLogViewer.days(in: $0.1)) }))
      }.value
      guard !Task.isCancelled else { return }
      days = catalog.0; computerDays = catalog.1; loading = false
      // Viewing saved diagnostics must not bypass the daily hold or start a transfer.
    }
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

  private func computerTitle(_ computer: MacTransferPairing) -> String {
    let platform = computer.platform == "Windows" ? "Windows" : "Mac"
    let suffix = manager.pairings.count > 1
      ? " · \(computer.hostID.uuidString.prefix(6))" : ""
    return "\(platform)\(suffix)"
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

@available(iOS 17, *)
private struct MacTransferLogDayView: View {
  @StateObject private var manager = MacTransferManager.shared
  @State private var fullText = ""
  @State private var categories: [String] = []
  @State private var category: String?
  @State private var pages: [String] = []
  @State private var page = 0
  @State private var loading = true
  @State private var loadError: String?
  @State private var revision = 0
  let day: String?
  var hostID: UUID? = nil
  private struct Request: Hashable { let day: String?; let host: UUID?; let category: String?; let revision: Int }

  private func categoryTitle(_ category: String) -> String {
    switch category {
    case "background": return L10n.text("mt_log_background", table: "MacTransfer")
    case "local-collection": return L10n.text("mt_log_local_collection", table: "MacTransfer")
    case "pc-transfer": return L10n.text("mt_log_pc_transfer", table: "MacTransfer")
    case "live-battery": return L10n.text("mt_log_live_battery", table: "MacTransfer")
    case "cloud-sync": return L10n.text("mt_log_cloud_sync", table: "MacTransfer")
    case "pairing": return L10n.text("mt_log_pairing", table: "MacTransfer")
    default: return L10n.text("mt_log_general", table: "MacTransfer")
    }
  }

  var body: some View {
    List {
      Section {
        Picker(L10n.text("mt_log_category", table: "MacTransfer"), selection: $category) {
          Text(L10n.text("mt_log_all", table: "MacTransfer")).tag(Optional<String>.none)
          ForEach(categories, id: \.self) { value in
            Text(categoryTitle(value))
              .tag(Optional(value))
          }
        }
      }
      Section {
        if loading {
          ProgressView(L10n.text("mt_log_loading", table: "MacTransfer"))
        } else if let loadError {
          Label(loadError, systemImage: "exclamationmark.triangle").foregroundStyle(.secondary)
        } else if pages.isEmpty {
          Text(L10n.text("mt_047", table: "MacTransfer")).foregroundStyle(.secondary)
        } else {
          DiagnosticLogPageControls(page: $page, count: pages.count)
          Text(pages[page]).font(.system(.caption, design: .monospaced))
            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
    .navigationTitle(day.map(MacTransferDebugLogView.displayDate)
      ?? L10n.text("mt_log_remote_title", table: "MacTransfer"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button { revision += 1 } label: { Image(systemName: "arrow.clockwise") }
          .accessibilityLabel(L10n.text("mt_015", table: "MacTransfer"))
        Button(L10n.text("mt_046", table: "MacTransfer")) { UIPasteboard.general.string = fullText }
          .disabled(loading || fullText.isEmpty)
      }
    }
    .task(id: Request(day: day, host: hostID, category: category, revision: revision)) {
      loading = true
      let root = manager.debugLogDirectory(for: hostID)
      let selectedDay = day; let selectedCategory = category
      let snapshot = await Task.detached(priority: .userInitiated) {
        do {
          guard let selectedDay,
            selectedDay.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil
          else { return ([String](), "", [String](), Optional<String>.none) }
          let raw = try String(contentsOf: root.appendingPathComponent(selectedDay + ".log"), encoding: .utf8)
          let text = DiagnosticLogViewer.text(raw, category: selectedCategory)
          return (DiagnosticLogViewer.categories(in: raw), text, DiagnosticLogViewer.pages(text), Optional<String>.none)
        } catch { return ([String](), "", [String](), Optional(error.localizedDescription)) }
      }.value
      guard !Task.isCancelled else { return }
      categories = snapshot.0; fullText = snapshot.1; pages = snapshot.2
      loadError = snapshot.3; page = 0; loading = false
    }
  }
}

@available(iOS 17, *)
private struct MacTransferLogStorageView: View {
  @StateObject private var manager = MacTransferManager.shared
  @State private var revision = 0
  @State private var showingDeleteConfirmation = false

  private let choices = [7, 30, 90, 180, 365]

  @State private var hasLogs = false

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
    .task(id: revision) {
      let root = manager.debugLogDirectory()
      let result = await Task.detached { !DiagnosticLogViewer.days(in: root).isEmpty }.value
      guard !Task.isCancelled else { return }
      hasLogs = result
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
