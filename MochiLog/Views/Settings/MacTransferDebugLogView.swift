import SwiftUI
import UIKit

@available(iOS 27, *)
struct MacTransferDebugLogView: View {
  @Environment(\.horizontalSizeClass) private var sizeClass
  @StateObject private var manager = MacTransferManager.shared
  @State private var revision = 0

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text(L10n.text("mt_087", table: "MacTransfer"))
          .foregroundStyle(.secondary)
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
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(L10n.text("mt_015", table: "MacTransfer")) { revision += 1 }
      }
    }
  }

  private var localLog: String { _ = revision; return manager.debugLogText() }
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
