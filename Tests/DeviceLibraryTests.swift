import Foundation

enum L10n {
  static let language = "en"
  static func string(_ key: String, table: String) -> String { key }
  static func string(_ key: String.LocalizationValue, table: String) -> String { "validation" }
}
final class AppSettings {
  static let shared = AppSettings()
  var overrideLocalModelIdentifier = ""
}

@main
struct DeviceLibraryTests {
  static func main() throws {
    try verifyIdentityCorrections()
    let suite = "MochiLog.DeviceLibraryTests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let profiles = DeviceProfileStore(defaults: defaults)
    let variants = [
      ("Watch3,1", "Apple Watch 3 (38mm) Cellular", 279),
      ("Watch3,2", "Apple Watch 3 (42mm) Cellular", 352),
      ("Watch3,3", "Apple Watch 3 (38mm)", 262),
      ("Watch3,4", "Apple Watch 3 (42mm)", 342),
    ]
    for (identifier, name, capacity) in variants {
      precondition(profiles.names[identifier] == name)
      precondition(profiles.modelIdentifier(for: name) == identifier)
      precondition(profiles.capacity(name) == capacity)
    }
    let cellular42 = variants[1].1
    func correction(_ name: String, _ capacity: Int) -> Int? {
      Migration_v3_WatchSeries3Capacity.correctedDesignCapacity(
        for: name, storedCapacity: capacity, profiles: profiles)
    }
    precondition(correction(cellular42, 279) == 352)
    precondition(correction(variants[0].1, 262) == 279)
    precondition(correction(cellular42, 352) == nil, "Correction must be idempotent")
    precondition(
      correction(cellular42, 300) == nil, "Unrecognized measured/custom values stay intact")
    precondition(correction(variants[3].1, 279) == nil, "GPS records are not reclassified")
    var edited = profiles.profiles.first { $0.name == cellular42 }!
    edited.capacity = 400
    try profiles.save(edited)
    precondition(correction(cellular42, 279) == nil, "Local overrides are preserved")
    edited.capacity = 352
    try profiles.save(edited)
    precondition(
      correction(cellular42, 279) == nil, "Even a matching explicit override stays manual")
    print("PASS: all four Series 3 variants, legacy corrections, idempotency and manual overrides")
  }

  private static func verifyIdentityCorrections() throws {
    let suite = "MochiLog.DeviceLibraryIdentityTests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let profiles = DeviceProfileStore(defaults: defaults)
    let names = [
      "Watch4,2": "Apple Watch 4 (44mm)",
      "Watch4,3": "Apple Watch 4 (40mm)",
      "Watch6,10": "Apple Watch SE (第2世代) (40mm)",
      "Watch6,11": "Apple Watch SE (第2世代) (44mm)",
      "Watch6,12": "Apple Watch SE (第2世代) (40mm)",
      "Watch6,13": "Apple Watch SE (第2世代) (44mm)",
      "Watch6,14": "Apple Watch 8 (41mm)",
      "Watch6,15": "Apple Watch 8 (45mm)",
      "Watch6,16": "Apple Watch 8 (41mm)",
      "Watch6,17": "Apple Watch 8 (45mm)",
    ]
    for (identifier, name) in names { precondition(profiles.names[identifier] == name) }
    let boards = [
      "N66AP": "iPhone8,2", "N66mAP": "iPhone8,2",
      "N71AP": "iPhone8,1", "N71mAP": "iPhone8,1",
      "D111AP": "iPhone9,4", "D11AP": "iPhone9,2",
      "J417AP": "iPad8,9", "J418AP": "iPad8,10",
    ]
    for (board, identifier) in boards {
      precondition(profiles.identifier(for: board) == identifier)
    }
    for size in [42, 46] {
      precondition(profiles.soc("Apple Watch 12 (\(size)mm) Cellular") == "S11")
    }
    let watchCases = [
      ("Apple Watch 4 (44mm)", "Watch4,3", "Watch4,2"),
      ("Apple Watch 8 (41mm)", "Watch6,10", "Watch6,14"),
      ("Apple Watch 8 (45mm)", "Watch6,11", "Watch6,15"),
      ("Apple Watch SE (第2世代) (40mm)", "Watch6,14", "Watch6,10"),
      ("Apple Watch SE (第2世代) (44mm)", "Watch6,15", "Watch6,11"),
    ]
    func correction(_ name: String, _ code: String?, os: String? = "watchOS 26.0")
      -> Migration_v4_DeviceLibraryIdentity.Correction?
    {
      Migration_v4_DeviceLibraryIdentity.correction(
        name: name, modelCode: code, osVersion: os, profiles: profiles)
    }
    for (name, old, corrected) in watchCases {
      precondition(correction(name, old) == .init(name: name, modelCode: corrected))
      precondition(profiles.modelIdentifier(for: name) == corrected)
      precondition(correction(name, corrected) == nil, "A second pass must not swap IDs back")
      precondition(correction(name, old, os: "iOS 27.0") == nil)
    }
    for (board, identifier) in boards {
      let name = profiles.names[identifier]!
      precondition(correction("Unknown", board) == .init(name: name, modelCode: identifier))
      precondition(correction(name, identifier) == nil, "A resolved ID has no board provenance")
    }
    precondition(correction("iPhone 6s", "iPhone8,1", os: "iOS 16.0") == nil)
    precondition(correction("Apple Watch 4 (40mm)", "Watch4,3") == nil)
    precondition(correction("Unknown", "Watch6,10") == nil)
    precondition(correction("Apple Watch 8 (41mm)", nil) == nil)
    precondition(correction("Custom device", "N66AP") == nil)

    var customized = profiles.profiles.first { $0.name == "Apple Watch 8 (41mm)" }!
    // Even a saved override equal to today's standard is still user-owned.
    try profiles.save(customized)
    precondition(correction(customized.name, "Watch6,10") == nil)
    customized.name = "My custom watch"
    try profiles.save(customized)
    precondition(correction("Apple Watch 8 (41mm)", "Watch6,10") == nil)
    print(
      "PASS: 20 identity references, legacy Watch representative IDs, board provenance, repeat passes and user overrides"
    )
  }
}
