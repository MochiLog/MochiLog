import MessageUI
import SwiftUI

@available(iOS 27, *)
struct MacTransferSupportView: View {
  @StateObject private var manager = MacTransferManager.shared
  @State private var nickname = ""
  @State private var email = ""
  @State private var message = ""
  @State private var incidentDate = Date()
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
      Section(L10n.text("mt_log_incident", table: "MacTransfer")) {
        DatePicker(L10n.text("mt_log_incident", table: "MacTransfer"),
          selection: $incidentDate, displayedComponents: [.date, .hourAndMinute])
        Text(L10n.text("mt_log_support_days", table: "MacTransfer"))
          .font(.caption).foregroundStyle(.secondary)
      }
      Section(L10n.text("mt_080", table: "MacTransfer")) {
        Label(L10n.text("mt_081", table: "MacTransfer"), systemImage: "iphone")
        if CrashDiagnostics.shared.latest() != nil {
          Label(L10n.string("attach_app_diagnostic", table: "Support"),
            systemImage: "waveform.path.ecg")
        }
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
    .formStyle(.grouped)
    .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 860 : .infinity)
    .frame(maxWidth: .infinity)
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationTitle(L10n.text("mt_022", table: "MacTransfer"))
    .sheet(isPresented: $showingComposer) {
      MailComposeView(recipients: ["support@mochilog.ryuya-dev.net"],
        subject: "[MochiLog] \(L10n.text("mt_040", table: "MacTransfer"))",
        body: """
        \(L10n.text("mt_032", table: "MacTransfer")): \(nickname)
        \(L10n.text("mt_033", table: "MacTransfer")): \(email)
        \(L10n.text("mt_log_incident", table: "MacTransfer")): \(incidentDate.formatted(date: .abbreviated, time: .shortened))

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
    .onAppear { manager.receiveNow() }
  }

  private var attachments: [MailAttachment] {
    var result = [MailAttachment(data: manager.supportDiagnosticsData(),
      mimeType: "application/json", fileName: "mochilog-iphone-diagnostics.json")]
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = "yyyy-MM-dd"
    for offset in -2...0 {
      guard let date = Calendar.current.date(byAdding: .day, value: offset,
        to: incidentDate) else { continue }
      let day = formatter.string(from: date)
      result.append(MailAttachment(data: Data(manager.debugLogText(for: day).utf8),
        mimeType: "text/plain", fileName: "mochilog-iphone-debug-\(day).log"))
      for computer in manager.pairings {
        let text = manager.computerDebugLogText(for: computer.hostID, day: day)
        result.append(MailAttachment(data: Data(text.utf8),
          mimeType: "text/plain",
          fileName: "mochilog-computer-\(computer.hostID.uuidString.prefix(8))-debug-\(day).log"))
      }
    }
    if let diagnostic = CrashDiagnostics.shared.latest() {
      result.append(MailAttachment(data: diagnostic, mimeType: "application/json",
        fileName: "mochilog-ios-app-diagnostic.json"))
    }
    if let mac = manager.latestMacDiagnosticsData() {
      let computer = manager.pairing?.platform == "windows" ? "windows" : "mac"
      result.append(MailAttachment(data: mac, mimeType: "application/json",
        fileName: "mochilog-\(computer)-diagnostics.json"))
    }
    return result
  }
}
