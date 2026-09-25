import MessageUI
import SwiftUI

// MARK: - 問い合わせの種類
enum InquiryType: String, CaseIterable, Identifiable {
  case bug = "inquiry_bug"
  case batteryCapacity = "inquiry_battery_capacity"
  case feature = "inquiry_feature"
  case question = "inquiry_question"
  case other = "inquiry_other"

  var id: String { rawValue }

  var localizedName: String {
    L10n.string(String.LocalizationValue(rawValue), table: "Support")
  }

  var messageTemplate: String? {
    guard self == .batteryCapacity else { return nil }
    return L10n.string("battery_capacity_report_template", table: "Support")
  }
}

// MARK: - サポートフォームビュー
struct SupportFormView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var appSettings = AppSettings.shared

  @State private var name = ""
  @State private var email = ""
  @State private var inquiryType: InquiryType = .question
  @State private var message = ""
  @State private var showingMailError = false
  @State private var showingValidationError = false
  @State private var isShowingMailCompose = false

  private var isFormValid: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty
      && !email.trimmingCharacters(in: .whitespaces).isEmpty
      && !message.trimmingCharacters(in: .whitespaces).isEmpty
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField(L10n.string("your_name", table: "Support"), text: $name)
            .textContentType(.nickname)

          TextField(L10n.string("email_address", table: "Support"), text: $email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
        }

        Section(L10n.string("inquiry_type", table: "Support")) {
          Picker(L10n.string("inquiry_type", table: "Support"), selection: $inquiryType) {
            ForEach(InquiryType.allCases) { type in
              Text(type.localizedName).tag(type)
            }
          }
          .pickerStyle(.menu)
          .onChange(of: inquiryType) { newValue in
            guard let template = newValue.messageTemplate,
              message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            message = template
          }
        }

        Section {
          TextEditor(text: $message)
            .frame(minHeight: 150)
        } header: {
          Text(L10n.string("message", table: "Support"))
        } footer: {
          Text(L10n.string("device_info_included", table: "Common"))
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle(L10n.string("contact_form", table: "Support"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.string("cancel", table: "Common")) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(L10n.string("send", table: "Common")) {
            sendEmail()
          }
          .disabled(!isFormValid)
        }
      }
      .alert(
        L10n.string("mail_not_configured", table: "Support"), isPresented: $showingMailError
      ) {
        Button(L10n.string("ok", table: "Common"), role: .cancel) {}
      } message: {
        Text(L10n.string("mail_not_configured_message", table: "Support"))
      }
      .alert(L10n.string("error", table: "Common"), isPresented: $showingValidationError) {
        Button(L10n.string("ok", table: "Common"), role: .cancel) {}
      } message: {
        Text(L10n.string("required_fields_empty", table: "Support"))
      }
      .sheet(isPresented: $isShowingMailCompose) {
        MailComposeView(
          recipients: ["support@mochilog.ryuya-dev.net"],
          subject: "[MochiLog] \(inquiryType.localizedName)",
          body: composeEmailBody()
        ) { result in
          if result == .sent {
            dismiss()
          }
        }
      }
    }
  }

  private func sendEmail() {
    guard isFormValid else {
      showingValidationError = true
      return
    }

    if MFMailComposeViewController.canSendMail() {
      isShowingMailCompose = true
    } else {
      // メールアプリが使えない場合はmailto URLを試す
      let subject = "[MochiLog] \(inquiryType.localizedName)"
      let body = composeEmailBody()

      if let encoded = "mailto:support@mochilog.ryuya-dev.net?subject=\(subject)&body=\(body)"
        .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
        let url = URL(string: encoded)
      {
        UIApplication.shared.open(url) { success in
          if success {
            dismiss()
          } else {
            showingMailError = true
          }
        }
      } else {
        showingMailError = true
      }
    }
  }

  private func composeEmailBody() -> String {
    """
    \(L10n.string("mail_body_name", table: "Support")): \(name)
    \(L10n.string("mail_body_email", table: "Support")): \(email)
    \(L10n.string("mail_body_type", table: "Support")): \(inquiryType.localizedName)

    \(L10n.string("mail_body_message", table: "Support")):
    \(message)

    \(appSettings.getDeviceInfo())
    """
  }
}

// MARK: - メール作成ビュー
struct MailComposeView: UIViewControllerRepresentable {
  let recipients: [String]
  let subject: String
  let body: String
  var attachments: [MailAttachment] = []
  let onComplete: (MFMailComposeResult) -> Void

  func makeUIViewController(context: Context) -> MFMailComposeViewController {
    let composer = MFMailComposeViewController()
    composer.mailComposeDelegate = context.coordinator
    composer.setToRecipients(recipients)
    composer.setSubject(subject)
    composer.setMessageBody(body, isHTML: false)
    for attachment in attachments {
      composer.addAttachmentData(attachment.data, mimeType: attachment.mimeType,
        fileName: attachment.fileName)
    }
    return composer
  }

  func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(onComplete: onComplete)
  }

  class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
    let onComplete: (MFMailComposeResult) -> Void

    init(onComplete: @escaping (MFMailComposeResult) -> Void) {
      self.onComplete = onComplete
    }

    func mailComposeController(
      _ controller: MFMailComposeViewController,
      didFinishWith result: MFMailComposeResult,
      error: Error?
    ) {
      controller.dismiss(animated: true)
      onComplete(result)
    }
  }
}

struct MailAttachment {
  let data: Data
  let mimeType: String
  let fileName: String
}

#Preview {
  SupportFormView()
}
