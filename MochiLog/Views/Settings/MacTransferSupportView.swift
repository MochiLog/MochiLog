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
  private var japanese: Bool { Locale.preferredLanguages.first?.hasPrefix("ja") == true }
  private var valid: Bool {
    [nickname, email, message].allSatisfy {
      !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }

  var body: some View {
    Form {
      Section {
        Text(japanese
          ? "Mac連携はベータ版です。解決まで時間がかかる場合があり、個別に返信できない場合もあります。"
          : "Mac transfer is in beta. A fix may take time, and we may not be able to reply individually.")
      }
      Section(japanese ? "連絡先" : "Contact") {
        TextField(japanese ? "ニックネーム" : "Nickname", text: $nickname)
          .textContentType(.nickname)
        TextField(japanese ? "返信先メールアドレス" : "Reply email", text: $email)
          .textContentType(.emailAddress)
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)
      }
      Section(japanese ? "発生した問題・再現手順" : "Problem and steps to reproduce") {
        TextEditor(text: $message).frame(minHeight: 140)
      }
      Section(japanese ? "添付する診断情報" : "Diagnostic attachments") {
        Label(japanese ? "iPhoneの状態" : "iPhone status", systemImage: "iphone")
        Label(manager.latestMacDiagnosticsData() == nil
          ? (japanese ? "Macの状態：未受信" : "Mac status: not received")
          : (japanese ? "Macの状態：受信済み" : "Mac status: received"),
          systemImage: "desktopcomputer")
        Text(japanese
          ? "Macの情報を更新するには同じWi-FiでMacアプリを開き、この画面を開き直してください。解析ログ本文やペアリングの秘密鍵は含めません。"
          : "To refresh the Mac report, open the Mac app on the same Wi-Fi, then reopen this screen. Raw analytics logs and pairing secrets are excluded.")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section {
        Button(japanese ? "メールを作成" : "Compose email") {
          if MFMailComposeViewController.canSendMail() { showingComposer = true }
          else { showingMailError = true }
        }.disabled(!valid)
      }
    }
    .navigationTitle(japanese ? "Mac連携のサポート" : "Mac transfer support")
    .sheet(isPresented: $showingComposer) {
      MailComposeView(recipients: ["support@mochilog.ryuya-dev.net"],
        subject: "[MochiLog] \(japanese ? "Mac連携ベータ" : "Mac transfer beta")",
        body: """
        \(japanese ? "ニックネーム" : "Nickname"): \(nickname)
        \(japanese ? "返信先" : "Reply email"): \(email)

        \(japanese ? "問題・再現手順" : "Problem and steps to reproduce"):
        \(message)
        """,
        attachments: attachments) { _ in }
    }
    .alert(japanese ? "メールを作成できません" : "Cannot compose email",
      isPresented: $showingMailError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(japanese ? "端末にメールアカウントを設定してください。"
        : "Set up an email account on this device.")
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
