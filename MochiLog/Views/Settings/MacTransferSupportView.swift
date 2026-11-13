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
  @State private var preparingAttachments = false
  @State private var preparedAttachments: [MailAttachment] = []
  @State private var exportDirectory: URL?
  @State private var preparationError: String?
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
        DatePicker(
          L10n.text("mt_log_incident", table: "MacTransfer"),
          selection: $incidentDate, displayedComponents: [.date, .hourAndMinute])
        Text(L10n.text("mt_log_support_days", table: "MacTransfer"))
          .font(.caption).foregroundStyle(.secondary)
      }
      Section(L10n.text("mt_080", table: "MacTransfer")) {
        Label(L10n.text("mt_081", table: "MacTransfer"), systemImage: "iphone")
        if CrashDiagnostics.shared.latest() != nil {
          Label(
            L10n.string("attach_app_diagnostic", table: "Support"),
            systemImage: "waveform.path.ecg")
        }
        Label(
          manager.latestMacDiagnosticsData() == nil
            ? (L10n.text("mt_082", table: "MacTransfer"))
            : (L10n.text("mt_083", table: "MacTransfer")),
          systemImage: "desktopcomputer")
        Text(L10n.text("mt_084", table: "MacTransfer"))
          .font(.caption).foregroundStyle(.secondary)
      }
      Section {
        Button(L10n.text("mt_038", table: "MacTransfer")) {
          if MFMailComposeViewController.canSendMail() {
            prepareMail()
          } else {
            showingMailError = true
          }
        }.disabled(!valid || preparingAttachments)
        if preparingAttachments { ProgressView() }
      }
    }
    .formStyle(.grouped)
    .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 860 : .infinity)
    .frame(maxWidth: .infinity)
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationTitle(L10n.text("mt_022", table: "MacTransfer"))
    .sheet(isPresented: $showingComposer, onDismiss: clearPreparedFiles) {
      MailComposeView(
        recipients: ["support@mochilog.ryuya-dev.net"],
        subject: "[MochiLog] \(L10n.text("mt_040", table: "MacTransfer"))",
        body: """
          \(L10n.text("mt_032", table: "MacTransfer")): \(nickname)
          \(L10n.text("mt_033", table: "MacTransfer")): \(email)
          \(L10n.text("mt_log_incident", table: "MacTransfer")): \(incidentDate.formatted(date: .abbreviated, time: .shortened))

          \(L10n.text("mt_034", table: "MacTransfer")):
          \(message)
          """,
        attachments: preparedAttachments
      ) { _ in }
    }
    .alert(
      L10n.text("mt_085", table: "MacTransfer"),
      isPresented: $showingMailError
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(L10n.text("mt_086", table: "MacTransfer"))
    }
    .alert(
      L10n.text("mt_085", table: "MacTransfer"),
      isPresented: Binding(
        get: { preparationError != nil }, set: { if !$0 { preparationError = nil } })
    ) {
      Button("OK", role: .cancel) { preparationError = nil }
    } message: {
      Text(preparationError ?? "")
    }
    .onAppear { manager.receiveNow() }
  }

  private func clearPreparedFiles() {
    if let exportDirectory { try? FileManager.default.removeItem(at: exportDirectory) }
    exportDirectory = nil
    preparedAttachments = []
  }

  private func prepareMail() {
    guard !preparingAttachments else { return }
    clearPreparedFiles()
    preparingAttachments = true
    MacTransferManager.appendDebugEvent("PC support: attachment export started")
    var sources = [
      SupportLogExport.Source(name: "mochilog-iphone", directory: manager.debugLogDirectory())
    ]
    var diagnostics = [
      SupportLogExport.Diagnostic(
        name: "mochilog-iphone-diagnostics.json", data: manager.supportDiagnosticsData())
    ]
    var unavailable: [String] = []
    if manager.pairings.isEmpty {
      unavailable.append(
        "computer: app pairing not completed; remote logs/diagnostics have not been received")
    }
    for computer in manager.pairings {
      let name = "mochilog-computer-" + computer.hostID.uuidString
      sources.append(.init(name: name, directory: manager.debugLogDirectory(for: computer.hostID)))
      if let report = manager.computerDiagnosticsData(for: computer.hostID) {
        diagnostics.append(.init(name: name + "-diagnostics.json", data: report))
      } else {
        unavailable.append(name + ": remote diagnostics not yet received")
      }
    }
    if let diagnostic = CrashDiagnostics.shared.latest() {
      diagnostics.append(.init(name: "mochilog-ios-app-diagnostic.json", data: diagnostic))
    }
    let days = SupportLogExport.days(around: incidentDate)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "MochiLog-Support-" + UUID().uuidString)
    let exportSources = sources
    let exportDiagnostics = diagnostics
    let missing = unavailable
    Task { @MainActor in
      defer { preparingAttachments = false }
      do {
        let prepared = try await Task.detached(priority: .utility) {
          let urls = try SupportLogExport.prepare(
            sources: exportSources, days: days,
            diagnostics: exportDiagnostics, unavailable: missing, directory: directory)
          return try urls.map { url in
            MailAttachment(
              data: try Data(contentsOf: url),
              mimeType: url.pathExtension == "json" ? "application/json" : "text/plain",
              fileName: url.lastPathComponent)
          }
        }.value
        exportDirectory = directory
        preparedAttachments = prepared
        MacTransferManager.appendDebugEvent(
          "PC support: attachment export prepared; files=\(prepared.count), bytes=\(prepared.reduce(0) { $0 + $1.data.count })"
        )
        showingComposer = true
      } catch {
        try? FileManager.default.removeItem(at: directory)
        MacTransferManager.appendDebugEvent(
          "PC support: attachment export failed; \(PairingTransport.errorSummary(error))")
        preparationError = error.localizedDescription
      }
    }
  }
}
