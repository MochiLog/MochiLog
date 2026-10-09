import SwiftUI
import UniformTypeIdentifiers

@available(iOS 17, *)
struct AutomaticCollectionSettingsView: View {
  @ObservedObject private var settings = AppSettings.shared
  private func text(_ key: String) -> String { L10n.text(key, table: "MacTransfer") }
  var body: some View {
    Form {
      Section {
        HStack(spacing: 18) {
          Image(systemName: "laptopcomputer").font(.largeTitle).foregroundStyle(.green)
          Image(systemName: "arrow.right").foregroundStyle(.secondary)
          Image(systemName: "iphone").font(.largeTitle).foregroundStyle(.green)
          Image(systemName: "chart.xyaxis.line").font(.largeTitle).foregroundStyle(.green)
        }.frame(maxWidth: .infinity).padding(.vertical, 12).accessibilityHidden(true)
        Text(text("auto_collection_intro")).foregroundStyle(.secondary)
      }
      if #available(iOS 27, *) {
      Section {
        Toggle(text("auto_pc_enable"), isOn: $settings.pcAutomaticCollectionEnabled)
          .accessibilityIdentifier("autoCollection.pcToggle")
        NavigationLink { MacTransferSettingsView() } label: {
          Label(text("mt_071"), systemImage: "laptopcomputer.and.iphone")
        }.accessibilityIdentifier("settings.macTransfer")
        Text(text("auto_pc_note")).font(.caption).foregroundStyle(.secondary)
      }
      }
      Section {
        Toggle(text("auto_local_enable"), isOn: $settings.localAutomaticCollectionEnabled)
          .accessibilityIdentifier("autoCollection.localToggle")
        NavigationLink { LocalDiagnosticsSettingsView() } label: {
          Label(text("local_title"), systemImage: "iphone.radiowaves.left.and.right")
        }.accessibilityIdentifier("autoCollection.localSettings")
        Text(text("auto_local_note")).font(.caption).foregroundStyle(.secondary)
      }
    }.navigationTitle(text("auto_collection_title"))
  }
}

@available(iOS 17, *)
struct LocalDiagnosticsSettingsView: View {
  @ObservedObject private var settings = AppSettings.shared
  @ObservedObject private var manager = LocalDiagnosticsManager.shared
  @ObservedObject private var transfer = MacTransferManager.shared
  @State private var importing = false
  @State private var expectedUDID = ""
  @State private var errorMessage: String?
  @State private var forgetConfirmation = false
  private func text(_ key: String) -> String { L10n.text(key, table: "MacTransfer") }
  var body: some View {
    Form {
      Section {
        HStack(spacing: 20) {
          Image(systemName: "iphone.radiowaves.left.and.right").font(.largeTitle).foregroundStyle(.green)
          Image(systemName: "arrow.triangle.2.circlepath").font(.title).foregroundStyle(.green)
          Image(systemName: "doc.text.magnifyingglass").font(.largeTitle).foregroundStyle(.green)
        }.frame(maxWidth: .infinity).padding(.vertical, 12).accessibilityHidden(true)
        Text(text("local_intro"))
        Label(text(manager.configured ? "local_configured" : "local_setup_needed"),
          systemImage: manager.configured ? "checkmark.shield.fill" : "key.fill")
          .foregroundStyle(manager.configured ? .green : .secondary)
        if manager.installingPairing { ProgressView(text("local_working")) }
        if !manager.message.isEmpty { Text(manager.message).font(.callout).textSelection(.enabled) }
      }
      Section(text("local_pairing_step")) {
        Text(text("local_pairing_note")).font(.callout)
        Label(text("local_pairing_refresh_note"), systemImage: "arrow.clockwise.circle")
          .font(.caption).foregroundStyle(.secondary)
          .accessibilityIdentifier("localPairing.refreshNote")
        if #available(iOS 27, *) {
          LocalDevicePairingControls()
        } else {
          Label(text("local_pair_import_required"), systemImage: "doc.badge.arrow.up").font(.callout)
            .accessibilityIdentifier("localPairing.importRequired")
        }
        if #available(iOS 27, *) {
        ForEach(transfer.pairings, id: \.hostID) { pair in
          Button { Task { await manager.reuse(pair) } } label: {
            Label(text("local_reuse") + " · " + (pair.platform == "windows" ? "Windows" : "Mac"), systemImage: "key.horizontal")
          }.disabled(manager.busy || manager.pairingActive)
        }
        }
        DisclosureGroup(text("local_import_title")) {
          Text(text("local_direct_import_note")).font(.caption).foregroundStyle(.secondary)
          Text(text("local_import_note")).font(.caption).foregroundStyle(.secondary)
          TextField(text("local_udid"), text: $expectedUDID).textInputAutocapitalization(.never).autocorrectionDisabled()
          Button(text("local_import_button")) { importing = true }.disabled(expectedUDID.isEmpty || manager.busy || manager.pairingActive)
          Link("idevice_pair", destination: URL(string: "https://github.com/jkcoxson/idevice_pair/releases")!)
        }
      }
      Section(text("local_vpn_step")) {
        Text(text("local_vpn_note"))
        Link(text("local_get_vpn"), destination: URL(string: "https://apps.apple.com/app/id6755608044")!)
        Link(text("local_open_vpn"), destination: URL(string: "localdevvpn://")!)
        TextField(text("local_address"), text: $manager.address).keyboardType(.numbersAndPunctuation)
          .textInputAutocapitalization(.never).autocorrectionDisabled()
        Text(text("local_vpn_caution")).font(.caption).foregroundStyle(.secondary)
      }
      Section(text("live_title")) {
        Toggle(text("local_live_enable"), isOn: $settings.liveBatteryEnabled)
          .accessibilityIdentifier("localBattery.enable")
        Text(text("local_live_note")).font(.caption).foregroundStyle(.secondary)
        Button { Task { await manager.receiveBatteryNow() } } label: {
          Label(text("live_receive"), systemImage: "battery.100percent")
        }.disabled(!manager.configured || manager.batteryBusy || manager.pairingActive || !settings.liveBatteryEnabled || !settings.localAutomaticCollectionEnabled)
          .accessibilityIdentifier("localBattery.receive")
        if manager.batteryBusy { ProgressView() }
        if let reading = manager.reading {
          LabeledContent(text("live_last")) { Text(reading.acquiredAt, format: .dateTime.month().day().hour().minute().second()) }
        }
        NavigationLink { LiveBatteryView(embeddedInSettings: true) } label: { Label(text("live_title"), systemImage: "chart.bar") }
          .disabled(!settings.liveBatteryEnabled).accessibilityIdentifier("localBattery.values")
      }
      Section {
        Button { Task { await manager.collectNow() } } label: {
          Label(text("local_collect_now"), systemImage: "arrow.down.doc")
        }.disabled(!manager.configured || manager.busy || manager.pairingActive || !AppSettings.shared.localAutomaticCollectionEnabled)
        if manager.busy { ProgressView(text("local_working")) }
        Text(text("local_limits")).font(.caption).foregroundStyle(.secondary)
        Button(text("local_forget"), role: .destructive) { forgetConfirmation = true }.disabled(!manager.configured || manager.pairingActive)
      }
      Section {
        NavigationLink { MacTransferDebugLogView() } label: { Label(text("mt_068"), systemImage: "ladybug") }
      }
    }.accessibilityIdentifier("localDiagnostics.form")
      .navigationTitle(text("local_title"))
      .alert(text("local_forget"), isPresented: $forgetConfirmation) {
        Button(text("local_forget"), role: .destructive) { manager.forget() }
        Button(L10n.text("cancel", table: "Common"), role: .cancel) {}
      } message: { Text(text("local_forget_note")) }
      .alert(text("local_setup_needed"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
        Button(L10n.text("ok", table: "Common")) { errorMessage = nil }
      } message: { Text(errorMessage ?? "") }
      .fileImporter(isPresented: $importing, allowedContentTypes: [.propertyList, .data]) { result in
        do {
          let url = try result.get(); let access = url.startAccessingSecurityScopedResource()
          defer { if access { url.stopAccessingSecurityScopedResource() } }
          guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 65536 else { throw LocalDiagnosticsTransport.Failure.invalid }
          try manager.importPairing(Data(contentsOf: url), expectedUDID: expectedUDID)
        } catch { errorMessage = text("local_import_failed") }
      }
  }
}

/// OS-initiated trust is deliberately unavailable on iOS 17–26.
@available(iOS 27, *)
private struct LocalDevicePairingControls: View {
  @ObservedObject private var manager = LocalDiagnosticsManager.shared
  @ObservedObject private var pairing = LocalDevicePairing.shared
  @State private var pairConfirmation = false
  private func text(_ key: String) -> String { L10n.text(key, table: "MacTransfer") }
  var body: some View {
        VStack(alignment: .leading, spacing: 12) {
          Label(text("local_pair_title"), systemImage: "iphone.and.arrow.forward").font(.headline)
          VStack(alignment: .leading, spacing: 8) {
            Label(text("local_pair_developer_required"), systemImage: "exclamationmark.shield.fill")
              .font(.headline).foregroundStyle(.orange)
              .accessibilityIdentifier("localPairing.developerRequired")
            Text(text("local_pair_developer_steps")).font(.callout)
            Link(text("local_pair_developer_guide"), destination: URL(string:
              "https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device")!)
          }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
          Text(text("local_pair_instructions")).font(.callout)
          if !pairing.hostName.isEmpty {
            Text(pairing.hostName).font(.caption.monospaced()).textSelection(.enabled)
              .accessibilityIdentifier("localPairing.hostName")
          }
          if pairing.active {
            ProgressView(text(pairing.statusKey))
            if !pairing.pin.isEmpty {
              Text(text("local_pair_code")).font(.caption)
              Text(pairing.pin).font(.system(.largeTitle, design: .monospaced).bold()).textSelection(.enabled)
            }
            if pairing.shortBackground { Text(text("local_pair_short_background")).font(.caption).foregroundStyle(.orange) }
            Button(L10n.text("cancel", table: "Common"), role: .cancel) { pairing.cancel() }
              .accessibilityIdentifier("localPairing.cancel")
          } else {
            Button {
              pairConfirmation = true
            } label: { Label(text("local_pair_start"), systemImage: "key.horizontal.fill") }
              .disabled(manager.busy).accessibilityIdentifier("localPairing.start")
            if pairing.statusKey != "local_pair_ready" { Text(text(pairing.statusKey)).font(.callout) }
          }
        }.padding(.vertical, 8)
          // Form rows must not activate the guide Link and pairing Button together.
          .buttonStyle(.borderless)

      .alert(text("local_pair_developer_required"), isPresented: $pairConfirmation) {
        Button(text("local_pair_developer_confirm")) { pairing.start() }
        Button(L10n.text("cancel", table: "Common"), role: .cancel) {}
      } message: {
        Text(text("local_pair_developer_steps") +
          (manager.configured ? "\n\n" + text("local_pair_replace_note") : ""))
      }
  }
}
