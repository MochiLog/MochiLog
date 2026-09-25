import Combine
import CryptoKit
import Foundation
import Network
import Security

struct MacTransferPairing: Codable {
  let hostID: UUID
  let physicalDeviceID: UUID
  let model: String
  let secret: Data
}

@available(iOS 27, *)
@MainActor
final class MacTransferManager: ObservableObject {
  static let shared = MacTransferManager()
  @Published private(set) var pairing: MacTransferPairing?
  @Published private(set) var status = "Macとのペアリングが必要です"
  @Published private(set) var isReceiving = false
  private let queue = DispatchQueue(label: "net.ryuya-dev.MochiLog.mac-transfer")
  private var browser: NWBrowser?
  private var connection: NWConnection?
  private var endpoint: NWEndpoint?
  private var accumulated = Data()
  private var pendingAck: String?
  private let unconfirmedKey = "MacTransferUnconfirmedFiles"
  private let confirmedKey = "MacTransferConfirmedFiles"

  private init() {
    pairing = Self.loadPairing()
    pendingAck = UserDefaults.standard.string(forKey: "MacTransferPendingAck")
  }

  func pair(from text: String, dataStore: DataStore, relinkLocalRecords: Bool = false) throws {
    guard let components = URLComponents(string: text),
      components.scheme == "mochilog-mac", components.host == "pair" else {
      throw TransferError.invalidPairing
    }
    var values: [String: String] = [:]
    for item in components.queryItems ?? [] {
      guard let value = item.value, values[item.name] == nil else {
        throw TransferError.invalidPairing
      }
      values[item.name] = value
    }
    guard let host = values["host"].flatMap(UUID.init(uuidString:)),
      let device = values["device"].flatMap(UUID.init(uuidString:)),
      let model = values["model"], model == DeviceLibrary.localModelIdentifier(),
      let key = values["key"].flatMap({ Data(base64Encoded: $0) }), key.count == 32 else {
      throw TransferError.wrongDevice
    }
    let pair = MacTransferPairing(hostID: host, physicalDeviceID: device,
      model: model, secret: key)
    let previousID = PhysicalDeviceIdentityStore.current()
    if previousID != device {
      let conflicting = dataStore.recordsDescending.contains {
        $0.physicalDeviceID == previousID && $0.deviceModelCode == model
      }
      if conflicting && !relinkLocalRecords { throw TransferError.identityConflict }
      if conflicting {
        _ = try dataStore.reassignPhysicalDeviceID(from: previousID, to: device,
          matchingModelCode: model)
      }
    }
    try Self.savePairing(pair)
    pairing = pair
    PhysicalDeviceIdentityStore.replace(with: device)
    status = "Macとペアリングしました。接続を探しています"
    start()
  }

  func start() {
    guard let pairing else { return }
    if browser != nil {
      pull()
      return
    }
    requeueConfirmedFiles(for: pairing)
    let browser = NWBrowser(for: .bonjour(type: "_mochilog._tcp", domain: nil), using: .tcp)
    self.browser = browser
    browser.browseResultsChangedHandler = { [weak self] results, _ in
      guard let self else { return }
      guard let result = results.first(where: { result in
        if case .service(let name, _, _, _) = result.endpoint {
          return name == pairing.hostID.uuidString
        }
        return false
      }) else { return }
      Task { @MainActor in
        self.endpoint = result.endpoint
        self.pull()
      }
    }
    browser.stateUpdateHandler = { [weak self] state in
      if case .failed(let error) = state {
      Task { @MainActor [weak self] in self?.status = "Macの検索に失敗: \(error.localizedDescription)" }
      }
    }
    browser.start(queue: queue)
  }

  func stop() {
    browser?.cancel()
    browser = nil
    connection?.cancel()
    connection = nil
    isReceiving = false
  }

  private func pull() {
    guard let pairing, let endpoint, connection == nil else { return }
    isReceiving = true
    let nonce = UUID()
    let ack = pendingAck ?? ""
    let message = "\(pairing.hostID.uuidString)|\(pairing.physicalDeviceID.uuidString)|\(nonce.uuidString)|\(ack)"
    let mac = HMAC<SHA256>.authenticationCode(for: Data(message.utf8),
      using: SymmetricKey(data: pairing.secret))
      .map { String(format: "%02x", $0) }.joined()
    let request: [String: String] = [
      "hostID": pairing.hostID.uuidString,
      "physicalDeviceID": pairing.physicalDeviceID.uuidString,
      "nonce": nonce.uuidString,
      "ack": ack,
      "mac": mac
    ]
    guard let payload = try? JSONSerialization.data(withJSONObject: request) else { return }
    let connection = NWConnection(to: endpoint, using: .tcp)
    self.connection = connection
    accumulated = Data()
    connection.stateUpdateHandler = { [weak self] state in
      guard let self else { return }
      switch state {
      case .ready:
        connection.send(content: payload + Data([10]), completion: .contentProcessed { error in
          if error == nil { Task { @MainActor in self.receive(on: connection) } }
        })
      case .failed(let error):
        Task { @MainActor in
          self.status = "Macに接続できません: \(error.localizedDescription)"
          self.connection = nil
          self.isReceiving = false
        }
        connection.cancel()
      default: break
      }
    }
    connection.start(queue: queue)
  }

  private func receive(on connection: NWConnection) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, complete, error in
      guard let self else { return }
      Task { @MainActor in
        if let data { self.accumulated.append(data) }
        if self.accumulated.count > 64 * 1024 * 1024 + 1_024 {
          connection.cancel()
          self.status = "転送サイズが上限を超えました"
          self.isReceiving = false
          return
        }
        if let error {
          self.status = "受信に失敗: \(error.localizedDescription)"
          self.isReceiving = false
          connection.cancel()
        } else if complete {
          let bytes = self.accumulated
          self.accumulated = Data()
          self.finish(bytes, connection: connection)
        } else {
          self.receive(on: connection)
        }
      }
    }
  }

  private func finish(_ bytes: Data, connection: NWConnection) {
    defer { connection.cancel(); self.connection = nil }
    guard let pairing, bytes.count >= 4 else {
      status = "Macからの応答が不完全です"; isReceiving = false; return
    }
    let length = bytes.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    guard length == bytes.count - 4 else {
      status = "Macからの応答サイズが一致しません"; isReceiving = false; return
    }
    do {
      let box = try AES.GCM.SealedBox(combined: bytes.dropFirst(4))
      let plain = try AES.GCM.open(box, using: SymmetricKey(data: pairing.secret))
      guard plain.count >= 2 else { throw TransferError.invalidPayload }
      let nameLength = Int(plain[0]) * 256 + Int(plain[1])
      guard nameLength <= 1024, plain.count >= 2 + nameLength,
        let name = String(data: plain.subdata(in: 2..<(2 + nameLength)), encoding: .utf8)
      else { throw TransferError.invalidPayload }
      if name.isEmpty {
        // The Mac has processed the final file acknowledgement and returned
        // an authenticated terminal reply. Only now may imports begin.
        let confirmedCount = confirmReceivedFiles(for: pairing)
        if pendingAck != nil {
          pendingAck = nil
          UserDefaults.standard.removeObject(forKey: "MacTransferPendingAck")
        }
        status = confirmedCount == 0 ? "Macに新しいログはありません"
          : "Macが\(confirmedCount)件の受信を確認しました。解析を開始します"
        isReceiving = false
        return
      }
      let token = name.components(separatedBy: "::")
      let kind: String
      let filename: String
      let source: String?
      if token.count == 1 {
        kind = "Host" // flat queue from the first beta
        filename = token[0]
        source = nil
      } else if token.count == 2, ["Host", "Watch"].contains(token[0]) {
        kind = token[0]
        filename = token[1]
        source = nil
      } else if token.count == 3, ["Host", "Watch"].contains(token[0]),
        token[1].range(of: #"^ProxiedDevice-[a-fA-F0-9]+$"#,
          options: .regularExpression) != nil {
        kind = token[0]
        source = token[1]
        filename = token[2]
      } else { throw TransferError.invalidPayload }
      guard filename == URL(fileURLWithPath: filename).lastPathComponent,
        filename.hasPrefix("Analytics-"), filename.hasSuffix(".ips.ca.synced") else {
        throw TransferError.invalidPayload
      }
      if filename.localizedCaseInsensitiveContains("session") ||
        !Self.looksLikeBatteryLog(plain.dropFirst(2 + nameLength)) {
        pendingAck = name
        UserDefaults.standard.set(name, forKey: "MacTransferPendingAck")
        status = "バッテリーログではないファイルを除外しました"
        isReceiving = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.pull() }
        return
      }
      let content = plain.dropFirst(2 + nameLength)
      var folder = try Self.inbox(for: pairing).appendingPathComponent(kind,
        isDirectory: true)
      if let source { folder.appendPathComponent(source, isDirectory: true) }
      try FileManager.default.createDirectory(at: folder,
        withIntermediateDirectories: true)
      let destination = folder.appendingPathComponent(filename)
      if !FileManager.default.fileExists(atPath: destination.path) {
        try Data(content).write(to: destination, options: .atomic)
      }
      var unconfirmed = Set(UserDefaults.standard.stringArray(forKey: unconfirmedKey) ?? [])
      unconfirmed.insert(destination.path)
      UserDefaults.standard.set(unconfirmed.sorted(), forKey: unconfirmedKey)
      pendingAck = name
      UserDefaults.standard.set(name, forKey: "MacTransferPendingAck")
      status = "\(kind): \(filename)を受信。Macの確認待ち"
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.pull() }
    } catch {
      status = "受信データを確認できません: \(error.localizedDescription)"
      isReceiving = false
    }
  }

  private func requeueConfirmedFiles(for pairing: MacTransferPairing) {
    // Files received by the previous beta were already offered for import.
    if UserDefaults.standard.object(forKey: confirmedKey) == nil {
      let pending = Set(UserDefaults.standard.stringArray(forKey: unconfirmedKey) ?? [])
      let legacy = allInboxFiles(for: pairing).map(\.path).filter { !pending.contains($0) }
      UserDefaults.standard.set(legacy, forKey: confirmedKey)
    }
    let confirmed = Set(UserDefaults.standard.stringArray(forKey: confirmedKey) ?? [])
    enqueueFiles(confirmed.compactMap { FileManager.default.fileExists(atPath: $0)
      ? URL(fileURLWithPath: $0) : nil }, for: pairing)
  }

  private func confirmReceivedFiles(for pairing: MacTransferPairing) -> Int {
    let unconfirmed = Set(UserDefaults.standard.stringArray(forKey: unconfirmedKey) ?? [])
    let files = unconfirmed.compactMap { FileManager.default.fileExists(atPath: $0)
      ? URL(fileURLWithPath: $0) : nil }.sorted { $0.path < $1.path }
    var confirmed = Set(UserDefaults.standard.stringArray(forKey: confirmedKey) ?? [])
    confirmed.formUnion(files.map(\.path))
    UserDefaults.standard.set(confirmed.sorted(), forKey: confirmedKey)
    UserDefaults.standard.removeObject(forKey: unconfirmedKey)
    enqueueFiles(files, for: pairing)
    return files.count
  }

  private func allInboxFiles(for pairing: MacTransferPairing) -> [URL] {
    guard let folder = try? Self.inbox(for: pairing),
      let enumerator = FileManager.default.enumerator(at: folder,
        includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
    return enumerator.compactMap { $0 as? URL }.filter {
      $0.lastPathComponent.hasPrefix("Analytics-")
    }
  }

  private func enqueueFiles(_ files: [URL], for pairing: MacTransferPairing) {
    var batch: [(url: URL, physicalDeviceID: UUID?)] = []
    for file in files where file.lastPathComponent.hasPrefix("Analytics-") {
      if file.lastPathComponent.localizedCaseInsensitiveContains("session") ||
        (try? Data(contentsOf: file, options: .mappedIfSafe)).map({ !Self.looksLikeBatteryLog($0) }) == true {
        try? FileManager.default.removeItem(at: file)
        continue
      }
      batch.append((file, Self.sourcePhysicalID(for: file, pairing: pairing)))
    }
    SharedImportQueue.shared.enqueueBatch(batch.sorted { $0.url.path < $1.url.path })
  }

  private static func sourcePhysicalID(for file: URL, pairing: MacTransferPairing) -> UUID? {
    let parts = file.pathComponents
    guard let watchIndex = parts.firstIndex(of: "Watch") else {
      return pairing.physicalDeviceID
    }
    guard parts.indices.contains(watchIndex + 1) else { return nil }
    let source = parts[watchIndex + 1]
    guard source.range(of: #"^ProxiedDevice-[a-fA-F0-9]+$"#,
      options: .regularExpression) != nil else { return nil }
    let digest = SHA256.hash(data: Data("\(pairing.physicalDeviceID.uuidString)|\(source)".utf8))
    var bytes = Array(digest.prefix(16))
    bytes[6] = (bytes[6] & 0x0f) | 0x50
    bytes[8] = (bytes[8] & 0x3f) | 0x80
    return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5],
      bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12],
      bytes[13], bytes[14], bytes[15]))
  }

  private static func looksLikeBatteryLog(_ bytes: Data) -> Bool {
    var lines = 0
    for byte in bytes where byte == 10 {
      lines += 1
      if lines >= 100 { break }
    }
    guard lines >= 100 else { return false }
    return ["last_value_CycleCount", "last_value_NominalChargeCapacity",
      "last_value_AppleRawMaxCapacity"].allSatisfy {
        bytes.range(of: Data($0.utf8)) != nil
      }
  }

  static func inbox(for pairing: MacTransferPairing) throws -> URL {
    let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("MacTransferInbox", isDirectory: true)
      .appendingPathComponent(pairing.physicalDeviceID.uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    return base
  }

  private static func loadPairing() -> MacTransferPairing? {
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "net.ryuya-dev.MochiLog.mac-pairing",
      kSecAttrAccount as String: "active", kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data else { return nil }
    return try? JSONDecoder().decode(MacTransferPairing.self, from: data)
  }

  private static func savePairing(_ pair: MacTransferPairing) throws {
    let data = try JSONEncoder().encode(pair)
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "net.ryuya-dev.MochiLog.mac-pairing",
      kSecAttrAccount as String: "active"]
    let update: [String: Any] = [kSecValueData as String: data]
    let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
    if status == errSecItemNotFound {
      var add = query
      add[kSecValueData as String] = data
      add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else {
        throw TransferError.keychain
      }
    } else if status != errSecSuccess {
      throw TransferError.keychain
    }
  }
}

enum TransferError: LocalizedError {
  case invalidPairing, wrongDevice, invalidPayload, keychain, identityConflict
  var errorDescription: String? {
    switch self {
    case .invalidPairing: "QRコードがMochiLog Mac用ではありません"
    case .wrongDevice: "このQRコードは、この端末の機種と一致しません"
    case .invalidPayload: "Macからのデータが不正です"
    case .keychain: "ペアリング情報を保存できません"
    case .identityConflict: "この端末に別の個体IDで保存された新しい記録があります。統合するか確認してください"
    }
  }
}
