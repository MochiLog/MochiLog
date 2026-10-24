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
}
