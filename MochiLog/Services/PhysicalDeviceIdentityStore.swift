import Foundation
import Security

/// Identity for this installation's physical phone. Keychain is a recovery aid;
/// Mac pairing and synced records are the other recovery paths.
enum PhysicalDeviceIdentityStore {
  static let manualLocalImportKey = "TagSameModelManualImportsAsThisDevice"
  private static let service = "net.ryuya-dev.MochiLog.physical-device"
  private static let account = "this-device"

  static func current() -> UUID {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var item: CFTypeRef?
    if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data, let text = String(data: data, encoding: .utf8),
      let id = UUID(uuidString: text) {
      return id
    }
    let id = UUID()
    replace(with: id)
    return id
  }

  static func replace(with id: UUID) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
    let update: [String: Any] = [kSecValueData as String: Data(id.uuidString.utf8)]
    if SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecItemNotFound {
      var item = query
      item[kSecValueData as String] = Data(id.uuidString.utf8)
      item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      SecItemAdd(item as CFDictionary, nil)
    }
  }

  static func identityForLocallyRecognizedLog(modelCode: String?) -> UUID? {
    guard UserDefaults.standard.bool(forKey: manualLocalImportKey) else { return nil }
    guard let modelCode, modelCode == DeviceLibrary.localModelIdentifier() else { return nil }
    return current()
  }
}
