import CloudKit
import Combine
import CryptoKit
import Foundation

/// Same-container CloudKit user IDs are app-scoped. Neither Apple ID nor email is sent.
@MainActor
final class CloudLogSharingState: ObservableObject {
  static let shared = CloudLogSharingState()
  @Published private(set) var scope: String?
  private var generation = 0
  private var subscriptions: Set<AnyCancellable> = []
  private init() {
    AppSettings.shared.$iCloudSyncEnabled.removeDuplicates().sink { [weak self] _ in
      Task { @MainActor in self?.refresh() }
    }.store(in: &subscriptions)
    NotificationCenter.default.publisher(for: .CKAccountChanged).sink { [weak self] _ in
      Task { @MainActor in self?.refresh() }
    }.store(in: &subscriptions)
  }
  func refresh() {
    generation += 1
    let expected = generation
    scope = nil // revoke before any asynchronous account lookup
    guard AppSettings.shared.iCloudSyncEnabled, !ProcessInfo.processInfo.isiOSAppOnMac else { return }
    Task {
      do {
        let container = CKContainer(identifier: "iCloud.net.ryuya-dev.MochiLog")
        guard try await container.accountStatus() == .available else { return }
        let user = try await container.userRecordID()
        guard expected == generation, AppSettings.shared.iCloudSyncEnabled else { return }
        scope = SHA256.hash(data: Data("mochilog.cloud-sharing.v1|iCloud.net.ryuya-dev.MochiLog|\(user.recordName)".utf8))
          .map { String(format: "%02x", $0) }.joined()
      } catch {
        // Offline/unavailable/account-changed: foreign logs remain withheld.
      }
    }
  }
  static func sharedToken(in url: URL) -> CloudSharedLogToken? {
    let parts = url.pathComponents
    guard let inbox = parts.firstIndex(of: "MacTransferInbox"),
      let shared = parts.dropFirst(inbox + 1).firstIndex(of: "Shared") else { return nil }
    return CloudSharedLogToken.parse(parts[shared...].joined(separator: "::"))
  }
  static func allowsImport(_ url: URL) -> Bool {
    let parts = url.pathComponents
    guard let inbox = parts.firstIndex(of: "MacTransferInbox"),
      parts.dropFirst(inbox + 1).contains("Shared") else { return true }
    guard let token = sharedToken(in: url) else { return false }
    return AppSettings.shared.iCloudSyncEnabled && shared.scope == token.scope
  }
}
