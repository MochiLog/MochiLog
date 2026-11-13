import Foundation
import Network

/// Passive observations, not a query of the global Local Network permission.
/// Never probe/request permission merely to generate a support report.
nonisolated final class NetworkAccessDiagnostics: @unchecked Sendable {
  struct Observation: Codable {
    let component: String
    let capturedAt: String
    let processID: Int32
    let processInstanceID: String
    let state: String
    let denialObserved: Bool
    let wifi: Bool?
    let cellular: Bool?
    let constrained: Bool?
    let expensive: Bool?
    let errorDomain: String?
    let errorCode: Int?
  }
  static let processInstanceID = UUID().uuidString
  static let shared = NetworkAccessDiagnostics(
    defaults: ProcessInfo.processInfo.environment["MOCHILOG_TRANSFER_TEST_ROOT"] == nil
      ? .standard : nil)
  private let lock = NSLock()
  private let defaults: UserDefaults?
  private let key = "MochiLogNetworkAccessObservationsV1"
  private var entries: [Observation] = []

  init(defaults: UserDefaults?) {
    self.defaults = defaults
    if let data = defaults?.data(forKey: key), data.count <= 8192,
      let saved = try? JSONDecoder().decode([Observation].self, from: data)
    {
      entries = Array(saved.suffix(8))
    }
  }

  func recordPath(_ path: NWPath, component: String) {
    record(
      component: component, state: "path-\(path.status)-\(path.unsatisfiedReason)",
      denied: path.unsatisfiedReason == .localNetworkDenied,
      wifi: path.usesInterfaceType(.wifi), cellular: path.usesInterfaceType(.cellular),
      constrained: path.isConstrained, expensive: path.isExpensive)
  }

  func record(
    component: String, state: String, denied: Bool = false,
    wifi: Bool? = nil, cellular: Bool? = nil, constrained: Bool? = nil,
    expensive: Bool? = nil, error: Error? = nil
  ) {
    let problem = error.map(PCConnectionFailure.systemError)
    let entry = Observation(
      component: String(component.prefix(48)), capturedAt: Self.now(),
      processID: ProcessInfo.processInfo.processIdentifier,
      processInstanceID: Self.processInstanceID, state: String(state.prefix(80)),
      denialObserved: denied, wifi: wifi, cellular: cellular, constrained: constrained,
      expensive: expensive, errorDomain: problem.map { String($0.domain.prefix(80)) },
      errorCode: problem?.code)
    lock.lock()
    defer { lock.unlock() }
    entries.removeAll { $0.component == entry.component }
    entries.append(entry)
    entries = Array(entries.suffix(8))
    if let data = try? JSONEncoder().encode(entries), data.count <= 8192 {
      defaults?.set(data, forKey: key)
    }
  }

  func snapshot() -> [Observation] {
    lock.lock()
    defer { lock.unlock() }
    return entries
  }

  static func now() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = .autoupdatingCurrent
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: Date())
  }
}
