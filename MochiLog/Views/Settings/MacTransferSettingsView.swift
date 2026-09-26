import AVFoundation
import SwiftUI

@available(iOS 27, *)
struct MacTransferSettingsView: View {
  @EnvironmentObject private var dataStore: DataStore
  @StateObject private var manager = MacTransferManager.shared
  @State private var showingScanner = false
  @State private var errorMessage: String?
  @State private var pendingPairingQR: String?
  @AppStorage(PhysicalDeviceIdentityStore.manualLocalImportKey)
  private var tagManualImportsAsThisDevice = false
  private let macReleaseURL = URL(string: "https://github.com/MochiLog/MochiLog-Mac/releases")!

  var body: some View {
    Form {
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
      }
      Section(L10n.text("mt_052", table: "MacTransfer")) {
        Label(L10n.text("mt_053", table: "MacTransfer"),
          systemImage: "checkmark.circle")
        Label(L10n.text("mt_054", table: "MacTransfer"),
          systemImage: "wifi")
        Label(L10n.text("mt_055", table: "MacTransfer"),
          systemImage: "lock.open")
      }
      Section(L10n.text("mt_056", table: "MacTransfer")) {
        step(1, L10n.text("mt_057", table: "MacTransfer"))
        step(2, L10n.text("mt_058", table: "MacTransfer"))
        step(3, L10n.text("mt_059", table: "MacTransfer"))
        step(4, L10n.text("mt_060", table: "MacTransfer"))
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
          Button(L10n.text("mt_064", table: "MacTransfer")) { manager.stop(); manager.start() }
        }
        Button {
          showingScanner = true
        } label: {
          Label(L10n.text("mt_065", table: "MacTransfer"),
            systemImage: "qrcode.viewfinder")
        }
        Text(manager.status).foregroundStyle(.secondary)
      } header: {
        Text(L10n.text("mt_066", table: "MacTransfer"))
      } footer: {
        Text(L10n.text("mt_067", table: "MacTransfer"))
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
    .formStyle(.grouped)
    .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 860 : .infinity)
    .frame(maxWidth: .infinity)
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationTitle(L10n.text("mt_071", table: "MacTransfer"))
    .sheet(isPresented: $showingScanner) {
      NavigationStack {
        MacPairingQRScanner { value in
          showingScanner = false
          do { try manager.pair(from: value, dataStore: dataStore) }
          catch TransferError.identityConflict { pendingPairingQR = value }
          catch { errorMessage = error.localizedDescription }
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
          do { try manager.pair(from: qr, dataStore: dataStore, relinkLocalRecords: true) }
          catch { errorMessage = error.localizedDescription }
        }
        pendingPairingQR = nil
      }
      Button(L10n.text("mt_076", table: "MacTransfer"), role: .cancel) { pendingPairingQR = nil }
    } message: {
      Text(L10n.text("mt_077", table: "MacTransfer"))
    }
    .onAppear { manager.start() }
  }

  private func step(_ number: Int, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Text("\(number)").font(.caption.bold()).foregroundStyle(.white)
        .frame(width: 24, height: 24).background(.green, in: Circle())
      Text(text).fixedSize(horizontal: false, vertical: true)
    }.padding(.vertical, 4)
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
