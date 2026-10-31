import CryptoKit
import Foundation
import Security

/// Run through scripts/device-catalog.sh; never write a private key into the checkout.
@main
struct DeviceCatalogSigner {
  private static let service = "net.ryuya-dev.MochiLog.DeviceCatalogSigning.v1"

  static func main() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    switch arguments.first {
    case "generate-key":
      let key = try signingKey(create: true)
      print(key.publicKey.rawRepresentation.base64EncodedString())
    case "sign":
      guard arguments.count == 3 else { throw ToolError.usage }
      let payload = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
      let catalog = try JSONDecoder().decode(DeviceCatalog.self, from: payload)
      try catalog.validate()
      let key = try signingKey(create: false)
      guard key.publicKey.rawRepresentation.base64EncodedString() == DeviceCatalog.publicKeyBase64
      else {
        throw ToolError.wrongKey
      }
      let envelope = DeviceCatalog.Envelope(
        payload: payload.base64EncodedString(),
        signature: try key.signature(for: payload).base64EncodedString())
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      let data = try encoder.encode(envelope)
      _ = try DeviceCatalog.verified(data)
      try data.write(to: URL(fileURLWithPath: arguments[2]), options: .atomic)
      print(
        "Signed device catalog revision \(catalog.revision), \(catalog.profiles.count) profiles")
    case "verify":
      guard (2...3).contains(arguments.count) else { throw ToolError.usage }
      let bytes = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
      let catalog = try DeviceCatalog.verified(bytes)
      if arguments.count == 3 {
        let envelope = try JSONDecoder().decode(DeviceCatalog.Envelope.self, from: bytes)
        let source = try Data(contentsOf: URL(fileURLWithPath: arguments[2]))
        guard Data(base64Encoded: envelope.payload) == source else { throw ToolError.sourceDiffers }
      }
      print(
        "Verified device catalog revision \(catalog.revision), \(catalog.profiles.count) profiles")
    default:
      throw ToolError.usage
    }
  }

  private static func signingKey(create: Bool) throws -> Curve25519.Signing.PrivateKey {
    if let encoded = ProcessInfo.processInfo.environment["DEVICE_CATALOG_SIGNING_KEY"],
      let bytes = Data(base64Encoded: encoded)
    {
      return try Curve25519.Signing.PrivateKey(rawRepresentation: bytes)
    }
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: "ed25519",
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecSuccess, let bytes = result as? Data {
      return try Curve25519.Signing.PrivateKey(rawRepresentation: bytes)
    }
    guard status == errSecItemNotFound, create else { throw ToolError.keyUnavailable(status) }
    let key = Curve25519.Signing.PrivateKey()
    let entry: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: "ed25519",
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecValueData as String: key.rawRepresentation,
    ]
    let saved = SecItemAdd(entry as CFDictionary, nil)
    guard saved == errSecSuccess else { throw ToolError.keyUnavailable(saved) }
    return key
  }

  enum ToolError: Error { case usage, wrongKey, sourceDiffers, keyUnavailable(OSStatus) }
}
