import Combine
import Foundation

final class DeviceProfileStore: ObservableObject {
  static let shared = DeviceProfileStore()
  @Published private(set) var revision = 0
  private let lock = NSRecursiveLock()
  private let defaults: UserDefaults
  private let key = "deviceProfileOverrides.v1"
  private var stored: [DeviceProfileEntry]
  private var resolved: [DeviceProfile] = []
  private var nameMap: [String: String] = [:]
  private var capacityMap: [String: Int] = [:]
  private var socMap: [String: String] = [:]
  private var boardMap: [String: String] = [:]

  static let bundled: [DeviceProfile] = {
    let names = Set(DeviceLibrary.deviceNamesJa.values).union(DeviceLibrary.designCapacities.keys)
    return names.sorted().map { name in
      let identifiers = DeviceLibrary.deviceNamesJa.filter { $0.value == name }.keys.sorted()
      let capacityName = DeviceLibrary.capacityReferenceNames[name] ?? name
      return DeviceProfile(id: "bundled:" + name, name: name, identifiers: identifiers,
        capacity: DeviceLibrary.designCapacities[capacityName] ?? 0, soc: DeviceLibrary.socInfo[name] ?? "",
        boards: DeviceLibrary.boardToIdentifier.filter { identifiers.contains($0.value) },
        modelNumbers: DeviceLibrary.modelNumbers[name] ?? [],
        modelNumbersByIdentifier: DeviceLibrary.modelNumbersByIdentifier.filter { identifiers.contains($0.key) },
        capacityVariants: DeviceLibrary.capacityVariants[name] ?? [])
    }
  }()

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    stored = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([DeviceProfileEntry].self, from: $0) } ?? []
    rebuild()
  }

  var profiles: [DeviceProfile] { lock.lock(); defer { lock.unlock() }; return resolved }
  var entries: [DeviceProfileEntry] { lock.lock(); defer { lock.unlock() }; return stored }
  var names: [String: String] { lock.lock(); defer { lock.unlock() }; return nameMap }
  var conflicts: [DeviceProfileEntry] {
    entries.filter { !DeviceProfileCatalog.conflicts($0, bundled: Self.bundled).isEmpty }
  }
  func capacity(_ name: String) -> Int? { lock.lock(); defer { lock.unlock() }; return capacityMap[name] }
  func soc(_ name: String) -> String? { lock.lock(); defer { lock.unlock() }; return socMap[name] }
  func capacityVariant(for name: String, productSku: String?) -> DeviceCapacityVariant? {
    lock.lock(); defer { lock.unlock() }
    let configuration: SIMConfiguration = ["ZP/A", "CH/A"].contains(productSku ?? "") ? .physicalSIM : .esim
    return resolved.first(where: { $0.name == name })?.capacityVariants.first {
      $0.configuration == configuration
    }
  }

  func capacityVariant(for name: String, capacity: Int) -> DeviceCapacityVariant? {
    lock.lock(); defer { lock.unlock() }
    return resolved.first(where: { $0.name == name })?.capacityVariants.first { $0.capacity == capacity }
  }
  func identifier(for board: String) -> String? { lock.lock(); defer { lock.unlock() }; return boardMap[board] }

  func modelIdentifier(for name: String) -> String? {
    lock.lock(); defer { lock.unlock() }
    if let identifier = nameMap.filter({ $0.value == name }).keys.sorted().first { return identifier }
    return stored.first { $0.previousNames.contains(name) }?.current.identifiers.sorted().first
  }

  func entry(for id: String) -> DeviceProfileEntry? { entries.first { $0.id == id } }

  func save(_ profile: DeviceProfile) throws {
    lock.lock(); defer { lock.unlock() }
    if let error = DeviceProfileCatalog.validationError(profile, others: resolved) {
      throw ProfileError(key: error)
    }
    if stored.contains(where: { entry in
      entry.id != profile.id && (entry.previousNames.contains(profile.name)
        || !entry.previousIdentifiers.isDisjoint(with: profile.identifiers))
    }) { throw ProfileError(key: "profile_duplicate") }
    var next = stored
    if let index = next.firstIndex(where: { $0.id == profile.id }) {
      next[index].previousNames.insert(next[index].current.name)
      next[index].previousIdentifiers.formUnion(next[index].current.identifiers)
      next[index].current = profile
    } else {
      let original = Self.bundled.first { $0.id == profile.id } ?? profile
      let bundled = Self.bundled.filter { $0.matches(profile) || $0.matches(original) }
      next.append(DeviceProfileEntry(original: original, current: profile,
        acceptedBundled: bundled.sorted { $0.id < $1.id },
        previousNames: [original.name], previousIdentifiers: Set(original.identifiers)))
    }
    try persist(next)
  }

  func restore(_ id: String) throws {
    guard let entry = entry(for: id) else { return }
    lock.lock(); defer { lock.unlock() }
    var next = stored
    guard let index = next.firstIndex(where: { $0.id == id }) else { return }
    var validation = entry.original
    validation.capacity = max(1, validation.capacity)
    if let error = DeviceProfileCatalog.validationError(validation, others: resolved) { throw ProfileError(key: error) }
    next[index].previousNames.insert(entry.current.name)
    next[index].previousIdentifiers.formUnion(entry.current.identifiers)
    next[index].current = entry.original
    try persist(next)
  }

  func resolve(_ id: String, useBundled: Bool, bundledID: String? = nil) throws {
    lock.lock(); defer { lock.unlock() }
    guard let index = stored.firstIndex(where: { $0.id == id }) else { return }
    var next = stored
    let candidates = Self.bundled.filter { next[index].current.matches($0) || next[index].original.matches($0) }
      .sorted { $0.id < $1.id }
    // Multiple matching standard profiles need an explicit profile choice in the editor.
    let chosen = bundledID.flatMap { id in candidates.first { $0.id == id } } ?? (candidates.count == 1 ? candidates.first : nil)
    guard !useBundled || chosen != nil else { throw ProfileError(key: "profile_multiple_matches") }
    if useBundled, var profile = chosen {
      profile.id = id
      var validation = profile
      validation.capacity = max(1, validation.capacity)
      if let error = DeviceProfileCatalog.validationError(validation, others: resolved) { throw ProfileError(key: error) }
      next[index].previousNames.insert(next[index].current.name)
      next[index].previousIdentifiers.formUnion(next[index].current.identifiers)
      profile.id = id
      next[index].current = profile
    }
    next[index].acceptedBundled = candidates
    try persist(next)
  }

  private func persist(_ next: [DeviceProfileEntry]) throws {
    let data = try JSONEncoder().encode(next)
    defaults.set(data, forKey: key)
    stored = next
    rebuild()
    revision += 1
  }

  private func rebuild() {
    resolved = DeviceProfileCatalog.merged(bundled: Self.bundled, entries: stored)
    nameMap = [:]; capacityMap = [:]; socMap = [:]; boardMap = [:]
    for profile in resolved {
      for identifier in profile.identifiers { nameMap[identifier] = profile.name }
      if profile.capacity > 0 { capacityMap[profile.name] = profile.capacity }
      if !profile.soc.isEmpty { socMap[profile.name] = profile.soc }
      boardMap.merge(profile.boards) { _, new in new }
    }
    // Old log names remain resolvable until the user chooses to update those logs.
    for entry in stored {
      for oldName in entry.previousNames {
        if capacityMap[oldName] == nil, entry.current.capacity > 0 { capacityMap[oldName] = entry.current.capacity }
        if socMap[oldName] == nil, !entry.current.soc.isEmpty { socMap[oldName] = entry.current.soc }
      }
    }
  }

  struct ProfileError: LocalizedError {
    let key: String
    var errorDescription: String? { L10n.string(String.LocalizationValue(key), table: "Settings") }
  }
}
