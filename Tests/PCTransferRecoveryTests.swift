import CryptoKit
import Foundation

@main struct PCTransferRecoveryTests {
  static func require(_ value: Bool, _ message: String) throws {
    if !value {
      throw NSError(
        domain: "PCTransferRecoveryTests", code: 1,
        userInfo: [NSLocalizedDescriptionKey: message])
    }
  }

  static func frame(_ body: Data) -> Data {
    let length = UInt32(body.count)
    return withUnsafeBytes(of: length.bigEndian) { Data($0) } + body
  }

  static func main() throws {
    let key = SymmetricKey(data: Data(repeating: 7, count: 32))
    let context = Data("synthetic-authenticated-response".utf8)
    let plain = Data(repeating: 42, count: 3 * 1024 * 1024)
    let encrypted = try AES.GCM.seal(plain, using: key, authenticating: context).combined!
    let bytes = frame(encrypted)
    var accumulated = Data()
    for offset in stride(from: 0, to: bytes.count, by: 16_384) {
      accumulated.append(bytes[offset..<min(offset + 16_384, bytes.count)])
      try require(
        try PCTransferRecoveryPolicy.frameIsComplete(accumulated)
          == (accumulated.count == bytes.count),
        "fragmented frame completion must follow its length, without EOF")
    }
    let box = try AES.GCM.SealedBox(combined: accumulated.dropFirst(4))
    try require(
      try AES.GCM.open(box, using: key, authenticating: context) == plain,
      "framing must preserve authenticated ciphertext exactly")
    for length in 0..<4 {
      try require(
        try !PCTransferRecoveryPolicy.frameIsComplete(Data(bytes.prefix(length))),
        "a partial header is not a full response")
    }
    for malformed in [Data([0, 0, 0, 0]), Data([255, 255, 255, 255]), bytes + Data([0])] {
      do {
        _ = try PCTransferRecoveryPolicy.frameIsComplete(malformed)
        throw NSError(domain: "accepted-invalid-frame", code: 1)
      } catch is PCTransferRecoveryPolicy.FrameFailure {}
    }
    var tampered = bytes
    tampered[tampered.count - 1] ^= 1
    try require(
      try PCTransferRecoveryPolicy.frameIsComplete(tampered), "framing is not authentication")
    do {
      let badBox = try AES.GCM.SealedBox(combined: tampered.dropFirst(4))
      _ = try AES.GCM.open(badBox, using: key, authenticating: context)
      throw NSError(domain: "accepted-forged-response", code: 1)
    } catch is CryptoKitError {}
    var routes = ["old-LAN", "VPN"]
    for round in 0..<1_000 {
      routes = PCTransferRecoveryPolicy.routes(
        current: routes,
        discovered: round % 2 == 0 ? ["VPN", "new-LAN"] : ["new-LAN", "VPN"],
        attemptActive: true)
      try require(
        routes == ["old-LAN", "VPN", "new-LAN"],
        "metadata reorder must not reset an in-flight fallback route")
    }
    try require(
      PCTransferRecoveryPolicy.routes(
        current: routes,
        discovered: ["new-LAN", "VPN", "new-LAN"], attemptActive: false) == ["new-LAN", "VPN"],
      "an idle cycle should use fresh deduplicated discovery results")
    for round in 0..<1_000 {
      routes = PCTransferRecoveryPolicy.routes(
        current: routes, discovered: ["untrusted-metadata-\(round)"], attemptActive: true)
    }
    try require(
      routes.count == PCTransferRecoveryPolicy.maximumRoutes
        && routes.prefix(3) == ["old-LAN", "VPN", "new-LAN"],
      "repeated new advertisements must stay bounded without displacing active routes")
    print(
      "PASS: fragmented authenticated frames, completion without EOF, invalid/oversized/trailing frames, tamper rejection, 1000 discovery reorders"
    )
  }
}
