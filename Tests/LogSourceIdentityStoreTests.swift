import Foundation

@MainActor final class CloudLogSharingState {
  static let shared = CloudLogSharingState()
  var scope: String?
}
@MainActor final class MacTransferManager {
  struct Pairing { let physicalDeviceID: UUID; let model: String }
  static let shared = MacTransferManager()
  var pairings: [Pairing] = []
}
@main struct LogSourceIdentityStoreTests {
  @MainActor static func main() {
    let key = "AuthenticatedLogSourceModelsV1"
    UserDefaults.standard.removeObject(forKey: key)
    defer { UserDefaults.standard.removeObject(forKey: key) }
    let scope = String(repeating: "a", count: 64), other = String(repeating: "b", count: 64)
    let phone = UUID(), pad = UUID(), rejected = UUID()
    CloudLogSharingState.shared.scope = scope
    assert(LogSourceIdentityStore.remember(models: [phone.uuidString: "iPhone18,3", pad.uuidString: "iPad16,6"], scope: scope))
    assert(LogSourceIdentityStore.models() == [phone: "iPhone18,3", pad: "iPad16,6"])
    let before = UserDefaults.standard.dictionary(forKey: key)! as NSDictionary
    assert(!LogSourceIdentityStore.remember(models: [rejected.uuidString: "iPad16,6", phone.uuidString: "iPhone99,9"], scope: scope))
    assert(!LogSourceIdentityStore.remember(models: [rejected.uuidString: "iPad16,6", "invalid": "iPhone18,3"], scope: scope))
    assert(!LogSourceIdentityStore.remember(models: [rejected.uuidString: "Watch7,18"], scope: scope))
    assert(!LogSourceIdentityStore.remember(models: [rejected.uuidString: "iPad16,6"], scope: "invalid"))
    assert(before.isEqual(to: UserDefaults.standard.dictionary(forKey: key)!))
    assert(!LogSourceIdentityStore.remember(models: Dictionary(uniqueKeysWithValues: (0..<65).map { _ in (UUID().uuidString, "iPad16,6") }), scope: scope))
    assert(LogSourceIdentityStore.remember(models: [phone.uuidString: "iPhone18,3"], scope: scope))
    CloudLogSharingState.shared.scope = other
    assert(LogSourceIdentityStore.models().isEmpty)
    CloudLogSharingState.shared.scope = nil
    assert(LogSourceIdentityStore.models().isEmpty)
    MacTransferManager.shared.pairings = [.init(physicalDeviceID: pad, model: "iPad16,6")]
    assert(LogSourceIdentityStore.models() == [pad: "iPad16,6"])
    print("PASS: atomic identity batch, immutable source model, malformed IDs/models, size limit, idempotence, scope isolation and own-pairing fallback")
  }
}
