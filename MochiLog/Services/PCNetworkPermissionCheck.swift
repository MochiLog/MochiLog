import Combine
import Foundation
import Network

/// Explicit, bounded foreground check started from the pairing UI. It never
/// reads TCC databases or labels unknown status as allowed/denied. A refusal
/// warns about LAN access without blocking a working VPN/direct route.
@MainActor
final class PCNetworkPermissionCheck: ObservableObject {
  @Published private(set) var denied = false
  @Published private(set) var isChecking = false
  private var browser: NWBrowser?
  private var deadline: Task<Void, Never>?

  init() { refresh() }

  func refresh() {
    let observed = NetworkAccessDiagnostics.shared.localNetworkDenialObserved()
    if denied != observed { denied = observed }
  }

  func check() {
    stop()
    refresh()
    isChecking = true
    let browser = NWBrowser(for: .bonjour(type: "_mochilog._tcp", domain: nil), using: .tcp)
    self.browser = browser
    let browserID = ObjectIdentifier(browser)
    NetworkAccessDiagnostics.shared.record(component: "pairing-permission-check", state: "checking")
    browser.stateUpdateHandler = { [weak self] state in
      Task { @MainActor in
        guard let self, let active = self.browser, ObjectIdentifier(active) == browserID else {
          return
        }
        switch state {
        case .ready:
          NetworkAccessDiagnostics.shared.record(
            component: "pairing-permission-check", state: "permission-check-ready")
        case .waiting(let error), .failed(let error):
          NetworkAccessDiagnostics.shared.record(
            component: "pairing-permission-check", state: "browse-unavailable",
            denied: NetworkAccessDiagnostics.isLocalNetworkPolicyDenial(error), error: error)
        default: break
        }
        self.refresh()
      }
    }
    browser.start(queue: DispatchQueue(label: "net.ryuya-dev.MochiLog.pairing-permission"))
    deadline = Task { [weak self] in
      do { try await Task.sleep(nanoseconds: 8_000_000_000) } catch { return }
      guard let self, let active = self.browser, ObjectIdentifier(active) == browserID else {
        return
      }
      self.stop()
      self.refresh()
    }
  }

  func stop() {
    deadline?.cancel()
    deadline = nil
    browser?.stateUpdateHandler = nil
    browser?.cancel()
    browser = nil
    isChecking = false
  }
}
