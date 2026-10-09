import Foundation

/// Distinguishes trust formats before starting any connection. Mixed formats
/// must never select a weaker transport after remote verification fails.
nonisolated enum LocalPairingFileFormat {
  case remote, lockdown
  static func normalized(_ source: [String: Any]) -> [String: Any]? {
    var plist = source
    if let old = source["identifier"] as? String, let newer = source["host_identifier"] as? String, old != newer { return nil }
    if plist["identifier"] == nil { plist["identifier"] = source["host_identifier"] }
    let fields = ["alt_irk", "peer_alt_irk"]
    for key in fields where source[key] != nil {
      guard let bytes = source[key] as? Data, bytes.count == 16 else { return nil }
    }
    if let a = source["alt_irk"] as? Data, let b = source["peer_alt_irk"] as? Data, a != b { return nil }
    if plist["alt_irk"] == nil { plist["alt_irk"] = source["peer_alt_irk"] }
    if let a = source["UDID"] as? String, let b = source["udid"] as? String, a != b { return nil }
    if plist["UDID"] == nil { plist["UDID"] = source["udid"] }
    return plist
  }
  static func detect(_ plist: [String: Any], expectedUDID: String) -> Self? {
    guard let plist = normalized(plist), plist["UDID"] == nil || plist["UDID"] as? String == expectedUDID else { return nil }
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
