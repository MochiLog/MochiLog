import Combine
import Foundation

final class RenderingPreferences: ObservableObject {
  static let shared = RenderingPreferences()
  enum Mode: String, CaseIterable, Identifiable {
    case automatic, reduced, full
    var id: String { rawValue }
  }
  @Published var mode: Mode {
    didSet { UserDefaults.standard.set(mode.rawValue, forKey: "renderingMode") }
  }
  @Published private(set) var constrained: Bool
  private var observers = Set<AnyCancellable>()

  var reduced: Bool { mode == .reduced || (mode == .automatic && constrained) }

  private static func isConstrained() -> Bool {
    let process = ProcessInfo.processInfo
    // Memory is a conservative device-budget heuristic, not a GPU benchmark.
    return process.physicalMemory <= 4 * 1024 * 1024 * 1024
      || process.isLowPowerModeEnabled
      || process.thermalState == .serious || process.thermalState == .critical
  }

  private init() {
    mode = Mode(rawValue: UserDefaults.standard.string(forKey: "renderingMode") ?? "") ?? .automatic
    constrained = Self.isConstrained()
    NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
      .merge(
        with: NotificationCenter.default.publisher(
          for: ProcessInfo.thermalStateDidChangeNotification)
      )
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in self?.constrained = Self.isConstrained() }
      .store(in: &observers)
  }
}
