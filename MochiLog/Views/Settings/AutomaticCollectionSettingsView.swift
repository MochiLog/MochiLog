import SwiftUI
import UniformTypeIdentifiers

@available(iOS 27, *)
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
      Section {
        Toggle(text("auto_pc_enable"), isOn: $settings.pcAutomaticCollectionEnabled)
          .accessibilityIdentifier("autoCollection.pcToggle")
        NavigationLink { MacTransferSettingsView() } label: {
          Label(text("mt_071"), systemImage: "laptopcomputer.and.iphone")
        }.accessibilityIdentifier("settings.macTransfer")
        Text(text("auto_pc_note")).font(.caption).foregroundStyle(.secondary)
      }
      Section {
        Toggle(text("auto_local_enable"), isOn: $settings.localAutomaticCollectionEnabled)
          .accessibilityIdentifier("autoCollection.localToggle")
        NavigationLink { LocalDiagnosticsSettingsView() } label: {
          Label(text("local_title"), systemImage: "iphone.radiowaves.left.and.right")
        }
        Text(text("auto_local_note")).font(.caption).foregroundStyle(.secondary)
      }
    }.navigationTitle(text("auto_collection_title"))
  }
}

@available(iOS 27, *)
struct LocalDiagnosticsSettingsView: View {
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
        if !manager.message.isEmpty { Text(manager.message).font(.callout).textSelection(.enabled) }
      }
      Section(text("local_pairing_step")) {
        Text(text("local_pairing_note")).font(.callout)
        ForEach(transfer.pairings, id: \.hostID) { pair in
          Button { Task { await manager.reuse(pair) } } label: {
            Label(text("local_reuse") + " · " + (pair.platform == "windows" ? "Windows" : "Mac"), systemImage: "key.horizontal")
          }.disabled(manager.busy)
        }
        if transfer.pairings.isEmpty {
          NavigationLink { MacTransferSettingsView() } label: { Label(text("mt_071"), systemImage: "laptopcomputer.and.iphone") }
        }
        DisclosureGroup(text("local_import_title")) {
          Text(text("local_import_note")).font(.caption).foregroundStyle(.secondary)
          TextField(text("local_udid"), text: $expectedUDID).textInputAutocapitalization(.never).autocorrectionDisabled()
          Button(text("local_import_button")) { importing = true }.disabled(expectedUDID.isEmpty || manager.busy)
          Link("idevice_pair", destination: URL(string: "https://github.com/jkcoxson/idevice_pair/releases")!)
        }
      }
      Section(text("local_vpn_step")) {
        Text(text("local_vpn_note"))
        Link("LocalDevVPN", destination: URL(string: "https://apps.apple.com/app/id6755608044")!)
        Link(text("local_open_vpn"), destination: URL(string: "localdevvpn://")!)
        TextField(text("local_address"), text: $manager.address).keyboardType(.numbersAndPunctuation)
          .textInputAutocapitalization(.never).autocorrectionDisabled()
        Text(text("local_vpn_caution")).font(.caption).foregroundStyle(.secondary)
      }
      Section {
        Button { Task { await manager.collectNow() } } label: {
          Label(text("local_collect_now"), systemImage: "arrow.down.doc")
        }.disabled(!manager.configured || manager.busy || !AppSettings.shared.localAutomaticCollectionEnabled)
        if manager.busy { ProgressView(text("local_working")) }
        Text(text("local_limits")).font(.caption).foregroundStyle(.secondary)
        Button(text("local_forget"), role: .destructive) { forgetConfirmation = true }.disabled(!manager.configured)
      }
      Section {
        NavigationLink { MacTransferDebugLogView() } label: { Label(text("mt_068"), systemImage: "ladybug") }
      }
    }.navigationTitle(text("local_title"))
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
