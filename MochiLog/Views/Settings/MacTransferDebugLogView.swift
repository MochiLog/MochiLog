import SwiftUI
import UIKit

@available(iOS 27, *)
struct MacTransferDebugLogView: View {
  @Environment(\.horizontalSizeClass) private var sizeClass
  @StateObject private var manager = MacTransferManager.shared
  @State private var revision = 0
  @State private var selectedDay: String?
  @State private var showingDeleteConfirmation = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text(L10n.text("mt_087", table: "MacTransfer"))
          .foregroundStyle(.secondary)
        HStack {
          Menu {
            ForEach(availableDays, id: \.self) { day in
              Button(day) { selectedDay = day }
            }
          } label: {
            Label(selectedDay ?? L10n.text("mt_log_no_days", table: "MacTransfer"),
              systemImage: "calendar")
          }
          .disabled(availableDays.isEmpty)
          Spacer()
          Picker(L10n.text("mt_log_retention", table: "MacTransfer"), selection: Binding(
            get: { manager.debugRetentionDays },
            set: { manager.debugRetentionDays = $0; revision += 1;
              selectedDay = availableDays.first }
          )) {
            ForEach([7, 30, 90, 180, 365], id: \.self) { days in
              Text("\(days)").tag(days)
            }
          }
          .fixedSize()
        }
        Button(L10n.text("mt_log_delete", table: "MacTransfer"), role: .destructive) {
          showingDeleteConfirmation = true
        }
        .disabled(availableDays.isEmpty)
        if sizeClass == .regular {
          HStack(alignment: .top, spacing: 16) {
            panel(L10n.text("mt_088", table: "MacTransfer"), text: localLog)
            panel("Mac", text: macLog)
          }
        } else {
          panel(L10n.text("mt_088", table: "MacTransfer"), text: localLog)
          panel("Mac", text: macLog)
        }
      }
      .frame(maxWidth: 1100)
      .frame(maxWidth: .infinity)
      .padding()
    }
    .navigationTitle(L10n.text("mt_026", table: "MacTransfer"))
    .onAppear { selectedDay = availableDays.first }
    .confirmationDialog(L10n.text("mt_log_delete_confirm", table: "MacTransfer"),
      isPresented: $showingDeleteConfirmation) {
      Button(L10n.text("mt_log_delete", table: "MacTransfer"), role: .destructive) {
        manager.clearDebugLogs()
        revision += 1
        selectedDay = nil
      }
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(L10n.text("mt_015", table: "MacTransfer")) {
          revision += 1
          if selectedDay == nil { selectedDay = availableDays.first }
        }
      }
    }
  }

  private var availableDays: [String] { _ = revision; return manager.debugLogDays() }
  private var localLog: String {
    _ = revision
    return selectedDay.map { manager.debugLogText(for: $0) } ?? manager.debugLogText()
  }
  private var macLog: String { _ = revision; return manager.macDebugLogText() }

  private func panel(_ title: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(title).font(.headline)
        Spacer()
        Button(L10n.text("mt_046", table: "MacTransfer")) { UIPasteboard.general.string = text }
          .disabled(text.isEmpty)
      }
      Text(text.isEmpty ? (L10n.text("mt_047", table: "MacTransfer")) : text)
        .font(.system(.caption, design: .monospaced))
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
    }
    .padding(16)
    .background(Color(uiColor: .secondarySystemGroupedBackground),
      in: RoundedRectangle(cornerRadius: 16))
    .frame(maxWidth: .infinity)
  }
}
