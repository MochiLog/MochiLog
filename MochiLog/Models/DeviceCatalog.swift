import CryptoKit
import Foundation

/// Versioned reference data only; downloaded catalogs cannot supply executable rules.
struct DeviceCatalog: Codable, Equatable {
  static let schemaVersion = 1
  static let bundledRevision = 2026110101
  static let maximumBytes = 2 * 1024 * 1024
  // Public verification key. Signing material is held outside the repository.
  static let publicKeyBase64 = "iO6IFzTNuCOwGYj4boiQeKF3G7z1U6pxGXq23HVWUxI="

  let schemaVersion: Int
  let revision: Int
  let profiles: [DeviceProfile]

  struct Envelope: Codable {
    let payload: String
    let signature: String
  }

  enum CatalogError: Error {
    case invalidSignature, unsupportedSchema, invalidData, rollback, revisionCollision
  }

  static func verified(_ data: Data, publicKey: Data? = nil) throws -> DeviceCatalog {
    guard data.count <= maximumBytes,
      let keyBytes = publicKey ?? Data(base64Encoded: publicKeyBase64)
    else { throw CatalogError.invalidData }
    let envelope = try JSONDecoder().decode(Envelope.self, from: data)
    guard let payload = Data(base64Encoded: envelope.payload),
      let signature = Data(base64Encoded: envelope.signature),
      signature.count == 64
    else { throw CatalogError.invalidSignature }
    let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyBytes)
    guard key.isValidSignature(signature, for: payload) else {
      throw CatalogError.invalidSignature
    }
    let catalog = try JSONDecoder().decode(DeviceCatalog.self, from: payload)
    try catalog.validate()
    return catalog
  }

  func validate() throws {
    guard schemaVersion == Self.schemaVersion else { throw CatalogError.unsupportedSchema }
    guard revision > 0, revision <= 9999999999, !profiles.isEmpty, profiles.count <= 2000,
      Set(profiles.map(\.id)).count == profiles.count
    else { throw CatalogError.invalidData }
    var seen: [DeviceProfile] = []
    for profile in profiles {
      let strings =
        [profile.id, profile.name, profile.soc] + profile.identifiers
        + Array(profile.boards.keys) + profile.modelNumbers
        + profile.modelNumbersByIdentifier.values.flatMap { $0 }
      guard !profile.id.isEmpty, profile.id.count <= 200,
        strings.allSatisfy({
          $0.count <= 200
            && !$0.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        }),
        profile.identifiers.count <= 40, profile.boards.count <= 80,
        profile.modelNumbers.count <= 80,
        profile.modelNumbersByIdentifier.values.allSatisfy({ $0.count <= 80 }),
        profile.capacityVariants.allSatisfy({ ($0.region?.count ?? 0) <= 100 })
      else { throw CatalogError.invalidData }
      // A zero reference means the capacity is unknown, never a measured zero.
      var checked = profile
      checked.capacity = max(1, checked.capacity)
      guard (0...100000).contains(profile.capacity),
        DeviceProfileCatalog.validationError(checked, others: seen) == nil
      else { throw CatalogError.invalidData }
      seen.append(profile)
    }
  }

  /// Retain bundled devices omitted from an overlay, and keep stable IDs for edits.
  func standards(over bundled: [DeviceProfile]) throws -> [DeviceProfile] {
    try validate()
    let remaining = bundled.filter { baseline in
      !profiles.contains { $0.id == baseline.id || $0.matches(baseline) }
    }
    let result = remaining + profiles
    try DeviceCatalog(schemaVersion: schemaVersion, revision: revision, profiles: result).validate()
    return result
  }
}
