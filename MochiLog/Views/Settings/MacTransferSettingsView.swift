import AVFoundation
import SwiftUI

@available(iOS 27, *)
struct MacTransferSettingsView: View {
  @EnvironmentObject private var dataStore: DataStore
  @StateObject private var manager = MacTransferManager.shared
  @State private var showingScanner = false
  @State private var errorMessage: String?
  @State private var pendingPairingQR: String?
  @State private var secureCandidate: SecureMacPairingCandidate?
  @State private var enteredPairingCode = ""
  @State private var isPreparingPairing = false
  @State private var guidePlatform = 0
  @State private var manualHostAddress = ""
  @State private var unpairHostID: UUID?
  @AppStorage(PhysicalDeviceIdentityStore.manualLocalImportKey)
  private var tagManualImportsAsThisDevice = false
  private let macReleaseURL = URL(string: "https://github.com/MochiLog/MochiLog-Mac/releases")!
  private let windowsURL = URL(string: "https://github.com/MochiLog/MochiLog-Windows")!

  var body: some View {
    Form {
      Section {
        workflowDiagram
        DisclosureGroup(L10n.text("mt_flow_details", table: "MacTransfer")) {
          guidePoint("mt_guide_collect_title", "mt_guide_collect_detail",
            symbol: "macbook.and.iphone")
          guidePoint("mt_guide_import_title", "mt_guide_import_detail",
            symbol: "arrow.down.doc")
          guidePoint("mt_guide_without_title", "mt_guide_without_detail",
            symbol: "iphone")
        }
      } header: {
        Text(L10n.text("mt_guide_title", table: "MacTransfer"))
      } footer: {
        Text(L10n.text("mt_guide_footer", table: "MacTransfer"))
      }
      if isPreparingPairing {
        Section { ProgressView(L10n.text("mt_secure_pair_connecting", table: "MacTransfer")) }
      }
      Section {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: connectionSymbol)
            .font(.title3.weight(.semibold))
            .foregroundStyle(connectionColor)
            .frame(width: 32, height: 32)
          VStack(alignment: .leading, spacing: 5) {
            Text(L10n.text(connectionTitleKey, table: "MacTransfer"))
              .font(.headline)
              .accessibilityIdentifier("macTransfer.connectionPhase")
            Text(manager.status)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          Spacer(minLength: 0)
          if manager.isReceiving { ProgressView().controlSize(.small) }
        }
        .padding(.vertical, 4)
        if let lastContact = manager.lastAuthenticatedContactAt {
          LabeledContent(L10n.text("mt_103", table: "MacTransfer"),
            value: lastContact.formatted(.dateTime.locale(L10n.locale)
              .month().day().hour().minute()))
            .font(.subheadline)
            .accessibilityIdentifier("macTransfer.lastContact")
        }
        Button { manager.receiveNow() } label: {
          Label(L10n.text("mt_105", table: "MacTransfer"),
            systemImage: "arrow.down.doc")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(manager.pairing == nil || manager.isReceiving)
        .accessibilityIdentifier("macTransfer.receiveNow")
      } header: {
        Text(L10n.text("mt_093", table: "MacTransfer"))
      } footer: {
        Text(L10n.text("mt_102", table: "MacTransfer"))
      }
      Section(L10n.text("mt_048", table: "MacTransfer")) {
        Link(destination: macReleaseURL) {
          Label(L10n.text("mt_049", table: "MacTransfer"),
            systemImage: "arrow.down.app")
        }
        ShareLink(item: macReleaseURL) {
          Label(L10n.text("mt_050", table: "MacTransfer"),
            systemImage: "square.and.arrow.up")
        }
        Text(L10n.text("mt_051", table: "MacTransfer"))
          .font(.caption).foregroundStyle(.secondary)
        Link(destination: windowsURL) {
          Label(L10n.text("mt_windows_alpha", table: "MacTransfer"),
            systemImage: "desktopcomputer")
        }
      }
      Section(L10n.text("mt_052", table: "MacTransfer")) {
        Label(L10n.text("mt_053", table: "MacTransfer"),
          systemImage: "checkmark.circle")
        Label(L10n.text("mt_054", table: "MacTransfer"),
          systemImage: "wifi")
        Label(L10n.text("mt_055", table: "MacTransfer"),
          systemImage: "lock.open")
        Text(L10n.text("mt_089", table: "MacTransfer"))
          .font(.caption).foregroundStyle(.secondary)
      }
      Section {
        Toggle(L10n.text("mt_090", table: "MacTransfer"),
          isOn: Binding(
            get: { manager.allowsCellularTransfer },
            set: { manager.setAllowsCellularTransfer($0) }
          ))
          .accessibilityIdentifier("macTransfer.allowCellularData")
      } footer: {
        VStack(alignment: .leading, spacing: 8) {
          Text(L10n.text("mt_091", table: "MacTransfer"))
          Text(L10n.text("mt_092", table: "MacTransfer"))
        }
      }
      if manager.pairing != nil {
        Section {
          TextField(L10n.text("mt_manual_ip_placeholder", table: "MacTransfer"),
            text: $manualHostAddress)
            .keyboardType(.numbersAndPunctuation)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
          HStack {
            Button(L10n.text("mt_manual_ip_save", table: "MacTransfer")) {
              do { try manager.setManualHostAddress(manualHostAddress) }
              catch { errorMessage = error.localizedDescription }
            }
            Spacer()
            Button(L10n.text("mt_manual_ip_clear", table: "MacTransfer")) {
              do {
                try manager.setManualHostAddress(nil)
                manualHostAddress = ""
              } catch { errorMessage = error.localizedDescription }
            }
          }
        } header: {
          Text(L10n.text("mt_manual_ip_title", table: "MacTransfer"))
        } footer: {
          Text(L10n.text("mt_manual_ip_footer", table: "MacTransfer"))
        }
      }
      Section(L10n.text("mt_056", table: "MacTransfer")) {
        Picker(L10n.text("mt_platform", table: "MacTransfer"), selection: $guidePlatform) {
          Text("Mac").tag(0)
          Text("Windows").tag(1)
        }
        .pickerStyle(.segmented)
        if guidePlatform == 1 {
          Text(L10n.text("mt_win_requirements", table: "MacTransfer"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        pairingDiagram
        DisclosureGroup(L10n.text("mt_pair_details", table: "MacTransfer")) {
          if guidePlatform == 0 {
            step(1, L10n.text("mt_057", table: "MacTransfer"))
            step(2, L10n.text("mt_058", table: "MacTransfer"))
            step(3, L10n.text("mt_059", table: "MacTransfer"))
            step(4, L10n.text("mt_060", table: "MacTransfer"))
          } else {
            step(1, L10n.text("mt_win_step_1", table: "MacTransfer"))
            step(2, L10n.text("mt_win_step_2", table: "MacTransfer"))
            step(3, L10n.text("mt_win_step_3", table: "MacTransfer"))
            step(4, L10n.text("mt_win_step_4", table: "MacTransfer"))
          }
        }
      }
      Section {
        Toggle(L10n.text("mt_061", table: "MacTransfer"),
          isOn: $tagManualImportsAsThisDevice)
      } footer: {
        Text(L10n.text("mt_062", table: "MacTransfer"))
      }
      Section {
        if let pairing = manager.pairing {
          LabeledContent(L10n.text("mt_063", table: "MacTransfer"),
            value: pairing.physicalDeviceID.uuidString).font(.caption)
        }
        ForEach(manager.pairings, id: \.hostID) { paired in
          HStack {
            Button {
              manager.selectPairing(paired.hostID)
            } label: {
              HStack(spacing: 10) {
                Image(systemName: paired.platform == "windows" ? "desktopcomputer" : "macmini")
                  .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                  Text(paired.platform == "windows" ? "Windows" : "Mac")
                    .font(.subheadline.weight(.semibold))
                  Text(String(paired.hostID.uuidString.suffix(8)))
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                  .foregroundStyle(.green)
              }
            }.buttonStyle(.plain)
            Button(role: .destructive) { unpairHostID = paired.hostID } label: {
              Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L10n.text("mt_unpair_button", table: "MacTransfer"))
          }
        }
        if !manager.pendingRevocations.isEmpty {
          Text(L10n.text("mt_unpair_pending", table: "MacTransfer"))
            .font(.caption).foregroundStyle(.secondary)
        }
        Button {
          showingScanner = true
        } label: {
          Label(L10n.text("mt_065", table: "MacTransfer"),
            systemImage: "qrcode.viewfinder")
        }
      } header: {
        Text(L10n.text("mt_066", table: "MacTransfer"))
      } footer: {
        Text(L10n.text("mt_067", table: "MacTransfer"))
      }
      Section(L10n.text("mt_help_title", table: "MacTransfer")) {
        helpDiagram
        DisclosureGroup(L10n.text("mt_help_remote_title", table: "MacTransfer")) {
          Text(L10n.text("mt_help_remote_detail", table: "MacTransfer"))
            .font(.subheadline).foregroundStyle(.secondary)
        }
        NavigationLink {
          MacTransferSupportView()
        } label: {
          Label(L10n.text("mt_help_support", table: "MacTransfer"),
            systemImage: "questionmark.circle")
        }
      }
      Section(L10n.text("mt_022", table: "MacTransfer")) {
        NavigationLink {
          MacTransferDebugLogView()
        } label: {
          Label(L10n.text("mt_068", table: "MacTransfer"),
            systemImage: "list.bullet.rectangle")
        }
        NavigationLink {
          MacTransferSupportView()
        } label: {
          Label(L10n.text("mt_069", table: "MacTransfer"),
            systemImage: "envelope.badge")
        }
        Text(L10n.text("mt_070", table: "MacTransfer"))
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .confirmationDialog(L10n.text("mt_unpair_title", table: "MacTransfer"),
      isPresented: Binding(get: { unpairHostID != nil },
        set: { if !$0 { unpairHostID = nil } }), titleVisibility: .visible) {
      Button(L10n.text("mt_unpair_button", table: "MacTransfer"), role: .destructive) {
        if let unpairHostID {
          do { try manager.unpair(unpairHostID) }
          catch { errorMessage = error.localizedDescription }
        }
        unpairHostID = nil
      }
    } message: {
      Text(L10n.text("mt_unpair_detail", table: "MacTransfer"))
    }
    .formStyle(.grouped)
    .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 860 : .infinity)
    .frame(maxWidth: .infinity)
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationTitle(L10n.text("mt_071", table: "MacTransfer"))
    .sheet(isPresented: $showingScanner) {
      NavigationStack {
        MacPairingQRScanner { value in
          showingScanner = false
          handlePairingQR(value)
        }
        .navigationTitle(L10n.text("mt_072", table: "MacTransfer"))
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(L10n.text("mt_037", table: "MacTransfer")) { showingScanner = false }
          }
        }
      }
    }
    .alert(L10n.text("mt_073", table: "MacTransfer"),
      isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
      Button("OK", role: .cancel) { errorMessage = nil }
    } message: { Text(errorMessage ?? "") }
    .alert(L10n.text("mt_074", table: "MacTransfer"),
      isPresented: Binding(get: { pendingPairingQR != nil }, set: { if !$0 { pendingPairingQR = nil } })) {
      Button(L10n.text("mt_075", table: "MacTransfer")) {
        if let qr = pendingPairingQR {
          handlePairingQR(qr, relinkLocalRecords: true)
        }
        pendingPairingQR = nil
      }
      Button(L10n.text("mt_076", table: "MacTransfer"), role: .cancel) { pendingPairingQR = nil }
    } message: {
      Text(L10n.text("mt_077", table: "MacTransfer"))
    }
    .alert(L10n.text("mt_secure_pair_title", table: "MacTransfer"),
      isPresented: Binding(get: { secureCandidate != nil },
        set: { if !$0 { secureCandidate = nil } })) {
      TextField(L10n.text("mt_secure_pair_placeholder", table: "MacTransfer"),
        text: $enteredPairingCode)
        .keyboardType(.numberPad)
      Button(L10n.text("mt_secure_pair_confirm", table: "MacTransfer")) {
        guard let candidate = secureCandidate else { return }
        secureCandidate = nil
        Task {
          do { try await manager.confirmSecurePairing(candidate,
            enteredCode: enteredPairingCode, dataStore: dataStore) }
          catch { errorMessage = error.localizedDescription }
          enteredPairingCode = ""
        }
      }
      Button(L10n.text("mt_037", table: "MacTransfer"), role: .cancel) {
        secureCandidate = nil
        enteredPairingCode = ""
      }
    } message: {
      Text(L10n.text("mt_secure_pair_instruction", table: "MacTransfer"))
    }
    .onAppear {
      manualHostAddress = manager.pairing?.manualHostAddress ?? ""
      manager.start()
    }
    .onChange(of: manager.pairing?.hostID) { _, _ in
      manualHostAddress = manager.pairing?.manualHostAddress ?? ""
    }
  }

  private func handlePairingQR(_ value: String, relinkLocalRecords: Bool = false) {
    let isSecure = URLComponents(string: value)?.queryItems?.contains {
      $0.name == "v" && ["2", "3"].contains($0.value ?? "")
    } == true
    guard isSecure else {
      errorMessage = L10n.text("mt_secure_pair_update_mac", table: "MacTransfer")
      return
    }
    isPreparingPairing = true
    Task {
      defer { isPreparingPairing = false }
      do {
        secureCandidate = try await manager.prepareSecurePairing(from: value,
          dataStore: dataStore, relinkLocalRecords: relinkLocalRecords)
        enteredPairingCode = ""
      } catch TransferError.identityConflict { pendingPairingQR = value }
      catch { errorMessage = error.localizedDescription }
    }
  }

  private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

  @ViewBuilder private var workflowDiagram: some View {
    if isPad {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: 8) {
          horizontalFlowNode("desktopcomputer", "mt_guide_collect_title", tint: .green)
          horizontalArrow
          horizontalFlowNode("lock.shield", "mt_flow_secure", tint: .blue)
          horizontalArrow
          horizontalFlowNode("iphone.gen3", "mt_guide_import_title", tint: .orange)
        }
        verticalWorkflowDiagram
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
    } else {
      verticalWorkflowDiagram
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 8)
    }
  }

  private var verticalWorkflowDiagram: some View {
    VStack(alignment: .leading, spacing: 5) {
      verticalFlowNode("desktopcomputer", "mt_guide_collect_title", tint: .green)
      verticalArrow
      verticalFlowNode("lock.shield", "mt_flow_secure", tint: .blue)
      verticalArrow
      verticalFlowNode("iphone.gen3", "mt_guide_import_title", tint: .orange)
    }
  }

  private func horizontalFlowNode(_ symbol: String, _ titleKey: String,
    tint: Color) -> some View {
    VStack(spacing: 8) {
      Image(systemName: symbol)
        .font(.title2.weight(.medium)).foregroundStyle(tint)
        .frame(width: 52, height: 52)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
      Text(L10n.text(titleKey, table: "MacTransfer"))
        .font(.caption.weight(.semibold)).multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(width: 148, alignment: .top)
    .accessibilityElement(children: .combine)
  }

  private func verticalFlowNode(_ symbol: String, _ titleKey: String,
    tint: Color) -> some View {
    HStack(spacing: 14) {
      Image(systemName: symbol)
        .font(.title3.weight(.medium)).foregroundStyle(tint)
        .frame(width: 48, height: 48)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
      Text(L10n.text(titleKey, table: "MacTransfer"))
        .font(.subheadline.weight(.semibold))
      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .combine)
  }

  private var horizontalArrow: some View {
    Image(systemName: "arrow.right")
      .font(.caption.bold()).foregroundStyle(.tertiary)
      .frame(height: 52).accessibilityHidden(true)
  }

  private var verticalArrow: some View {
    Image(systemName: "arrow.down")
      .font(.caption.bold()).foregroundStyle(.tertiary)
      .frame(width: 48).accessibilityHidden(true)
  }

  @ViewBuilder private var pairingDiagram: some View {
    if isPad {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: 8) {
          pairingStage(1, "arrow.down.app", pairingInstallKey, horizontal: true)
          horizontalArrow
          pairingStage(2, "wifi", pairingOSKey, horizontal: true)
          horizontalArrow
          pairingStage(3, "qrcode", "mt_pair_qr_short", horizontal: true)
          horizontalArrow
          pairingStage(4, "checkmark.circle", "mt_pair_ready_short", horizontal: true)
        }
        verticalPairingDiagram
      }
      .frame(maxWidth: .infinity).padding(.vertical, 10)
    } else {
      verticalPairingDiagram
      .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
    }
  }

  private var verticalPairingDiagram: some View {
    VStack(alignment: .leading, spacing: 5) {
      pairingStage(1, "arrow.down.app", pairingInstallKey, horizontal: false)
      verticalArrow
      pairingStage(2, "wifi", pairingOSKey, horizontal: false)
      verticalArrow
      pairingStage(3, "qrcode", "mt_pair_qr_short", horizontal: false)
      verticalArrow
      pairingStage(4, "checkmark.circle", "mt_pair_ready_short", horizontal: false)
    }
  }

  private var pairingInstallKey: String {
    guidePlatform == 1 ? "mt_win_pair_install_short" : "mt_pair_install_short"
  }

  private var pairingOSKey: String {
    guidePlatform == 1 ? "mt_win_pair_os_short" : "mt_pair_os_short"
  }

  @ViewBuilder private func pairingStage(_ number: Int, _ symbol: String,
    _ titleKey: String, horizontal: Bool) -> some View {
    if horizontal {
      VStack(spacing: 8) {
        numberedSymbol(number, symbol)
        Text(L10n.text(titleKey, table: "MacTransfer"))
          .font(.caption.weight(.semibold)).multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(width: 148, alignment: .top)
      .accessibilityElement(children: .combine)
    } else {
      HStack(spacing: 14) {
        numberedSymbol(number, symbol)
        Text(L10n.text(titleKey, table: "MacTransfer"))
          .font(.subheadline.weight(.semibold))
        Spacer(minLength: 0)
      }
      .accessibilityElement(children: .combine)
    }
  }

  private func numberedSymbol(_ number: Int, _ symbol: String) -> some View {
    Image(systemName: symbol)
      .font(.title3).foregroundStyle(.green)
      .frame(width: 48, height: 48)
      .background(.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
      .overlay(alignment: .topTrailing) {
        Text("\(number)").font(.caption2.bold()).foregroundStyle(.white)
          .frame(width: 19, height: 19).background(.green, in: Circle())
          .offset(x: 6, y: -6)
      }
  }

  @ViewBuilder private var helpDiagram: some View {
    if isPad {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: 10) {
          helpStage(1, "doc.text.magnifyingglass", "mt_help_missing_title",
            "mt_help_missing_detail", horizontal: true)
          helpStage(2, "macbook", "mt_help_collect_title", "mt_help_collect_detail",
            horizontal: true)
          helpStage(3, "iphone.gen3", "mt_help_import_title", "mt_help_import_detail",
            horizontal: true)
        }
        verticalHelpDiagram
      }
      .padding(.vertical, 8)
    } else {
      verticalHelpDiagram
      .padding(.vertical, 8)
    }
  }

  private var verticalHelpDiagram: some View {
    VStack(alignment: .leading, spacing: 6) {
      helpStage(1, "doc.text.magnifyingglass", "mt_help_missing_title",
        "mt_help_missing_detail")
      helpStage(2, "macbook", "mt_help_collect_title", "mt_help_collect_detail")
      helpStage(3, "iphone.gen3", "mt_help_import_title", "mt_help_import_detail")
    }
  }

  private func helpStage(_ number: Int, _ symbol: String,
    _ titleKey: String, _ detailKey: String, horizontal: Bool = false) -> some View {
    DisclosureGroup {
      Text(L10n.text(detailKey, table: "MacTransfer"))
        .font(.caption).foregroundStyle(.secondary)
        .padding(.top, 6)
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Image(systemName: symbol).font(.title3).foregroundStyle(.green)
          Spacer(minLength: 4)
          Text("\(number)").font(.caption2.bold()).foregroundStyle(.white)
            .frame(width: 22, height: 22).background(.green, in: Circle())
        }
        Text(L10n.text(titleKey, table: "MacTransfer"))
          .font(.subheadline.weight(.semibold))
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(minWidth: horizontal ? 170 : nil, maxWidth: .infinity,
      alignment: .topLeading)
    .padding(12)
    .background(Color.accentColor.opacity(0.06),
      in: RoundedRectangle(cornerRadius: 14))
  }

  private func step(_ number: Int, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Text("\(number)").font(.caption.bold()).foregroundStyle(.white)
        .frame(width: 24, height: 24).background(.green, in: Circle())
      Text(text).fixedSize(horizontal: false, vertical: true)
    }.padding(.vertical, 4)
  }

  private func guidePoint(_ titleKey: String, _ detailKey: String,
    symbol: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol)
        .font(.body.weight(.semibold))
        .foregroundStyle(.green)
        .frame(width: 26)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 3) {
        Text(L10n.text(titleKey, table: "MacTransfer")).font(.subheadline.weight(.semibold))
        Text(L10n.text(detailKey, table: "MacTransfer"))
          .font(.subheadline).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }.padding(.vertical, 4)
  }

  private var connectionTitleKey: String {
    switch manager.connectionPhase {
    case .needsPairing: "mt_094"
    case .checkingNetwork: "mt_095"
    case .offline: "mt_096"
    case .waitingForWiFi: "mt_097"
    case .searching: "mt_098"
    case .connecting: "mt_099"
    case .receiving: "mt_100"
    case .available: "mt_101"
    case .retrying: "mt_104"
    }
  }

  private var connectionSymbol: String {
    switch manager.connectionPhase {
    case .needsPairing: "link.badge.plus"
    case .checkingNetwork, .searching, .connecting, .retrying: "arrow.triangle.2.circlepath"
    case .offline: "wifi.slash"
    case .waitingForWiFi: "wifi.exclamationmark"
    case .receiving: "arrow.down.doc"
    case .available: "checkmark.circle.fill"
    }
  }

  private var connectionColor: Color {
    switch manager.connectionPhase {
    case .available: .green
    case .offline, .waitingForWiFi, .retrying: .orange
    default: .accentColor
    }
  }
}

@available(iOS 27, *)
private struct MacPairingQRScanner: UIViewControllerRepresentable {
  let onCode: (String) -> Void
  func makeUIViewController(context: Context) -> ScannerController {
    let controller = ScannerController()
    controller.onCode = onCode
    return controller
  }
  func updateUIViewController(_ controller: ScannerController, context: Context) {}
}

@available(iOS 27, *)
private final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
  var onCode: ((String) -> Void)?
  private let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "net.ryuya-dev.MochiLog.qr-scanner")
  private var previewLayer: AVCaptureVideoPreviewLayer?
  private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
  private var rotationObservation: NSKeyValueObservation?
  private var delivered = false

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
      for: .video, position: .back),
      let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else { return }
    session.addInput(input)
    let output = AVCaptureMetadataOutput()
    guard session.canAddOutput(output) else { return }
    session.addOutput(output)
    output.setMetadataObjectsDelegate(self, queue: .main)
    output.metadataObjectTypes = [.qr]
    let preview = AVCaptureVideoPreviewLayer(session: session)
    preview.videoGravity = .resizeAspectFill
    previewLayer = preview
    view.layer.addSublayer(preview)
    let coordinator = AVCaptureDevice.RotationCoordinator(device: camera, previewLayer: preview)
    rotationCoordinator = coordinator
    rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview,
      options: [.initial, .new]) { [weak self] coordinator, _ in
      guard let connection = self?.previewLayer?.connection else { return }
      let angle = coordinator.videoRotationAngleForHorizonLevelPreview
      if connection.isVideoRotationAngleSupported(angle) {
        connection.videoRotationAngle = angle
      }
    }
    sessionQueue.async { self.session.startRunning() }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    previewLayer?.frame = view.bounds
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    sessionQueue.async { self.session.stopRunning() }
  }

  func metadataOutput(_ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
    guard !delivered,
      let code = metadataObjects.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first
    else { return }
    delivered = true
    onCode?(code)
  }
}
