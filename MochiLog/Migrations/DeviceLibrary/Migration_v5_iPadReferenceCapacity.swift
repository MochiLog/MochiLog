import Foundation

/// Replace only the reviewed old iPad references with Apple's published rated
/// capacities. Measured capacities and user-owned profiles are never rewritten.
enum Migration_v5_iPadReferenceCapacity {
  static let version = "v5_iPadReferenceCapacity"
  static let description = "iPadの基準容量を補正"
  static let swiftDataKey = "Migration_Completed_" + version
  static let coreDataKey = "CoreDataMigration_Completed_" + version

  enum Failure: Error { case saveFailed }

  private static let corrections: [String: (previous: Int, corrected: Int)] = [
    "iPad Pro 13 (M5)": (10340, 10209),
    "iPad Pro 13 (M4)": (10340, 10209),
    "iPad Pro 11 (M5)": (8340, 8160),
    "iPad Pro 11 (M4)": (8340, 8160),
    "iPad mini (A17 Pro)": (5124, 5034),
    "iPad (A16)": (7698, 7606),
    "iPad Air 13 (M4)": (9705, 9720),
    "iPad Air 13 (M3)": (9705, 9720),
  ]

  static func correctedDesignCapacity(
    for name: String, storedCapacity: Int, profiles: DeviceProfileStore = .shared
  ) -> Int? {
    guard let correction = corrections[name], storedCapacity == correction.previous,
      profiles.capacity(name) == correction.corrected
    else { return nil }
    let identifiers = Set(DeviceLibrary.deviceNamesJa.filter { $0.value == name }.keys)
    guard
      !profiles.entries.contains(where: { entry in
        entry.current.name == name || entry.original.name == name
          || entry.previousNames.contains(name)
          || !identifiers.isDisjoint(with: entry.current.identifiers)
          || !identifiers.isDisjoint(with: entry.original.identifiers)
          || !identifiers.isDisjoint(with: entry.previousIdentifiers)
      })
    else { return nil }
    return correction.corrected
  }
}
