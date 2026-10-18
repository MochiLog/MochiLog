import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
  private let status = UILabel()
  private let details = UILabel()
  private let done = UIButton(type: .system)
  private let cancel = UIButton(type: .system)
  private var task: Task<Void, Never>?
  private var japanese: Bool { Locale.preferredLanguages.first?.hasPrefix("ja") == true }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemGroupedBackground
    isModalInPresentation = true
    status.font = .preferredFont(forTextStyle: .title2)
    status.adjustsFontForContentSizeCategory = true
    status.numberOfLines = 0
    details.font = .preferredFont(forTextStyle: .body)
    details.adjustsFontForContentSizeCategory = true
    details.numberOfLines = 0
    details.textColor = .secondaryLabel
    done.setTitle(japanese ? "完了" : "Done", for: .normal)
    done.addTarget(self, action: #selector(finish), for: .touchUpInside)
    done.isEnabled = false
    cancel.setTitle(japanese ? "キャンセル" : "Cancel", for: .normal)
    cancel.addTarget(self, action: #selector(cancelImport), for: .touchUpInside)
    let stack = UIStackView(arrangedSubviews: [status, details, done, cancel])
    stack.axis = .vertical
    stack.spacing = 24
    stack.translatesAutoresizingMaskIntoConstraints = false
    let scroll = UIScrollView()
    scroll.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scroll)
    scroll.addSubview(stack)
    NSLayoutConstraint.activate([
      scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
      scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 32),
      stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32),
      stack.leadingAnchor.constraint(
        equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(
        equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
      stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48),
      done.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
    ])
    task = Task { await receiveFiles() }
  }

  private func receiveFiles() async {
    let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap {
      $0.attachments ?? []
    }
    guard let root = SharedLogInbox.root else {
      status.text = japanese ? "共有データを保存できませんでした" : "Shared storage is unavailable"
      done.isEnabled = true
      return
    }
    var batch: URL?
    do {
      let pending = try SharedLogInbox.begin(at: root)
      batch = pending
      var received = 0
      var errors: [String] = []
      for (index, provider) in providers.enumerated() {
        try Task.checkCancellation()
        status.text =
          japanese
          ? "ログを受け取り中 \(index + 1)/\(providers.count)"
          : "Receiving logs \(index + 1)/\(providers.count)"
        do {
          try await copyAttachment(provider, index: index, into: pending)
          received += 1
        } catch {
          errors.append(
            "\(provider.suggestedName ?? String(index + 1)): \(error.localizedDescription)")
        }
      }
      try Task.checkCancellation()
      if received > 0 {
        try SharedLogInbox.publish(pending)
      } else {
        try? FileManager.default.removeItem(at: pending)
      }
      batch = nil
      status.text =
        japanese
        ? "\(providers.count)件中\(received)件を受け取りました"
        : "Received \(received) of \(providers.count) files"
      let next =
        japanese
        ? "完了を押してMochiLogを開くと、ログをまとめて取り込みます。元のファイルは変更しません。"
        : "Tap Done, then open MochiLog to import these logs together. Original files are unchanged."
      details.text =
        (received > 0 ? next : (japanese ? "受け取れるログがありませんでした。" : "No logs could be received."))
        + (errors.isEmpty ? "" : "\n\n" + errors.joined(separator: "\n"))
    } catch {
      if let batch { try? FileManager.default.removeItem(at: batch) }
      status.text = japanese ? "共有データを保存できませんでした" : "Could not save shared files"
      details.text = error.localizedDescription
    }
    done.isEnabled = true
    cancel.isHidden = true
    isModalInPresentation = false
  }

  private func copyAttachment(_ provider: NSItemProvider, index: Int, into batch: URL) async throws
  {
    // Copy in the provider callback: its temporary URL expires when the callback returns.
    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, Error>) in
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) {
          item, error in
          do {
            if let error { throw error }
            let url =
              (item as? URL)
              ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
            guard let url, url.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            try SharedLogInbox.copy(url, index: index, into: batch)
            continuation.resume()
          } catch { continuation.resume(throwing: error) }
        }
      }
    } else {
      guard
        let type = provider.registeredTypeIdentifiers.first(where: {
          UTType($0)?.conforms(to: .data) == true
        })
      else { throw CocoaError(.fileReadUnsupportedScheme) }
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, Error>) in
        provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
          do {
            if let error { throw error }
            guard let url else { throw CocoaError(.fileReadUnknown) }
            try SharedLogInbox.copy(url, index: index, into: batch)
            continuation.resume()
          } catch { continuation.resume(throwing: error) }
        }
      }
    }
  }

  @objc private func cancelImport() {
    task?.cancel()
    extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
  }

  @objc private func finish() { extensionContext?.completeRequest(returningItems: nil) }
}
