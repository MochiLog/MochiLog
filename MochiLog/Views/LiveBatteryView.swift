import SwiftUI

@available(iOS 27, *)
struct LiveBatteryView: View {
  @ObservedObject private var manager = LiveBatteryManager.shared
  @ObservedObject private var transfer = MacTransferManager.shared
  private func text(_ key: String) -> String { L10n.text(key, table: "MacTransfer") }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Label(text("live_title"), systemImage: "battery.100percent")
            .font(.largeTitle.bold())
          Text(text("live_note")).foregroundStyle(.secondary)
          Text(text("live_network_note")).font(.caption).foregroundStyle(.secondary)
          HStack {
            Button { Task { await manager.receiveNow() } } label: {
              Label(text("live_receive"), systemImage: "arrow.down.circle")
            }.accessibilityIdentifier("live.receive")
            Button { Task { await manager.receiveNow(refresh: true) } } label: {
              Label(text("live_request"), systemImage: "paperplane")
            }.accessibilityIdentifier("live.send")
            if manager.busy { ProgressView() }
          }.buttonStyle(.bordered).disabled(manager.busy)
          if manager.activePairings.isEmpty && manager.readings.isEmpty {
            ContentUnavailableView(text("live_pair_first"), systemImage: "laptopcomputer.and.iphone",
              description: Text(text("live_pair_detail")))
            NavigationLink { MacTransferSettingsView() } label: { Text(text("live_pair_open")) }
          }
          ForEach(manager.activePairings, id: \.hostID) { pairing in
            card(id: pairing.hostID, name: pairing.platform == "windows" ? "Windows" : "Mac", model: pairing.model)
          }
          #if DEBUG
          if ProcessInfo.processInfo.environment["MOCHI_LIVE_BATTERY_TEST"] == "1",
            let id = manager.readings.keys.first {
            card(id: id, name: "Mac", model: "iPhone")
          }
          #endif
        }.padding().frame(maxWidth: 1100, alignment: .leading).frame(maxWidth: .infinity)
      }
      .navigationTitle(text("live_title"))
      .navigationBarTitleDisplayMode(.inline)
      .onAppear { manager.updateActivity() }
    }
  }
  private func card(id: UUID, name: String, model: String) -> some View {
    let reading = manager.readings[id]
    let state = manager.states[id] ?? "waiting"
    return VStack(alignment: .leading, spacing: 16) {
      HStack {
        Label(model, systemImage: model.hasPrefix("iPad") ? "ipad" : "iphone")
          .font(.headline)
        Spacer()
        Text(name).font(.caption).foregroundStyle(.secondary)
      }
      Label(text("live_state_" + state), systemImage: state == "current" ? "checkmark.circle" : "clock")
        .foregroundStyle(state == "current" ? Color.green : Color.secondary)
      Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
        GridRow { Text(text("live_field")); Text(text("live_value")) }
          .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        ForEach(BatteryPresentation.summary(values: reading?.values ?? [:], charging: reading?.charging,
          fields: reading?.fields ?? [])) { row in
          Divider().gridCellColumns(2)
          GridRow(alignment: .top) {
            Text(text("live_" + row.key)).frame(maxWidth: .infinity, alignment: .leading)
            Text(row.display(text: text)).monospacedDigit().textSelection(.enabled)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityIdentifier("live." + row.key)
          }
        }
      }.font(.callout)
      if let reading {
        DisclosureGroup {
          if reading.fields.isEmpty { Text(text("live_details_missing")).font(.caption) }
          else { RawBatteryFieldsView(fields: BatteryPresentation.details(values: reading.values,
            charging: reading.charging, fields: reading.fields), text: text) }
        } label: { Label(text("live_details"), systemImage: "list.bullet.rectangle") }
        .accessibilityIdentifier("live.details")
        HStack(alignment: .firstTextBaseline) {
          Text(text("live_last"))
          Text(reading.acquiredAt, format: .dateTime.year().month().day().hour().minute().second())
        }.font(.caption).foregroundStyle(.secondary)
      }
    }.padding(20).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))

  }
}

@available(iOS 27, *)
private struct RawBatteryFieldsView: View {
  let fields: [RawBatteryField]
  let text: (String) -> String
  private var groups: [String: [RawBatteryField]] { Dictionary(grouping: fields, by: \.group) }
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(text("live_details_note")).font(.caption).foregroundStyle(.secondary)
      if fields.isEmpty { Text(text("live_details_empty")).font(.caption) }
      ForEach(groups.keys.sorted(), id: \.self) { group in
        DisclosureGroup {
          VStack(alignment: .leading, spacing: 12) {
            ForEach(Array((groups[group] ?? []).enumerated()), id: \.offset) { _, field in
              VStack(alignment: .leading, spacing: 4) {
                Text(field.label).font(.subheadline.weight(.medium)).textSelection(.enabled)
                Text(field.kind == "boolean" ? text(field.value == "true" ? "live_true" : "live_false")
                  : (field.kind == "data" ? "Base64 · " : "") + field.value)
                  .font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                  .fixedSize(horizontal: false, vertical: true)
                  .frame(maxWidth: .infinity, alignment: .leading)
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
