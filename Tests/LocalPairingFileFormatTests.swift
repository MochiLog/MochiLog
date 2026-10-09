import Foundation

@main struct LocalPairingFileFormatTests {
  static func main() {
    let udid = "00008132-0000000000000000"
    // Synthetic bytes only; native certificate validation happens separately.
    var remote: [String: Any] = ["public_key": Data(repeating: 1, count: 32), "private_key": Data(repeating: 2, count: 32), "identifier": "test"]
    precondition(LocalPairingFileFormat.detect(remote, expectedUDID: udid) == .remote)
    remote["HostID"] = "mixed"
    precondition(LocalPairingFileFormat.detect(remote, expectedUDID: udid) == nil)
    remote.removeValue(forKey: "HostID"); remote["public_key"] = Data(repeating: 1, count: 31)
    precondition(LocalPairingFileFormat.detect(remote, expectedUDID: udid) == nil)
    remote["public_key"] = Data(repeating: 1, count: 32)
    remote["alt_irk"] = Data(repeating: 3, count: 16)
    remote["UDID"] = udid
    remote["remote_unlock_host_key"] = "opaque-extra-field"
    precondition(LocalPairingFileFormat.detect(remote, expectedUDID: udid) == .remote)
    precondition(LocalPairingFileFormat.detect(remote, expectedUDID: "00008132-1111111111111111") == nil)
    remote.removeValue(forKey: "identifier"); remote["host_identifier"] = "test"
    remote.removeValue(forKey: "alt_irk"); remote["peer_alt_irk"] = Data(repeating: 3, count: 16)
    precondition(LocalPairingFileFormat.detect(remote, expectedUDID: udid) == .remote)
    precondition(LocalPairingFileFormat.normalized(remote)?["alt_irk"] as? Data == Data(repeating: 3, count: 16))
    precondition(LocalPairingFileFormat.normalized(remote)?["remote_unlock_host_key"] as? String == "opaque-extra-field")
    remote["alt_irk"] = Data(repeating: 4, count: 16)
    precondition(LocalPairingFileFormat.detect(remote, expectedUDID: udid) == nil)
    remote.removeValue(forKey: "alt_irk"); remote["peer_alt_irk"] = Data(repeating: 3, count: 15)
    precondition(LocalPairingFileFormat.detect(remote, expectedUDID: udid) == nil)
    var legacy: [String: Any] = ["HostID": "test", "SystemBUID": "test", "WiFiMACAddress": "00:00:00:00:00:00", "UDID": udid]
    for key in ["DeviceCertificate", "HostCertificate", "HostPrivateKey", "RootCertificate", "RootPrivateKey"] { legacy[key] = Data([1]) }
    precondition(LocalPairingFileFormat.detect(legacy, expectedUDID: udid) == .lockdown)
    precondition(LocalPairingFileFormat.detect(legacy, expectedUDID: "00008132-1111111111111111") == nil)
    legacy.removeValue(forKey: "RootPrivateKey")
    precondition(LocalPairingFileFormat.detect(legacy, expectedUDID: udid) == nil)
    precondition(LocalPairingFileFormat.detect([:], expectedUDID: udid) == nil)
    print("PASS: pairing format rejects mixed credentials, incomplete keys and a different device identity")
  }
}
