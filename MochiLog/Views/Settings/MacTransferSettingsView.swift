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
  private var japanese: Bool { Locale.preferredLanguages.first?.hasPrefix("ja") == true }

  var body: some View {
    Form {
      Section(japanese ? "ベータ版の利用条件" : "Beta requirements") {
        Label(japanese ? "iOS / iPadOS 27 と macOS 27 以降" : "iOS / iPadOS 27 and macOS 27 or later",
          systemImage: "checkmark.circle")
        Label(japanese ? "同じWi-Fi、Bluetoothがオン" : "Same Wi-Fi, Bluetooth enabled",
          systemImage: "wifi")
        Label(japanese ? "ログ収集は端末のロック解除中のみ可能" : "Log collection works only while unlocked",
          systemImage: "lock.open")
      }
      Section(japanese ? "ペアリングの手順" : "Pairing steps") {
        step(1, japanese
          ? "MacにMochiLog MacのDMGをインストールして開きます。PythonやXcodeの追加インストールは不要です。"
          : "Install and open the MochiLog Mac DMG. No Python or Xcode installation is needed.")
        step(2, japanese
          ? "初回だけMacアプリで『OSペアリングを開始』を押し、この端末でデベロッパモードをオンにします。『設定 → デベロッパ → ペアリング済みMac』からMacを選び、Macに表示された6桁コードを入力します。完了後はデベロッパモードをオフに戻せます。"
          : "For first setup, tap Start OS pairing in the Mac app, enable Developer Mode here, open Settings → Developer → Paired Macs, choose the Mac, and enter its six-digit code. Developer Mode can be turned off afterwards.")
        step(3, japanese
          ? "Macアプリで端末を選び、MochiLogペアリングを作成します。表示されたQRコードを下のボタンで読み取ります。QRは選択した端末専用です。"
          : "Select this device in the Mac app and create MochiLog pairing. Scan its QR below. The QR is specific to this device.")
        step(4, japanese
          ? "Macアプリを起動しておくとログを定期収集します。このアプリを開くとWi-Fiで受信・解析します。"
          : "Keep the Mac app open for periodic collection. Open this app to receive and import over Wi-Fi.")
      }
      Section {
        Toggle(japanese ? "同じ機種の手動ログをこの端末として記録" : "Tag same-model manual logs as this device",
          isOn: $tagManualImportsAsThisDevice)
      } footer: {
        Text(japanese
          ? "この端末の『設定 → 解析データ』から共有する場合だけオンにしてください。同じ機種の別個体から受け取ったファイルも区別できなくなるため、その場合はオフにします。Macからの転送はこの設定に関係なく個体IDで区別します。"
          : "Enable only when sharing logs from this device's Settings → Analytics Data. Turn it off for files from another physical device of the same model. Mac transfers always use their paired device ID independently.")
      }
      Section {
        if let pairing = manager.pairing {
          LabeledContent(japanese ? "個体ID" : "Device ID",
            value: pairing.physicalDeviceID.uuidString).font(.caption)
          Button(japanese ? "Macを再検索" : "Find Mac again") { manager.stop(); manager.start() }
        }
        Button {
          showingScanner = true
        } label: {
          Label(japanese ? "MacのQRコードを読み取る" : "Scan the Mac's QR code",
            systemImage: "qrcode.viewfinder")
        }
        Text(manager.status).foregroundStyle(.secondary)
      } header: {
        Text(japanese ? "接続状態" : "Connection")
      } footer: {
        Text(japanese
          ? "再インストール後は同じMacで再ペアリングすると同じ個体IDを受け取れます。iCloud同期がオフの間の記録は、アプリ削除時に復元できません。既存のIDなし記録は自動で結合しません。"
          : "After reinstalling, pair with the same Mac to recover the same device ID. Records stored only locally cannot be recovered after deleting the app. Older records without IDs are not merged automatically.")
      }
    }
    .navigationTitle(japanese ? "Mac連携（ベータ）" : "Mac transfer (Beta)")
    .sheet(isPresented: $showingScanner) {
      NavigationStack {
        MacPairingQRScanner { value in
          showingScanner = false
          do { try manager.pair(from: value, dataStore: dataStore) }
          catch TransferError.identityConflict { pendingPairingQR = value }
          catch { errorMessage = error.localizedDescription }
        }
        .navigationTitle(japanese ? "QRを読み取る" : "Scan QR")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(japanese ? "閉じる" : "Close") { showingScanner = false }
          }
        }
      }
    }
    .alert(japanese ? "ペアリングできません" : "Pairing failed",
      isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
      Button("OK", role: .cancel) { errorMessage = nil }
    } message: { Text(errorMessage ?? "") }
    .alert(japanese ? "個体IDを引き継ぎますか？" : "Relink this device's records?",
      isPresented: Binding(get: { pendingPairingQR != nil }, set: { if !$0 { pendingPairingQR = nil } })) {
      Button(japanese ? "引き継ぐ" : "Relink") {
        if let qr = pendingPairingQR {
          do { try manager.pair(from: qr, dataStore: dataStore, relinkLocalRecords: true) }
          catch { errorMessage = error.localizedDescription }
        }
        pendingPairingQR = nil
      }
      Button(japanese ? "キャンセル" : "Cancel", role: .cancel) { pendingPairingQR = nil }
    } message: {
      Text(japanese
        ? "この端末に付けた以前の個体IDをMacのIDに変更します。IDのない旧記録や他の機種の記録は変更しません。"
        : "Only this device's records with its previous ID will receive the Mac's ID. Older records without an ID and other models are unchanged.")
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
  private var delivered = false

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    guard let camera = AVCaptureDevice.default(for: .video),
      let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else { return }
    session.addInput(input)
    let output = AVCaptureMetadataOutput()
    guard session.canAddOutput(output) else { return }
    session.addOutput(output)
    output.setMetadataObjectsDelegate(self, queue: .main)
    output.metadataObjectTypes = [.qr]
    let preview = AVCaptureVideoPreviewLayer(session: session)
    preview.videoGravity = .resizeAspectFill
    preview.frame = view.bounds
    view.layer.addSublayer(preview)
    DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    DispatchQueue.global(qos: .userInitiated).async { self.session.stopRunning() }
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
