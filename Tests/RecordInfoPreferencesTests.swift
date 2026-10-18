import Foundation

@main
struct RecordInfoPreferencesTests {
  static func main() {
    let suite = "MochiLog.RecordInfoTests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    RecordInfoPreferences.prepareForLaunch(defaults: defaults, release: "1.0(1)")
    assert(defaults.object(forKey: "showRecordInfoButtons") != nil)
    assert(!defaults.bool(forKey: "showRecordInfoButtons"))
    defaults.set(true, forKey: "showRecordInfoButtons")
    RecordInfoPreferences.prepareForLaunch(defaults: defaults, release: "1.0(1)")
    assert(defaults.bool(forKey: "showRecordInfoButtons"), "Same release preserves manual ON")
    RecordInfoPreferences.prepareForLaunch(defaults: defaults, release: "1.0(2)")
    assert(!defaults.bool(forKey: "showRecordInfoButtons"), "New build resets to OFF")
    defaults.set(true, forKey: "showRecordInfoButtons")
    RecordInfoPreferences.prepareForLaunch(defaults: defaults, release: "1.1(2)")
    assert(!defaults.bool(forKey: "showRecordInfoButtons"), "New version resets to OFF")
    defaults.removeObject(forKey: "recordInfoDefaultsRelease")
    defaults.set(true, forKey: "showRecordInfoButtons")
    RecordInfoPreferences.prepareForLaunch(defaults: defaults, release: "1.1(2)")
    assert(
      !defaults.bool(forKey: "showRecordInfoButtons"),
      "Upgrade from older app without marker resets ON")
    print("PASS: initial OFF, legacy upgrade, version/build updates, manual ON survives relaunch")
  }
}
