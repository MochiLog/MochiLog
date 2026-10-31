import Foundation

// Standalone catalog export uses no app preferences or localized display strings.
enum L10n {
  static let language = "ja"
  static func string(_ key: String, table: String) -> String { key }
  static func string(_ key: String.LocalizationValue, table: String) -> String { "validation" }
}
final class AppSettings {
  static let shared = AppSettings()
  var overrideLocalModelIdentifier = ""
}

@main
struct ExportDeviceCatalog {
  static func main() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard let destination = arguments.first else { throw ExportError.destinationRequired }
    let revision = arguments.count > 1 ? Int(arguments[1]) : DeviceCatalog.bundledRevision
    guard let revision else { throw ExportError.invalidRevision }
    let catalog = DeviceCatalog(
      schemaVersion: DeviceCatalog.schemaVersion, revision: revision,
      profiles: DeviceProfileStore.bundled)
    var seen: [DeviceProfile] = []
    for profile in catalog.profiles {
      var checked = profile
      checked.capacity = max(1, checked.capacity)
      if let error = DeviceProfileCatalog.validationError(checked, others: seen) {
        FileHandle.standardError.write(
          Data("Invalid bundled profile \(profile.name): \(error)\n".utf8))
      }
      seen.append(profile)
    }
    try catalog.validate()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(catalog).write(to: URL(fileURLWithPath: destination), options: .atomic)
    print("Exported \(catalog.profiles.count) profiles at revision \(revision)")
  }
  enum ExportError: Error { case destinationRequired, invalidRevision }
}
