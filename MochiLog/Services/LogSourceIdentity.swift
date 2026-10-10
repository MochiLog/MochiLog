import Foundation

/// A receiving device is not evidence of the device that made a shared log.
nonisolated enum LogSourceIdentity {
  static func validHostModel(_ model: String) -> Bool {
    model.range(of: #"^(iPhone|iPad)[0-9]+,[0-9]+$"#, options: .regularExpression) != nil
  }

  static func resolve(detected: String?, source: UUID?, known: [UUID: String],
    local: String?, foreign: Bool) -> String? {
    if let source, let model = known[source] {
      // Contradictory log metadata requires review instead of choosing a side.
      if let detected, detected != model { return nil }
      return model
    }
    if let detected { return detected }
    return foreign ? nil : local
  }

  static func shouldRepair(recordID: UUID, origin: UUID?, model: String?,
    known: [UUID: String]) -> String? {
    guard recordID.uuid.6 >> 4 == 5, let origin, let correct = known[origin],
      validHostModel(correct), model.map(validHostModel) == true, model != correct else { return nil }
    return correct
  }
}
