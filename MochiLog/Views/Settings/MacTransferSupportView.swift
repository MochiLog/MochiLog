import MessageUI
import SwiftUI

@available(iOS 27, *)
struct MacTransferSupportView: View {
  @StateObject private var manager = MacTransferManager.shared
  @State private var nickname = ""
  @State private var email = ""
  @State private var message = ""
  @State private var showingComposer = false
  @State private var showingMailError = false
  private var valid: Bool {
    [nickname, email, message].allSatisfy {
      !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }

  var body: some View {
    Form {
      Section {
        Text(L10n.text("mt_078", table: "MacTransfer"))
      }
      Section(L10n.text("mt_079", table: "MacTransfer")) {
        TextField(L10n.text("mt_032", table: "MacTransfer"), text: $nickname)
          .textContentType(.nickname)
        TextField(L10n.text("mt_033", table: "MacTransfer"), text: $email)
          .textContentType(.emailAddress)
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)
      }
      Section(L10n.text("mt_034", table: "MacTransfer")) {
        TextEditor(text: $message).frame(minHeight: 140)
      }
      Section(L10n.text("mt_080", table: "MacTransfer")) {
        Label(L10n.text("mt_081", table: "MacTransfer"), systemImage: "iphone")
        Label(manager.latestMacDiagnosticsData() == nil
          ? (L10n.text("mt_082", table: "MacTransfer"))
          : (L10n.text("mt_083", table: "MacTransfer")),
          systemImage: "desktopcomputer")
        Text(L10n.text("mt_084", table: "MacTransfer"))
          .font(.caption).foregroundStyle(.secondary)
      }
      Section {
        Button(L10n.text("mt_038", table: "MacTransfer")) {
          if MFMailComposeViewController.canSendMail() { showingComposer = true }
          else { showingMailError = true }
        }.disabled(!valid)
      }
    }
    .navigationTitle(L10n.text("mt_022", table: "MacTransfer"))
    .sheet(isPresented: $showingComposer) {
      MailComposeView(recipients: ["support@mochilog.ryuya-dev.net"],
        subject: "[MochiLog] \(L10n.text("mt_040", table: "MacTransfer"))",
        body: """
        \(L10n.text("mt_032", table: "MacTransfer")): \(nickname)
        \(L10n.text("mt_033", table: "MacTransfer")): \(email)

        \(L10n.text("mt_034", table: "MacTransfer")):
        \(message)
        """,
        attachments: attachments) { _ in }
    }
    .alert(L10n.text("mt_085", table: "MacTransfer"),
      isPresented: $showingMailError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(L10n.text("mt_086", table: "MacTransfer"))
    }
    .onAppear { manager.start() }
  }

  private var attachments: [MailAttachment] {
    var result = [MailAttachment(data: manager.supportDiagnosticsData(),
      mimeType: "application/json", fileName: "mochilog-iphone-diagnostics.json")]
    if let mac = manager.latestMacDiagnosticsData() {
      result.append(MailAttachment(data: mac, mimeType: "application/json",
        fileName: "mochilog-mac-diagnostics.json"))
    }
    return result
  }
}
