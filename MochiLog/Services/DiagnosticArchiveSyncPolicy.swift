import Foundation

/// Diagnostic history must not keep another paired computer waiting for logs.
nonisolated enum DiagnosticArchiveSyncPolicy {
  static let roundsPerComputer = 8

  static func shouldRotate(completedRounds: Int, pairedComputers: Int) -> Bool {
    pairedComputers > 1 && completedRounds >= roundsPerComputer
  }

  static func continuationDelay(completedRounds: Int) -> TimeInterval {
    completedRounds > 0 && completedRounds % 25 == 0 ? 10 : 0.3
  }
}
