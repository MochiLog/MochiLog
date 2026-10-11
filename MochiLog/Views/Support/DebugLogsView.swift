import SwiftUI
import UIKit

struct DebugLogsView: View {
  @State private var days: [ErrorLogDay] = []
  @State private var selectedID: String?
  @State private var query = ""
  @State private var revision = 0
  @State private var loading = true
  @State private var showingDeleteAllConfirm = false

  private struct Request: Hashable { let revision: Int; let query: String }
  private var selected: ErrorLogEntry? {
    days.lazy.flatMap(\.entries).first { $0.id == selectedID }
  }

  var body: some View {
    GeometryReader { geometry in
      let wide = geometry.size.width >= 700
      HStack(spacing: 0) {
        logList(wide: wide)
          .frame(maxWidth: wide ? min(340, geometry.size.width * 0.4) : .infinity)
        if wide {
          Divider()
          if let selected {
            DebugLogDetailContentView(entry: selected)
              .frame(maxWidth: .infinity).id(selected.id)
          } else {
            VStack(spacing: 12) {
              Image(systemName: "doc.text.magnifyingglass").font(.largeTitle).foregroundStyle(.secondary)
              Text(L10n.string("select_log_message", table: "Support"))
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding().frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        }
      }
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationTitle(L10n.string("view_error_logs", table: "Support"))
    .navigationBarTitleDisplayMode(.inline)
    .searchable(text: $query, prompt: L10n.string("error_log_search", table: "Support"))
    .toolbar {
      ToolbarItemGroup(placement: .navigationBarTrailing) {
        Button { revision += 1 } label: { Image(systemName: "arrow.clockwise") }
          .accessibilityLabel(L10n.text("mt_015", table: "MacTransfer"))
        Button(role: .destructive) { showingDeleteAllConfirm = true } label: {
          Image(systemName: "trash")
        }.disabled(days.isEmpty || loading)
          .accessibilityLabel(L10n.string("clear_all_logs", table: "Home"))
      }
    }
    .task(id: Request(revision: revision, query: query)) {
      loading = true
      let query = query
      let loaded = await Task.detached(priority: .userInitiated) {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.environment["MOCHI_ERROR_LOG_UI"] == "1",
          ErrorLogStore.shared.listLogs().isEmpty {
          ErrorLogStore.shared.saveLog(message: "Large log UI fixture", rawText:
            String(repeating: "Connection: ready 日本語🧪\n", count: 108_672))
        }
        #endif
        return ErrorLogPresentation.days(ErrorLogStore.shared.listLogs(), query: query)
      }.value
      guard !Task.isCancelled else { return }
      days = loaded
      if selected == nil { selectedID = days.first?.entries.first?.id }
      loading = false
    }
    .confirmationDialog(L10n.string("delete_all_logs_confirm", table: "Home"),
      isPresented: $showingDeleteAllConfirm, titleVisibility: .visible) {
      Button(L10n.string("delete", table: "Common"), role: .destructive) {
        Task {
          await Task.detached { ErrorLogStore.shared.clearAll() }.value
          selectedID = nil; revision += 1
        }
      }
    }
  }

  private func logList(wide: Bool) -> some View {
    List {
      if loading {
        ProgressView(L10n.string("loading_logs", table: "Support"))
      }
      if days.isEmpty && !loading {
        Label(L10n.string(query.isEmpty ? "no_error_logs" : "error_log_no_results", table: "Support"),
          systemImage: query.isEmpty ? "checkmark.circle" : "magnifyingglass")
          .foregroundStyle(.secondary)
      }
      ForEach(days) { day in
        Section {
          ForEach(day.entries) { entry in
            Group {
              if wide {
                Button { selectedID = entry.id } label: { row(entry) }
                  .buttonStyle(.plain)
              } else {
                NavigationLink { DebugLogDetailContentView(entry: entry) } label: { row(entry) }
              }
            }
            .listRowBackground(wide && selectedID == entry.id ? Color.accentColor.opacity(0.12) : nil)
            .swipeActions {
              Button(role: .destructive) {
                Task {
                  await Task.detached { ErrorLogStore.shared.deleteLog(id: entry.id) }.value
                  if selectedID == entry.id { selectedID = nil }
                  revision += 1
                }
              } label: { Label(L10n.string("delete", table: "Common"), systemImage: "trash") }
            }
          }
        } header: {
          HStack { Text(day.date, style: .date); Spacer(); Text("\(day.entries.count)") }
        }
      }
    }
    .listStyle(.insetGrouped)
    .accessibilityIdentifier("errorLogs.list")
  }

  private func row(_ entry: ErrorLogEntry) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
      VStack(alignment: .leading, spacing: 5) {
        Text(entry.message).lineLimit(3).foregroundStyle(.primary)
        Text(entry.timestamp, style: .time).font(.caption).foregroundStyle(.secondary)
      }
    }.padding(.vertical, 5)
  }
}

struct DebugLogDetailContentView: View {
  let entry: ErrorLogEntry
  @State private var rawText = ""
  @State private var pages: [String] = []
  @State private var page = 0
  @State private var loading = true
  @State private var loadError: String?
  @State private var shareFileURL: URL?
  @State private var revision = 0

  private struct Request: Hashable { let id: String; let revision: Int }
  var body: some View {
    List {
      Section {
        Label(entry.timestamp.formatted(date: .abbreviated, time: .standard), systemImage: "clock")
          .font(.subheadline).foregroundStyle(.secondary)
        Text(entry.message).textSelection(.enabled)
      } header: { Text(L10n.string("message", table: "Support")) }
      Section {
        if loading {
          ProgressView(L10n.string("loading_logs", table: "Support"))
        } else if let loadError {
          Label(loadError, systemImage: "exclamationmark.triangle").foregroundStyle(.secondary)
        } else if pages.isEmpty {
          Text(L10n.string("empty_log_preview", table: "Records")).foregroundStyle(.secondary)
        } else {
          Text(pages[page]).font(.system(.caption, design: .monospaced))
            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("errorLogs.detail.text")
          DiagnosticLogPageControls(page: $page, count: pages.count)
        }
      } header: { Text(L10n.string("details_label", table: "Support")) }
      Section {
        Button { UIPasteboard.general.string = entry.message + "\n" + rawText } label: {
          Label(L10n.text("mt_046", table: "MacTransfer"), systemImage: "doc.on.doc")
        }.disabled(loading)
        if let shareFileURL {
          ShareLink(item: shareFileURL) {
            Label(L10n.string("share_label", table: "Support"), systemImage: "square.and.arrow.up")
          }
        }
        Button { revision += 1 } label: {
          Label(L10n.text("mt_015", table: "MacTransfer"), systemImage: "arrow.clockwise")
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle(L10n.string("log_details", table: "Records"))
    .navigationBarTitleDisplayMode(.inline)
    .task(id: Request(id: entry.id, revision: revision)) {
      loading = true
      let entry = entry
      let snapshot = await Task.detached(priority: .userInitiated) {
        do {
          let original = ErrorLogStore.shared.rawFileURL(id: entry.id)
          let text = try original.map { try String(contentsOf: $0, encoding: .utf8) }
            ?? entry.rawTextPreview ?? ""
          let url: URL
          if let original { url = original }
          else {
            url = FileManager.default.temporaryDirectory.appendingPathComponent(entry.id)
            try JSONEncoder().encode(entry).write(to: url, options: .atomic)
          }
          return (text, DiagnosticLogViewer.pages(text), Optional(url), Optional<String>.none)
        } catch { return ("", [String](), Optional<URL>.none, Optional(error.localizedDescription)) }
      }.value
      guard !Task.isCancelled else { return }
      rawText = snapshot.0; pages = snapshot.1; shareFileURL = snapshot.2
      loadError = snapshot.3; page = 0; loading = false
    }
  }
}

/// One set of page controls for failed imports and connection diagnostics.
struct DiagnosticLogPageControls: View {
  @Binding var page: Int
  let count: Int
  var body: some View {
    HStack {
      Button(L10n.text("mt_log_previous", table: "MacTransfer")) { page -= 1 }
        .disabled(page == 0)
      Spacer()
      Text(String(format: L10n.text("mt_log_page", table: "MacTransfer"),
        count == 0 ? 0 : page + 1, count)).font(.caption).foregroundStyle(.secondary)
      Spacer()
      Button(L10n.text("mt_log_next", table: "MacTransfer")) { page += 1 }
        .disabled(page + 1 >= count)
    }.buttonStyle(.borderless)
  }
}
