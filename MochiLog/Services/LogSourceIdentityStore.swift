import Foundation

/// Only models from authenticated PC offers are cached, scoped to that account.
@MainActor enum LogSourceIdentityStore {
  static let changed = Notification.Name("LogSourceIdentityChanged")
  private static let key = "AuthenticatedLogSourceModelsV1"

  static func remember(origin: UUID, model: String, scope: String) -> Bool {
    guard CloudSharedLogToken.validScope(scope), LogSourceIdentity.validHostModel(model) else { return false }
    var accounts = UserDefaults.standard.dictionary(forKey: key) as? [String: [String: String]] ?? [:]
    var values = accounts[scope] ?? [:]
    if let previous = values[origin.uuidString], previous != model { return false }
    guard values[origin.uuidString] != model else { return true }
    values[origin.uuidString] = model
    accounts[scope] = values
    UserDefaults.standard.set(accounts, forKey: key)
    NotificationCenter.default.post(name: changed, object: nil)
    return true
  }

  static func models() -> [UUID: String] {
    guard #available(iOS 17, *) else { return [:] }
    var result: [UUID: String] = [:]
    if let scope = CloudLogSharingState.shared.scope,
      let accounts = UserDefaults.standard.dictionary(forKey: key) as? [String: [String: String]] {
      for (id, model) in accounts[scope] ?? [:] {
        if let id = UUID(uuidString: id), LogSourceIdentity.validHostModel(model) { result[id] = model }
      }
    }
    for pairing in MacTransferManager.shared.pairings where LogSourceIdentity.validHostModel(pairing.model) {
      result[pairing.physicalDeviceID] = pairing.model
    }
    return result
  }
}
