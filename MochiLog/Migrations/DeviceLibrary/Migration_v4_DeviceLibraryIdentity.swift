import Foundation

/// Metadata corrections approved after the 2026-10-25 source comparison.
/// This migration never changes capacities, measurements, dates, record IDs or
/// physical device IDs.
enum Migration_v4_DeviceLibraryIdentity {
  static let version = "v4_DeviceLibraryIdentity"
  static let description = "機種ライブラリの識別情報を補正"
  static let swiftDataKey = "Migration_Completed_" + version
  static let coreDataKey = "CoreDataMigration_Completed_" + version

  enum Failure: Error { case saveFailed }

  struct Correction: Equatable {
    let name: String
    let modelCode: String
  }

  /// Watch import always uses the chosen/registered model name and fills its
  /// representative ID using getFirstIdentifier/getIdentifierForDeviceName.
  /// Correct only the old representative ID, preserving that explicit name.
  /// A model-only swap would turn an intentionally selected Series 8 into SE 2.
  private static let watchRepresentativeIDs: [String: (old: String, corrected: String)] = [
    "Apple Watch 4 (44mm)": ("Watch4,3", "Watch4,2"),
    "Apple Watch 8 (41mm)": ("Watch6,10", "Watch6,14"),
    "Apple Watch 8 (45mm)": ("Watch6,11", "Watch6,15"),
    "Apple Watch SE (第2世代) (40mm)": ("Watch6,14", "Watch6,10"),
    "Apple Watch SE (第2世代) (44mm)": ("Watch6,15", "Watch6,11"),
  ]

  /// An already-resolved iPhone/iPad ID does not retain the original board.
  /// Repair a board-derived record only when the literal board is still saved.
  /// Never assume every old iPhone8,1 record originally came from N66AP.
  private static let boardIdentifiers: [String: (old: String, corrected: String)] = [
    "N66AP": ("iPhone8,1", "iPhone8,2"),
    "N66mAP": ("iPhone8,1", "iPhone8,2"),
    "N71AP": ("iPhone8,2", "iPhone8,1"),
    "N71mAP": ("iPhone8,2", "iPhone8,1"),
    "D111AP": ("iPhone9,2", "iPhone9,4"),
    "D11AP": ("iPhone9,4", "iPhone9,2"),
    "J417AP": ("iPad8,10", "iPad8,9"),
    "J418AP": ("iPad8,9", "iPad8,10"),
  ]

  static func correction(
    name: String, modelCode: String?, osVersion: String?,
    profiles: DeviceProfileStore = .shared
  ) -> Correction? {
    guard let modelCode else { return nil }
    if let rule = watchRepresentativeIDs[name], modelCode == rule.old {
      guard osVersion.map({ $0.lowercased().contains("watch") }) ?? true,
        !hasManualProfile(name: name, codes: [rule.old, rule.corrected], profiles: profiles),
        profiles.names[rule.corrected] == name
      else { return nil }
      return Correction(name: name, modelCode: rule.corrected)
    }
    if let rule = boardIdentifiers[modelCode],
      DeviceLibrary.boardToIdentifier[modelCode] == rule.corrected,
      let correctedName = DeviceLibrary.deviceNamesJa[rule.corrected]
    {
      let previousName = DeviceLibrary.deviceNamesJa[rule.old]
      guard name == previousName || name == correctedName || name == "Unknown",
        !hasManualProfile(
          name: name, codes: [rule.old, rule.corrected, modelCode], profiles: profiles),
        profiles.identifier(for: modelCode) == rule.corrected,
        profiles.names[rule.corrected] == correctedName
      else { return nil }
      return Correction(name: correctedName, modelCode: rule.corrected)
    }
    return nil
  }

  private static func hasManualProfile(
    name: String, codes: Set<String>, profiles: DeviceProfileStore
  ) -> Bool {
    profiles.entries.contains { entry in
      entry.current.name == name || entry.original.name == name
        || entry.previousNames.contains(name)
        || !codes.isDisjoint(with: entry.current.identifiers)
        || !codes.isDisjoint(with: entry.original.identifiers)
        || !codes.isDisjoint(with: entry.previousIdentifiers)
        || !codes.isDisjoint(with: entry.current.boards.keys)
        || !codes.isDisjoint(with: entry.original.boards.keys)
    }
  }
}
