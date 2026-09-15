import SwiftUI

private func profileText(_ key: String) -> String { L10n.string(String.LocalizationValue(key), table: "Settings") }

struct DeviceProfilesView: View {
  @ObservedObject private var store = DeviceProfileStore.shared
  @State private var search = ""
  @State private var showingAdd = false
  @State private var expandedCategories: Set<DeviceProfile.Category> = []

  var body: some View {
    List {
      Section {
        Button { showingAdd = true } label: {
          Label(profileText("profile_add"), systemImage: "plus.circle.fill")
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("profiles.addRow")
      }
      Section {
        TextField(profileText("profile_search"), text: $search)
          .textInputAutocapitalization(.never).autocorrectionDisabled()
          .accessibilityIdentifier("profiles.search")
      }
      if !store.conflicts.isEmpty {
        Section(profileText("profile_conflicts")) {
          ForEach(store.conflicts) { entry in
            NavigationLink { DeviceProfileEditor(profile: entry.current) } label: {
              Label(entry.current.name, systemImage: "exclamationmark.triangle")
            }
          }
        }
      }
      let grouped = Dictionary(grouping: store.profiles.filter { search.isEmpty
        || $0.name.localizedCaseInsensitiveContains(search)
        || $0.identifiers.contains(where: { $0.localizedCaseInsensitiveContains(search) }) }, by: \.category)
      ForEach(DeviceProfile.Category.allCases) { category in
        let profiles = newestFirst(grouped[category] ?? [])
        if search.isEmpty || !profiles.isEmpty {
          Section {
            DisclosureGroup(isExpanded: Binding(
              get: { !search.isEmpty || expandedCategories.contains(category) },
              set: { expanded in
                if expanded { expandedCategories.insert(category) }
                else { expandedCategories.remove(category) }
              })) {
              ForEach(profiles) { profile in
                NavigationLink { DeviceProfileEditor(profile: profile) } label: {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(DeviceLibrary.localizedName(for: profile.name))
                    if !profile.identifiers.isEmpty {
                      Text(profile.identifiers.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    if store.entry(for: profile.id) != nil {
                      Text(profileText("profile_customized")).font(.caption).foregroundStyle(.tint)
                    }
                  }
                }
                .accessibilityIdentifier("profiles.model.\(profile.id)")
              }
            } label: {
              HStack {
                Label(category == .other ? profileText("profile_category_other") : category.rawValue,
                  systemImage: category.icon)
                Spacer()
                Text(profiles.count, format: .number).foregroundStyle(.secondary)
              }
              .accessibilityIdentifier("profiles.category.\(category.id)")
            }
          }
        }
      }
      Section {} footer: { Text(profileText("profile_library_footer")) }
    }
    .navigationTitle(profileText("profile_library"))
    .toolbar {
      Button { showingAdd = true } label: { Image(systemName: "plus") }
        .accessibilityLabel(profileText("profile_add"))
        .accessibilityIdentifier("profiles.add")
    }
    .sheet(isPresented: $showingAdd) {
      NavigationStack {
        DeviceProfileEditor(profile: DeviceProfile(id: UUID().uuidString, name: "", identifiers: [],
          capacity: 0, soc: "", boards: [:]), isNew: true)
      }
    }
    .accessibilityIdentifier("profiles.list")
  }
  private func newestFirst(_ profiles: [DeviceProfile]) -> [DeviceProfile] {
    // Match the model picker: compare identifier generations numerically, not model names.
    let keyed = profiles.map { profile in
      (profile: profile, identifier: profile.identifiers.max {
        $0.compare($1, options: .numeric) == .orderedAscending
      } ?? "")
    }
    return keyed.sorted { lhs, rhs in
      let order = lhs.identifier.compare(rhs.identifier, options: .numeric)
      if order != .orderedSame { return order == .orderedDescending }
      let nameOrder = lhs.profile.name.localizedStandardCompare(rhs.profile.name)
      if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
      return lhs.profile.id < rhs.profile.id
    }.map(\.profile)
  }
}

private struct DeviceProfileEditor: View {
  let profile: DeviceProfile
  var isNew = false
  @EnvironmentObject private var dataStore: DataStore
  @Environment(\.dismiss) private var dismiss
  @ObservedObject private var store = DeviceProfileStore.shared
  @State private var name: String
  @State private var identifiers: String
  @State private var capacity: String
  @State private var soc: String
  @State private var boards: String
  @State private var modelNumbers: String
  @State private var esimCapacity: String
  @State private var physicalSIMCapacity: String
  @State private var message: String?
  @State private var confirmApply = false
  @State private var confirmRestore = false
  @State private var applying = false
  @FocusState private var focusedField: String?

  init(profile: DeviceProfile, isNew: Bool = false) {
    self.profile = profile
    self.isNew = isNew
    _name = State(initialValue: profile.name)
    _identifiers = State(initialValue: profile.identifiers.joined(separator: "\n"))
    _capacity = State(initialValue: profile.capacity > 0 ? String(profile.capacity) : "")
    _soc = State(initialValue: profile.soc)
    _boards = State(initialValue: profile.boards.keys.sorted().map { "\($0)=\(profile.boards[$0]!)" }.joined(separator: "\n"))
    _modelNumbers = State(initialValue: profile.modelNumbers.joined(separator: "\n"))
    _esimCapacity = State(initialValue: profile.capacityVariants.first(where: { $0.configuration == .esim })?.capacity.map(String.init) ?? "")
    _physicalSIMCapacity = State(initialValue: profile.capacityVariants.first(where: { $0.configuration == .physicalSIM })?.capacity.map(String.init) ?? "")
  }

  private var entry: DeviceProfileEntry? { store.entry(for: profile.id) }
  private var current: DeviceProfile { entry?.current ?? profile }
  private var original: DeviceProfile { entry?.original ?? profile }
  private var sourceNames: Set<String> { (entry?.previousNames ?? []).union([profile.name, original.name, current.name]) }
  private var sourceIdentifiers: Set<String> {
    (entry?.previousIdentifiers ?? []).union(profile.identifiers).union(original.identifiers).union(current.identifiers)
  }
  private var matchingCount: Int {
    dataStore.recordsDescending.filter { sourceNames.contains($0.deviceName) || sourceIdentifiers.contains($0.deviceModelCode ?? "") }.count
  }
  private var conflicts: [DeviceProfile] {
    guard let entry else { return [] }
    return DeviceProfileCatalog.conflicts(entry, bundled: DeviceProfileStore.bundled)
  }

  var body: some View {
    Form {
      conflictSection
      fieldsSection
      existingLogSection
    }
    .navigationTitle(isNew ? profileText("profile_add") : DeviceLibrary.localizedName(for: current.name))
    .navigationBarTitleDisplayMode(.inline)
    .scrollDismissesKeyboard(.interactively)
    .scrollContentBackground(.hidden)
    .background(Color(uiColor: .systemGroupedBackground))
    .toolbar {
      if isNew {
        ToolbarItem(placement: .confirmationAction) {
          Button(profileText("profile_save"), action: save)
            .accessibilityIdentifier("profiles.addSave")
        }
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.string("cancel", table: "Common")) { dismiss() }
        }
      }
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button(L10n.string("close", table: "Common")) { focusedField = nil }
      }
    }
    .alert(profileText("profile_apply"), isPresented: $confirmApply) {
      Button(L10n.string("cancel", table: "Common"), role: .cancel) {}
      Button(profileText("profile_apply")) { apply() }
    } message: { Text(String(format: profileText("profile_apply_confirmation"), matchingCount, current.name, current.capacity)) }
    .alert(profileText("profile_restore"), isPresented: $confirmRestore) {
      Button(L10n.string("cancel", table: "Common"), role: .cancel) {}
      Button(profileText("profile_restore")) {
        do { try store.restore(profile.id); load(current); message = profileText("profile_restored") }
        catch { message = error.localizedDescription }
      }
    } message: { Text(profileText("profile_restore_help")) }
    .alert(profileText("profile_library"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
      Button("OK") { message = nil }
    } message: { Text(message ?? "") }
  }

  @ViewBuilder private var conflictSection: some View {
      if !conflicts.isEmpty {
        Section(profileText("profile_conflicts")) {
          Text(profileText("profile_conflict_description"))
          summary(current, title: profileText("profile_your_values"))
          ForEach(conflicts) { bundled in
            summary(bundled, title: profileText("profile_bundled_values"))
            Button(profileText("profile_use_bundled") + " · " + bundled.name) {
              do { try store.resolve(profile.id, useBundled: true, bundledID: bundled.id); load(current) }
              catch { message = error.localizedDescription }
            }
          }
          Button(profileText("profile_keep_custom")) { resolve(useBundled: false) }
        }
      }
  }

  @ViewBuilder private var fieldsSection: some View {
      Section(profileText("profile_parameters")) {
        VStack(alignment: .leading, spacing: 8) {
          Text(profileText("profile_name")).font(.caption).foregroundStyle(.secondary)
          TextField(profileText("profile_name"), text: $name)
            .textFieldStyle(.roundedBorder).focused($focusedField, equals: "name").accessibilityIdentifier("profiles.name")
        }
        if profile.capacityVariants.isEmpty {
          capacityField(profileText("profile_capacity"), text: $capacity, field: "capacity")
        } else {
          capacityField(profileText("profile_esim_capacity"), text: $esimCapacity, field: "esimCapacity")
          if profile.capacityVariants.contains(where: { $0.configuration == .physicalSIM }) {
            capacityField(profileText("profile_physical_sim_capacity"), text: $physicalSIMCapacity, field: "physicalSIMCapacity")
          }
        }
        VStack(alignment: .leading, spacing: 8) {
          Text("SoC").font(.caption).foregroundStyle(.secondary)
          TextField("SoC", text: $soc).textFieldStyle(.roundedBorder).focused($focusedField, equals: "soc")
            .accessibilityIdentifier("profiles.soc")
        }
      }
      Section {
        TextEditor(text: $identifiers).focused($focusedField, equals: "identifiers").frame(minHeight: 72)
          .textInputAutocapitalization(.never).autocorrectionDisabled()
          .accessibilityIdentifier("profiles.identifiers")
      } header: { Text(profileText("profile_identifiers")) } footer: { Text(profileText("profile_identifiers_help")) }
      Section {
        TextEditor(text: $boards).focused($focusedField, equals: "boards").frame(minHeight: 72)
          .textInputAutocapitalization(.never).autocorrectionDisabled()
      } header: { Text(profileText("profile_boards")) } footer: { Text(profileText("profile_boards_help")) }
      Section {
        TextEditor(text: $modelNumbers).focused($focusedField, equals: "modelNumbers").frame(minHeight: 72)
          .textInputAutocapitalization(.characters).autocorrectionDisabled()
      } header: { Text(profileText("profile_model_numbers")) } footer: { Text(profileText("profile_model_numbers_help")) }
      if !isNew {
        Section {
          actionButton("profile_save", action: save).accessibilityIdentifier("profiles.save")
        } footer: { Text(profileText("profile_save_help")) }
      }
  }

  private func capacityField(_ title: String, text: Binding<String>, field: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      HStack {
        TextField(profileText("profile_unknown"), text: text)
          .textFieldStyle(.roundedBorder)
          .keyboardType(.numberPad)
          .focused($focusedField, equals: field)
          .accessibilityIdentifier("profiles.\(field)")
        Text("mAh").foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder private var existingLogSection: some View {
      if !isNew {
        Section {
          Text(String(format: profileText("profile_matching_count"), matchingCount))
          actionButton("profile_apply") { confirmApply = true }
            .disabled(entry == nil || applying || !conflicts.isEmpty || (try? draft()) != current)
            .accessibilityIdentifier("profiles.apply")
        } header: { Text(profileText("profile_existing_logs")) } footer: { Text(profileText("profile_apply_help")) }
        Section(profileText("profile_defaults")) {
          summary(original, title: profileText("profile_initial_values"))
          actionButton("profile_restore") { confirmRestore = true }
            .disabled(entry == nil)
            .accessibilityIdentifier("profiles.restore")
        }
      }
  }

  private func actionButton(_ key: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(profileText(key))
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
  }

  private func summary(_ value: DeviceProfile, title: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text(DeviceLibrary.localizedName(for: value.name)).font(.headline)
      Text("\(value.capacity) mAh · \(value.soc)")
      Text(value.identifiers.joined(separator: " · ")).font(.caption)
      if !value.modelNumbers.isEmpty && value.modelNumbersByIdentifier.isEmpty {
        Text(value.modelNumbers.joined(separator: " · ")).font(.caption)
      }
      ForEach(value.modelNumbersByIdentifier.keys.sorted(), id: \.self) { identifier in
        Text("\(identifier): \(value.modelNumbersByIdentifier[identifier, default: []].joined(separator: " · "))")
          .font(.caption)
      }
      ForEach(value.capacityVariants) { variant in
        let label = variant.configuration == .esim ? "eSIM" : "Physical SIM (HK)"
        Text("\(label): \(variant.capacity.map { "\($0) mAh" } ?? "—")").font(.caption)
      }
      if !value.boards.isEmpty {
        Text(value.boards.keys.sorted().map { "\($0)=\(value.boards[$0]!)" }.joined(separator: "\n")).font(.caption)
      }
    }
  }

  private func draft() throws -> DeviceProfile {
    var mappings: [String: String] = [:]
    for line in boards.split(whereSeparator: \.isNewline) {
      let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
      guard parts.count == 2, mappings[parts[0]] == nil else { throw DeviceProfileStore.ProfileError(key: "profile_boards_invalid") }
      mappings[parts[0]] = parts[1]
    }
    let ids = identifiers.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
    let models = modelNumbers.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
    if (isNew || !profile.identifiers.isEmpty) && ids.isEmpty { throw DeviceProfileStore.ProfileError(key: "profile_identifiers_invalid") }
    return DeviceProfile(id: profile.id, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
      identifiers: ids, capacity: Int(profile.capacityVariants.isEmpty ? capacity : esimCapacity) ?? 0, soc: soc.trimmingCharacters(in: .whitespacesAndNewlines), boards: mappings,
      modelNumbers: models, modelNumbersByIdentifier: profile.modelNumbersByIdentifier,
      capacityVariants: profile.capacityVariants.map { variant in
        switch variant.configuration {
        case .esim:
          return DeviceCapacityVariant(configuration: .esim, capacity: Int(esimCapacity), region: nil)
        case .physicalSIM:
          return DeviceCapacityVariant(configuration: .physicalSIM, capacity: Int(physicalSIMCapacity), region: "HK/CN")
        }
      })
  }
  private func save() {
    focusedField = nil
    do {
      try store.save(draft())
      if isNew { dismiss() } else { message = profileText("profile_saved") }
    } catch { message = error.localizedDescription }
  }
  private func resolve(useBundled: Bool) {
    do { try store.resolve(profile.id, useBundled: useBundled); load(current) }
    catch { message = error.localizedDescription }
  }
  private func load(_ value: DeviceProfile) {
    name = value.name; capacity = String(value.capacity); soc = value.soc
    identifiers = value.identifiers.joined(separator: "\n")
    boards = value.boards.keys.sorted().map { "\($0)=\(value.boards[$0]!)" }.joined(separator: "\n")
    modelNumbers = value.modelNumbers.joined(separator: "\n")
    esimCapacity = value.capacityVariants.first(where: { $0.configuration == .esim })?.capacity.map(String.init) ?? ""
    physicalSIMCapacity = value.capacityVariants.first(where: { $0.configuration == .physicalSIM })?.capacity.map(String.init) ?? ""
  }
  private func apply() {
    applying = true
    defer { applying = false }
    do {
      let count = try dataStore.applyDeviceProfile(current, names: sourceNames, identifiers: sourceIdentifiers)
      message = String(format: profileText("profile_applied"), count)
    } catch { message = error.localizedDescription }
  }
}
