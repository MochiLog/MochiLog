import Foundation
import Network

@main struct Tests {
  static func main() throws {
    let suite = "MochiLog-Settings-Test-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set("DO_NOT_EXPORT_SECRET", forKey: "private-key")
    let store = NetworkAccessDiagnostics(defaults: defaults)
    for index in 0..<30 {
      store.record(component: "test-\(index)", state: "path-unavailable", denied: index == 29)
    }
    precondition(store.snapshot().count == 8)
    let restored = NetworkAccessDiagnostics(defaults: defaults)
    precondition(restored.snapshot().last?.denialObserved == true)
    precondition(restored.snapshot().last?.processID == ProcessInfo.processInfo.processIdentifier)
    precondition(restored.localNetworkDenialObserved())
    restored.record(component: "generic-path", state: "path-satisfied")
    precondition(
      restored.localNetworkDenialObserved(), "Generic connectivity must not erase a known denial")
    restored.record(component: "pairing-permission-check", state: "permission-check-ready")
    precondition(!restored.localNetworkDenialObserved())
    restored.record(
      component: "qr-policy", state: "denied", denied: true,
      error: NWError.dns(-65570))
    precondition(restored.localNetworkDenialObserved())
    precondition(NetworkAccessDiagnostics.isLocalNetworkPolicyDenial(NWError.dns(-65570)))
    precondition(!NetworkAccessDiagnostics.isLocalNetworkPolicyDenial(NWError.posix(.EACCES)))
    var previousProcess =
      try JSONSerialization.jsonObject(
        with: JSONEncoder().encode(restored.snapshot())) as! [[String: Any]]
    for index in previousProcess.indices {
      previousProcess[index]["processInstanceID"] = "older-process"
    }
    defaults.set(
      try JSONSerialization.data(withJSONObject: previousProcess),
      forKey: "MochiLogNetworkAccessObservationsV1")
    precondition(
      !NetworkAccessDiagnostics(defaults: defaults).localNetworkDenialObserved(),
      "A previous app process must not turn an unknown current permission into denied")
    let bytes = SupportSettingsSnapshot.encode(
      platform: "test", toggles: ["pcAutomaticCollection": true],
      limits: ["debugRetentionDays": 30],
      permissions: ["localNetwork": .init("unknown", source: "no-general-public-query-API")])
    precondition(
      bytes.count <= 8192
        && !String(decoding: bytes, as: UTF8.self).contains("DO_NOT_EXPORT_SECRET"))
    let object = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
    let report = try JSONSerialization.data(withJSONObject: ["settingsSnapshot": object])
    precondition(SupportSettingsSnapshot.extract(from: report) == bytes)
    precondition(SupportSettingsSnapshot.extract(from: Data("{}".utf8)) == nil)
    let reset = PCConnectionFailure.classify(
      NWError.posix(.ECONNRESET), phase: "receiving", receivedBytes: 4096)
    precondition(
      reset.kind == .connectionLost && reset.originCode == 54 && reset.receivedBytes == 4096)
    let denied = PCConnectionFailure.timeout(phase: "connecting", bytes: 0, denied: true)
    let connect = PCConnectionFailure.timeout(phase: "connecting", bytes: 0, denied: false)
    let response = PCConnectionFailure.timeout(
      phase: "waiting-for-response", bytes: 0, denied: false)
    let partial = PCConnectionFailure.timeout(
      phase: "waiting-for-response", bytes: 12, denied: false)
    precondition(
      denied.kind == .networkDenied && connect.kind == .connectTimeout
        && response.kind == .responseTimeout && partial.kind == .incompleteResponse)
    precondition(
      PCConnectionFailure.classify(NWError.posix(.ECONNREFUSED), phase: "connecting").kind
        == .connectionRefused)
    precondition(
      PCConnectionFailure.classify(NWError.dns(-65570), phase: "connecting").kind
        == .networkPolicyDenied)
    precondition(
      PCConnectionFailure.classify(NSError(domain: "Unknown", code: -1001), phase: "connecting")
        .kind == .unknown)
    precondition(
      Set(
        PCConnectionFailure.Kind.allCases.map {
          PCConnectionFailure($0, phase: "test").diagnosticCode
        }
      ).count == PCConnectionFailure.Kind.allCases.count)
    precondition(
      partial.diagnosticDescription.contains("receivedBytes=12") && partial.errorCode == -1001)
    print(
      "PASS: bounded persisted observations, unknown-vs-denied semantics, secret exclusion, remote snapshots and structured error classification"
    )
  }
}
