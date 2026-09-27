import Foundation
import MetricKit

/// OS crash and hang reports are retained on-device and shared only from a support form.
final class CrashDiagnostics: NSObject, MXMetricManagerSubscriber {
  static let shared = CrashDiagnostics()
  private let lock = NSLock()
  private let url: URL = {
    let directory = FileManager.default.urls(for: .applicationSupportDirectory,
      in: .userDomainMask)[0]
    return directory.appendingPathComponent("last-app-diagnostic.json")
  }()
  private var observer: Task<Void, Never>?

  func start() {
    if #available(iOS 27, *) {
      guard observer == nil else { return }
      let manager = MetricManager()
      observer = Task.detached { [manager] in
        for await report in manager.diagnosticReports {
          let kind: String
          switch report.result {
          case .crash: kind = "crash"
          case .hang: kind = "hang"
          default: continue
          }
          guard let diagnostic = try? JSONEncoder().encode(report) else { continue }
          await CrashDiagnostics.shared.save(kind: kind, diagnostic: diagnostic)
        }
      }
    } else {
      MXMetricManager.shared.add(self)
      // A subscriber may be installed after a report was delivered; recover recent payloads.
      didReceive(MXMetricManager.shared.pastDiagnosticPayloads)
    }
  }

  func didReceive(_ payloads: [MXDiagnosticPayload]) {
    for payload in payloads where
      !(payload.crashDiagnostics ?? []).isEmpty || !(payload.hangDiagnostics ?? []).isEmpty {
      let kind = (payload.crashDiagnostics ?? []).isEmpty ? "hang" : "crash"
      save(kind: kind, diagnostic: payload.jsonRepresentation())
    }
  }

  func latest() -> Data? {
    lock.lock()
    defer { lock.unlock() }
    return try? Data(contentsOf: url)
  }

  func summary() -> String? {
    guard let data = latest(),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let kind = object["kind"] as? String,
      let receivedAt = object["receivedAt"] as? String else { return nil }
    return "OS diagnostic: \(kind) received \(receivedAt)"
  }

  private func save(kind: String, diagnostic: Data) {
    guard diagnostic.count <= 1_048_576,
      let report = try? JSONSerialization.jsonObject(with: diagnostic),
      let data = try? JSONSerialization.data(withJSONObject: [
        "schema": 1, "platform": "iOS", "kind": kind,
        "receivedAt": ISO8601DateFormatter().string(from: Date()),
        "report": report
      ], options: [.prettyPrinted, .sortedKeys]) else { return }
    lock.lock()
    defer { lock.unlock() }
    do {
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true)
      try data.write(to: url, options: .atomic)
      try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    } catch { /* A diagnostic failure must not affect the app. */ }
  }
}
