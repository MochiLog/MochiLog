import SwiftUI

@available(iOS 27, *)
struct LiveBatteryView: View {
  @ObservedObject private var manager = LiveBatteryManager.shared
  @ObservedObject private var local = LocalDiagnosticsManager.shared
  @ObservedObject private var transfer = MacTransferManager.shared
  private func text(_ key: String) -> String { L10n.text(key, table: "MacTransfer") }

  private var sources: [LiveBatterySource] {
    let pairs = manager.activePairings
    let totals = Dictionary(grouping: pairs, by: { $0.platform == "windows" ? "Windows" : "Mac" }).mapValues(\.count)
    var indices: [String: Int] = [:]
    let computers = pairs.flatMap { pair -> [LiveBatterySource] in
      let platform = pair.platform == "windows" ? "Windows" : "Mac"
      let index = indices[platform, default: 0] + 1
      indices[platform] = index
      let name = totals[platform, default: 0] > 1 ? "\(platform) \(index)" : platform
      let own = LiveBatterySource(id: pair.hostID, physicalDeviceID: pair.physicalDeviceID,
        model: pair.model, name: name, reading: manager.readings[pair.hostID],
        state: manager.states[pair.hostID] ?? "waiting")
      let shared = (manager.sharedSources[pair.hostID] ?? [:]).sorted { $0.key.uuidString < $1.key.uuidString }
        .filter { $0.value.scope == CloudLogSharingState.shared.scope }
        .map { id, source in LiveBatterySource(id: pair.hostID, physicalDeviceID: id,
          model: source.model, name: name, reading: source.reading, state: source.state) }
      return [own] + shared
    }
    if AppSettings.shared.localAutomaticCollectionEnabled && local.configured {
      let own = LiveBatterySource(id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        physicalDeviceID: PhysicalDeviceIdentityStore.current(), model: DeviceLibrary.localModelIdentifier() ?? "",
        name: text("local_source"), reading: local.reading, state: local.state)
      return computers + [own]
    }
    return computers
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Label(text("live_title"), systemImage: "battery.100percent").font(.largeTitle.bold())
          Text(text("live_note")).foregroundStyle(.secondary)
          Text(text("live_network_note")).font(.caption).foregroundStyle(.secondary)
          HStack {
            Button { Task { async let pc: () = manager.receiveNow(); async let own: () = local.receiveBatteryNow(); _ = await (pc, own) } } label: {
              Label(text("live_receive"), systemImage: "arrow.down.circle")
            }.accessibilityIdentifier("live.receive")
            Button { Task { async let pc: () = manager.receiveNow(refresh: true); async let own: () = local.receiveBatteryNow(); _ = await (pc, own) } } label: {
              Label(text("live_request"), systemImage: "paperplane")
            }.accessibilityIdentifier("live.send")
            if manager.busy || local.batteryBusy { ProgressView() }
          }.buttonStyle(.bordered).disabled(manager.busy || local.batteryBusy)
          if sources.isEmpty {
            ContentUnavailableView(text("live_pair_first"), systemImage: "laptopcomputer.and.iphone",
              description: Text(text("live_pair_detail")))
            NavigationLink { MacTransferSettingsView() } label: { Text(text("live_pair_open")) }
          }
          ForEach(LiveBatteryComparison.devices(sources)) { device in
            deviceCard(device)
          }
        }.padding().frame(maxWidth: 1100, alignment: .leading).frame(maxWidth: .infinity)
      }
      .navigationTitle(text("live_title"))
      .navigationBarTitleDisplayMode(.inline)
      .onAppear { manager.updateActivity(); local.updateActivity() }
    }
  }

  private func deviceName(_ device: LiveBatteryDeviceReadings) -> String {
    let model = device.sources.first?.model ?? ""
    let name = DeviceProfileStore.shared.names[model] ?? DeviceLibrary.getDeviceName(for: model) ?? model
    return DeviceLibrary.localizedName(for: name)
  }

  private func deviceCard(_ device: LiveBatteryDeviceReadings) -> some View {
    let readings = device.sources.map(\.reading)
    let fields = LiveBatteryComparison.summary(readings)
    let common = fields.filter(\.isCommon)
    let differences = fields.filter { !$0.isCommon }
    return VStack(alignment: .leading, spacing: 18) {
      Label(deviceName(device), systemImage: device.sources.first?.model.hasPrefix("iPad") == true ? "ipad" : "iphone")
        .font(.headline).accessibilityIdentifier("live.deviceName")
      if device.sources.count > 1 {
        Text(text("live_common")).font(.subheadline.weight(.semibold))
      }
      Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
        GridRow { Text(text("live_field")); Text(text("live_value")) }
          .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        ForEach(common) { field in
          Divider().gridCellColumns(2)
          GridRow(alignment: .top) {
            Text(text("live_" + field.id)).frame(maxWidth: .infinity, alignment: .leading)
            Text(field.values.first.flatMap { $0 }?.display(text: text) ?? text("live_missing"))
              .monospacedDigit().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
              .accessibilityIdentifier("live." + field.id)
          }
        }
      }.font(.callout)
      if !differences.isEmpty {
        Text(text("live_differences")).font(.subheadline.weight(.semibold))
          .accessibilityIdentifier("live.differences")
        Text(text("live_compare_note")).font(.caption).foregroundStyle(.secondary)
        ForEach(differences) { field in
          VStack(alignment: .leading, spacing: 10) {
            Text(text("live_" + field.id)).font(.callout.weight(.medium))
            ForEach(Array(device.sources.enumerated()), id: \.element.id) { index, source in
              HStack(alignment: .top) {
                Text(source.name).foregroundStyle(.secondary)
                Spacer()
                Text(field.values[index]?.display(text: text) ?? text("live_missing"))
                  .monospacedDigit().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                  .accessibilityIdentifier("live.diff." + field.id + "." + source.name)
              }
            }
          }.padding(14).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        }
      }
      if readings.contains(where: { $0 != nil }) {
        DisclosureGroup {
          ComparedRawBatteryFieldsView(fields: LiveBatteryComparison.details(readings),
            names: device.sources.map(\.name), text: text)
          ForEach(device.sources.filter { $0.reading != nil && $0.reading?.fields.isEmpty == true }) { source in
            Text(source.name + ": " + text("live_details_missing")).font(.caption)
          }
        } label: { Label(text("live_details"), systemImage: "list.bullet.rectangle") }
        .accessibilityIdentifier("live.details")
      }
      Divider()
      Text(text("live_sources")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
      ForEach(device.sources) { source in
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text(source.name).font(.callout.weight(.medium))
            Spacer()
            Label(text("live_state_" + source.state), systemImage: source.state == "current" ? "checkmark.circle" : "clock")
              .font(.caption).foregroundStyle(source.state == "current" ? Color.green : Color.secondary)
          }
          if let reading = source.reading {
            HStack(alignment: .firstTextBaseline) {
              Text(text("live_last"))
              Text(reading.acquiredAt, format: .dateTime.year().month().day().hour().minute().second())
            }.font(.caption).foregroundStyle(.secondary)
          }
        }
      }
    }.padding(20).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
  }
}

@available(iOS 27, *)
private struct ComparedRawBatteryFieldsView: View {
  let fields: [ComparedBatteryField<BatteryFieldPath, RawBatteryField>]
  let names: [String]
  let text: (String) -> String
  private var groups: [String: [ComparedBatteryField<BatteryFieldPath, RawBatteryField>]] {
    Dictionary(grouping: fields, by: { $0.id.group })
  }
  private func value(_ field: RawBatteryField?) -> String {
    guard let field else { return text("live_missing") }
    return field.kind == "boolean" && ["true", "false"].contains(field.value) ? text(field.value == "true" ? "live_true" : "live_false")
      : (field.kind == "data" ? "Base64 · " : "") + field.value
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(text("live_details_note")).font(.caption).foregroundStyle(.secondary)
      if fields.isEmpty { Text(text("live_details_empty")).font(.caption) }
      ForEach(groups.keys.sorted(), id: \.self) { group in
        DisclosureGroup {
          VStack(alignment: .leading, spacing: 12) {
            ForEach(groups[group] ?? []) { field in
              VStack(alignment: .leading, spacing: 6) {
                Text(field.id.label).font(.subheadline.weight(.medium)).textSelection(.enabled)
                if field.isCommon {
                  Text(value(field.values.first.flatMap { $0 }))
                    .font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                } else {
                  ForEach(names.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 3) {
                      HStack {
                        Text(names[index])
                        Spacer()
                        Text(field.values[index]?.kind ?? "")
                      }.font(.caption).foregroundStyle(.secondary)
                      Text(value(field.values[index])).font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                  }
                }
                Divider()
              }
            }
          }.padding(.top, 8)
        } label: {
          HStack {
            Text(group.isEmpty ? text("live_details_general") : group)
            Spacer()
            Text(String(groups[group]?.count ?? 0)).font(.caption).foregroundStyle(.secondary)
          }
        }
      }
    }
  }
}
