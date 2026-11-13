import Foundation

nonisolated enum SupportSettingsSnapshot {
  struct Permission: Codable {
    let status: String
    let source: String
    let checkedAt: String
    init(_ status: String, source: String) {
      self.status = status
      self.source = source
      checkedAt = NetworkAccessDiagnostics.now()
    }
  }
  struct Snapshot: Encodable {
    let type = "mochilog-settings-snapshot"
    let schema = 1
    let capturedAt = NetworkAccessDiagnostics.now()
    let timeZone = TimeZone.autoupdatingCurrent.identifier
    let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
    let platform: String
    let appVersion: String
    let build: String
    let processID = ProcessInfo.processInfo.processIdentifier
    let processInstanceID = NetworkAccessDiagnostics.processInstanceID
    let toggles: [String: Bool]
    let limits: [String: Int]
    let selections: [String: String]
    let permissions: [String: Permission]
    let networkObservations: [NetworkAccessDiagnostics.Observation]
    let note =
      "Current settings at capture time; not historical incident settings. Local Network has no general public permission-query API. Observations are scoped evidence, not a global grant; processInstanceID/timestamps identify stale observations. No raw preference or credential dump."
  }
  static func formatted(_ data: Data) -> Data {
    guard data.count <= 8192, let object = try? JSONSerialization.jsonObject(with: data),
      let output = try? JSONSerialization.data(
        withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
    else { return data }
    return output
  }

  static func extract(from report: Data) -> Data? {
    guard report.count <= 262_144,
      let object = try? JSONSerialization.jsonObject(with: report) as? [String: Any],
      let settings = object["settingsSnapshot"] as? [String: Any],
      settings["type"] as? String == "mochilog-settings-snapshot", settings["schema"] as? Int == 1,
      let data = try? JSONSerialization.data(withJSONObject: settings, options: [.sortedKeys]),
      data.count <= 8192
    else { return nil }
    return data
  }

  static func encode(
    platform: String, toggles: [String: Bool], limits: [String: Int],
    selections: [String: String] = [:], permissions: [String: Permission]
  ) -> Data {
    let snapshot = Snapshot(
      platform: platform,
      appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
      build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
      toggles: toggles, limits: limits, selections: selections, permissions: permissions,
      networkObservations: NetworkAccessDiagnostics.shared.snapshot())
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard toggles.count <= 32, limits.count <= 16, selections.count <= 16, permissions.count <= 12,
      selections.values.allSatisfy({ $0.utf8.count <= 80 }),
      let data = try? encoder.encode(snapshot), data.count <= 8192
    else {
      return Data(
        #"{"type":"mochilog-settings-snapshot","schema":1,"unavailable":"snapshot-limit"}"#.utf8)
    }
    return data
  }
}
