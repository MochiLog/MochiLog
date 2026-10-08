import SwiftUI
import Network

@main struct ProbeApp: App {
  var body: some Scene { WindowGroup { ProbeView() } }
}
struct ProbeView: View {
  @StateObject var probe = Probe()
  var body: some View {
    ScrollView { VStack(alignment: .leading, spacing: 16) {
      Text("MochiLog · LocalDevVPN経路調査").font(.title)
      Text("端末自身から要求します。PCはビルド・結果確認だけに使い、診断要求の中継はしません。既存のPC連携や保存記録は変更しません。")
      Text(probe.output).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
    }.padding() }.task { await probe.run() }
  }
}
@MainActor final class Probe: ObservableObject {
  @Published var output = "Starting…"
  private var results: [[String: String]] = []
  private var running = false
  func run() async {
    guard !running else { return }; running = true
    UIApplication.shared.isIdleTimerDisabled = true
    defer { UIApplication.shared.isIdleTimerDisabled = false }
    results.append(["stage": "start", "os": UIDevice.current.systemVersion,
      "time": ISO8601DateFormatter().string(from: Date()), "transport": "device-originated TCP via existing Tailscale reflector"])
    for host in ["10.7.0.1", "127.0.0.1"] {
      for port in [62078, 49152] {
        let channel = ProbeChannel(host: host, port: UInt16(port))
        var row = ["stage": "TCP", "host": host, "port": String(port)]
        do {
          try await channel.open()
          row["result"] = "ready"
          row["tcpReady"] = "true"
          if port == 62078 {
            let reply = try await channel.query(["Request": "QueryType", "Label": "MochiLogLocalDevResearch"])
            row["lockdownType"] = reply["Type"] as? String ?? "missing"
            row["error"] = reply["Error"] as? String ?? "none"
            for key in ["ProductType", "ProductVersion"] {
              let response = try await channel.query(["Request": "GetValue", "Key": key, "Label": "MochiLogLocalDevResearch"])
              row[key] = response["Value"] as? String ?? (response["Error"] as? String ?? "missing")
            }
          }
        } catch { row["result"] = String(describing: error) }
        channel.close(); results.append(row); update()
      }
    }
    output += "\n認証・診断サービスを調査中…"
    let ffiRows = await Task.detached(priority: .utility) { FFIProbe.run() }.value
    results.append(contentsOf: ffiRows)
    results.append(["stage": "complete", "dailyFileAcquired": String(ffiRows.contains { $0["fileBodyRead"] == "true" }),
      "batteryValuesAcquired": String(ffiRows.contains { !($0["numericMetricNames"] ?? "").isEmpty })])
    update()
  }
  private func update() {
    output = results.map { row in row.keys.sorted().map { "\($0): \(row[$0]!)" }.joined(separator: " | ") }.joined(separator: "\n\n")
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("research-results.json")
    if let data = try? JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]) {
      try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }
  }
}
final class ProbeChannel {
  enum Failure: Error { case timeout, closed, malformed, tooLarge }
  private let connection: NWConnection
  private let queue = DispatchQueue(label: "MochiLog.LocalDevResearch")
  init(host: String, port: UInt16) {
    connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
  }
  func open() async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      var completed = false
      func finish(_ error: Error?) {
        guard !completed else { return }; completed = true
        connection.stateUpdateHandler = nil
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
      }
      connection.stateUpdateHandler = { state in
        switch state {
        case .ready: finish(nil)
        case .failed(let error): finish(error)
        case .cancelled: finish(Failure.closed)
        default: break
        }
      }
      queue.asyncAfter(deadline: .now() + 8) { finish(Failure.timeout) }
      connection.start(queue: queue)
    }
  }
  func close() { connection.cancel() }
  func query(_ value: [String: Any]) async throws -> [String: Any] {
    let payload = try PropertyListSerialization.data(fromPropertyList: value, format: .xml, options: 0)
    var length = UInt32(payload.count).bigEndian
    var frame = Data(bytes: &length, count: 4); frame.append(payload)
    try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
      connection.send(content: frame, completion: .contentProcessed { error in
        if let error { c.resume(throwing: error) } else { c.resume() }
      })
    }
    let header = try await read(count: 4)
    let size = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    guard size > 0, size < 1024 * 1024 else { throw Failure.tooLarge }
    let data = try await read(count: Int(size))
    guard let reply = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else { throw Failure.malformed }
    return reply
  }
  private func read(count: Int) async throws -> Data {
    try await withCheckedThrowingContinuation { c in
      var completed = false
      queue.asyncAfter(deadline: .now() + 8) { [self] in
        guard !completed else { return }; completed = true
        c.resume(throwing: Failure.timeout); connection.cancel()
      }
      connection.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, isComplete, error in
        guard !completed else { return }; completed = true
        if let error { c.resume(throwing: error) }
        else if let data, data.count == count { c.resume(returning: data) }
        else { c.resume(throwing: isComplete ? Failure.closed : Failure.malformed) }
      }
    }
  }
}
