import Foundation

enum SIMConfiguration: String, Codable, CaseIterable, Identifiable {
  case esim
  case physicalSIM

  var id: String { rawValue }
}

struct DeviceCapacityVariant: Codable, Equatable, Identifiable {
  var configuration: SIMConfiguration
  var capacity: Int?
  var region: String?

  var id: String { configuration.rawValue }
}

struct DeviceProfile: Codable, Equatable, Identifiable {
  var id: String
  var name: String
  var identifiers: [String]
  var capacity: Int
  var soc: String
  var boards: [String: String]
  var modelNumbers: [String]
  var modelNumbersByIdentifier: [String: [String]]
  var capacityVariants: [DeviceCapacityVariant]

  init(
    id: String, name: String, identifiers: [String], capacity: Int, soc: String,
    boards: [String: String], modelNumbers: [String] = [],
    modelNumbersByIdentifier: [String: [String]] = [:],
    capacityVariants: [DeviceCapacityVariant] = []
  ) {
    self.id = id
    self.name = name
    self.identifiers = identifiers
    self.capacity = capacity
    self.soc = soc
    self.boards = boards
    self.modelNumbers = modelNumbers
    self.modelNumbersByIdentifier = modelNumbersByIdentifier
    self.capacityVariants = capacityVariants
  }

  private enum CodingKeys: String, CodingKey {
    case id, name, identifiers, capacity, soc, boards, modelNumbers, modelNumbersByIdentifier,
      capacityVariants
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    name = try values.decode(String.self, forKey: .name)
    identifiers = try values.decode([String].self, forKey: .identifiers)
    capacity = try values.decode(Int.self, forKey: .capacity)
    soc = try values.decode(String.self, forKey: .soc)
    boards = try values.decode([String: String].self, forKey: .boards)
    modelNumbers = try values.decodeIfPresent([String].self, forKey: .modelNumbers) ?? []
    modelNumbersByIdentifier =
      try values.decodeIfPresent([String: [String]].self, forKey: .modelNumbersByIdentifier) ?? [:]
    capacityVariants =
      try values.decodeIfPresent([DeviceCapacityVariant].self, forKey: .capacityVariants) ?? []
  }

  enum Category: String, CaseIterable, Identifiable {
    case iphone = "iPhone", ipad = "iPad", watch = "Apple Watch", ipod = "iPod", other
    var id: String { rawValue }
    var icon: String {
      switch self {
      case .iphone: return "iphone"
      case .ipad: return "ipad"
      case .watch: return "applewatch"
      case .ipod: return "ipod"
      case .other: return "square.grid.2x2"
      }
    }
  }

  var category: Category {
    if identifiers.contains(where: { $0.hasPrefix("iPhone") }) { return .iphone }
    if identifiers.contains(where: { $0.hasPrefix("iPad") }) { return .ipad }
    if identifiers.contains(where: { $0.hasPrefix("Watch") }) { return .watch }
    if identifiers.contains(where: { $0.hasPrefix("iPod") }) { return .ipod }
    return .other
  }

  func matches(_ other: DeviceProfile) -> Bool {
    name.caseInsensitiveCompare(other.name) == .orderedSame
      || !Set(identifiers).isDisjoint(with: other.identifiers)
  }
}

struct DeviceProfileEntry: Codable, Equatable, Identifiable {
  var id: String { original.id }
  let original: DeviceProfile
  var current: DeviceProfile
  var acceptedBundled: [DeviceProfile]
  var previousNames: Set<String>
  var previousIdentifiers: Set<String>
}

/// Pure catalog operations also used by the regression tests.
enum DeviceProfileCatalog {
  static func conflicts(_ entry: DeviceProfileEntry, bundled: [DeviceProfile]) -> [DeviceProfile] {
    let matches = bundled.filter { entry.current.matches($0) || entry.original.matches($0) }
      .sorted { $0.id < $1.id }
    return matches == entry.acceptedBundled.sorted(by: { $0.id < $1.id }) ? [] : matches
  }

  static func merged(bundled: [DeviceProfile], entries: [DeviceProfileEntry]) -> [DeviceProfile] {
    let defaults = bundled.filter { profile in
      !entries.contains { $0.current.matches(profile) || $0.original.id == profile.id }
    }
    return (defaults + entries.map(\.current)).sorted {
      $0.name.localizedStandardCompare($1.name) == .orderedAscending
    }
  }

  static func validationError(_ profile: DeviceProfile, others: [DeviceProfile]) -> String? {
    if profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return "profile_name_required"
    }
    let permitsUnknownCapacity =
      profile.capacity == 0
      && profile.capacityVariants.contains(where: {
        $0.configuration == .esim && $0.capacity == nil
      })
    if !(1...100000).contains(profile.capacity) && !permitsUnknownCapacity {
      return "profile_capacity_invalid"
    }
    if profile.identifiers.contains(where: {
      $0.range(
        of: "^((iPhone|iPad|Watch|iPod)[0-9]+,[0-9]+|A[0-9]{4})$", options: .regularExpression)
        == nil
    })
      || Set(profile.identifiers).count != profile.identifiers.count
    {
      return "profile_identifiers_invalid"
    }
    if profile.boards.contains(where: { $0.key.isEmpty || !profile.identifiers.contains($0.value) })
    {
      return "profile_boards_invalid"
    }
    if Set(profile.modelNumbers).count != profile.modelNumbers.count {
      return "profile_model_numbers_invalid"
    }
    if profile.modelNumbersByIdentifier.contains(where: { !profile.identifiers.contains($0.key) }) {
      return "profile_model_numbers_invalid"
    }
    if Set(profile.capacityVariants.map(\.configuration)).count != profile.capacityVariants.count
      || profile.capacityVariants.contains(where: { variant in
        if let capacity = variant.capacity { return !(1...100000).contains(capacity) }
        return false
      })
    {
      return "profile_sim_capacities_invalid"
    }
    if others.contains(where: { $0.id != profile.id && profile.matches($0) }) {
      return "profile_duplicate"
    }
    if others.contains(where: { other in
      other.id != profile.id && !Set(other.boards.keys).isDisjoint(with: profile.boards.keys)
    }) {
      return "profile_board_duplicate"
    }
    return nil
  }
}
