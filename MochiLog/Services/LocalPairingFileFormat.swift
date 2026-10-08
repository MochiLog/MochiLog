import Foundation

/// Distinguishes trust formats before starting any connection. Mixed formats
/// must never select a weaker transport after remote verification fails.
nonisolated enum LocalPairingFileFormat {
  case remote, lockdown
  static func detect(_ plist: [String: Any], expectedUDID: String) -> Self? {
    if plist["public_key"] != nil || plist["private_key"] != nil {
      guard plist["HostID"] == nil,
        let pub = plist["public_key"] as? Data, pub.count == 32,
        let priv = plist["private_key"] as? Data, priv.count == 32,
        let id = plist["identifier"] as? String, !id.isEmpty, id.count <= 128 else { return nil }
      return .remote
    }
    guard ["DeviceCertificate", "HostCertificate", "HostPrivateKey", "RootCertificate", "RootPrivateKey"].allSatisfy({
      guard let bytes = plist[$0] as? Data else { return false }; return !bytes.isEmpty
    }), ["HostID", "SystemBUID"].allSatisfy({ (plist[$0] as? String)?.isEmpty == false }),
      plist["WiFiMACAddress"] is String,
      plist["UDID"] == nil || plist["UDID"] as? String == expectedUDID else { return nil }
    return .lockdown
  }
}
