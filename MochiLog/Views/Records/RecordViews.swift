import Foundation
// RecordViews.swift
// 一覧行ビューと詳細ビュー
import SwiftUI

private func simCapacityProfile(for record: BatteryRecord) -> String? {
  guard let variant = DeviceProfileStore.shared.capacityVariant(
    for: record.deviceName, productSku: record.productSku) else { return nil }
  switch variant.configuration {
  case .esim:
    return L10n.string("sim_profile_esim", table: "Records")
  case .physicalSIM:
    return L10n.string("sim_profile_physical_hk", table: "Records")
  }
}

// MARK: - ⓘボタン付きLabeledContentラッパー
/// ラベルの横にⓘボタンを表示し、タップでポップオーバーを表示するコンポーネント
/// iPad / iPhone どちらも吹き出しスタイルで表示（UIKitブリッジ使用）
struct InfoLabeledContent<V: View>: View {
  let label: String
  let hint: String
  let valueContent: V

  @AppStorage("showRecordInfoButtons") private var showInfoButtons = false
  @State private var isShowingInfo = false

  init(_ label: String, hint: String, @ViewBuilder value: () -> V) {
    self.label = label
    self.hint = hint
    self.valueContent = value()
  }

  var body: some View {
    LabeledContent {
      valueContent
    } label: {
      HStack(spacing: 4) {
        Text(label)
        if showInfoButtons {
        Button {
          isShowingInfo = true
        } label: {
          // 当たり判定を広げる（行の高さを太らせない範囲で）
          Image(systemName: "info.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .background {
          // UIKitポップオーバーのアンカービューを背面に配置してタップを妨げないようにする
          InfoPopoverAnchor(isPresented: $isShowingInfo, title: label, hint: hint)
            .allowsHitTesting(false)
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier("record.info.\(label)")
        }
      }
    }
  }
}

/// Stringバリューを直接渡せるオーバーロード
extension InfoLabeledContent where V == Text {
  init(_ label: String, hint: String, value: String) {
    self.init(label, hint: hint) { Text(value) }
  }
}

// MARK: - UIKitブリッジポップオーバーアンカー
/// UIPopoverPresentationControllerを使ってiPhone/iPad両方で吹き出しポップオーバーを表示する
private struct InfoPopoverAnchor: UIViewRepresentable {
  @Binding var isPresented: Bool
  let title: String
  let hint: String

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.backgroundColor = .clear
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    if isPresented && !context.coordinator.isShowing {
      showPopover(from: uiView, context: context)
    } else if !isPresented && context.coordinator.isShowing {
      context.coordinator.dismissPopover()
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(isPresented: $isPresented)
  }

  private func showPopover(from uiView: UIView, context: Context) {
    guard let windowScene = uiView.window?.windowScene,
      let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
    else { return }

    // 最前面のViewControllerを取得
    var topVC = root
    while let presented = topVC.presentedViewController {
      topVC = presented
    }

    // ポップオーバーコンテンツのビュー
    let contentView = InfoPopoverContent(title: title, hint: hint)
    let hostingVC = UIHostingController(rootView: contentView)
    hostingVC.modalPresentationStyle = .popover

    // 幅300でレイアウトしたときの自然な高さを計算してサイズを決定
    hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
    let fittingSize = hostingVC.view.systemLayoutSizeFitting(
      CGSize(width: 300, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    )
    // 画面の半分を超えないようキャップする
    let maxHeight = max(1, topVC.view.safeAreaLayoutGuide.layoutFrame.height * 0.5)
    hostingVC.preferredContentSize = CGSize(width: 300, height: min(fittingSize.height, maxHeight))

    if let pop = hostingVC.popoverPresentationController {
      pop.sourceView = uiView
      pop.sourceRect = uiView.bounds
      pop.permittedArrowDirections = [.up, .down, .left, .right]
      pop.delegate = context.coordinator
    }

    context.coordinator.isShowing = true
    context.coordinator.presentedVC = hostingVC
    topVC.present(hostingVC, animated: true)
  }

  // MARK: - Coordinator
  class Coordinator: NSObject, UIPopoverPresentationControllerDelegate {
    @Binding var isPresented: Bool
    var isShowing = false
    weak var presentedVC: UIViewController?

    init(isPresented: Binding<Bool>) {
      self._isPresented = isPresented
    }

    /// iPhoneでもシートに変換せずポップオーバーのまま表示する
    func adaptivePresentationStyle(
      for controller: UIPresentationController,
      traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
      return .none
    }

    /// ドラッグやタップ外で閉じたとき状態を同期
    func popoverPresentationControllerDidDismissPopover(
      _ popoverPresentationController: UIPopoverPresentationController
    ) {
      isPresented = false
      isShowing = false
    }

    func dismissPopover() {
      presentedVC?.dismiss(animated: true) { [weak self] in
        self?.isShowing = false
      }
    }
  }
}

// MARK: - ポップオーバー内コンテンツ
/// ポップオーバー吹き出し内に表示するビュー（UIKitのUIHostingControllerで表示）
private struct InfoPopoverContent: View {
  let title: String
  let hint: String

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // ── ヘッダー ──
      HStack(alignment: .center, spacing: 8) {
        Image(systemName: "info.circle.fill")
          .font(.callout)
          .foregroundStyle(.tint)
        Text(title)
          .font(.subheadline)
          .fontWeight(.semibold)
          .foregroundStyle(.primary)
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 10)

      Divider()

      // ── 説明文 ──
      Text(hint)
        .font(.callout)
        .foregroundStyle(.primary)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
    }
    .frame(width: 300)
  }
}

struct RecordRowView: View {
  let record: BatteryRecord
  @StateObject private var appSettings = AppSettings.shared

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    if horizontalSizeClass == .regular {
      existingRow
    } else {
      phoneRow
    }
  }

  private var phoneRow: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .center, spacing: 20) {
        phoneRecordLabel
        Spacer(minLength: 12)
        phoneHealthLabel
      }
      VStack(alignment: .leading, spacing: 10) {
        phoneRecordLabel
        phoneHealthLabel
      }
    }
    .padding(.vertical, 16)
    .accessibilityElement(children: .combine)
  }

  private var phoneRecordLabel: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(record.localizedDeviceName)
        .font(.body.weight(.semibold))
        .foregroundStyle(.primary)
      Text(record.logDate, style: .date)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Text(String(format: L10n.string("cycle_count_format", table: "Analytics"), record.cycleCount))
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  private var phoneHealthLabel: some View {
    let health = appSettings.analysisDataSource == .nominal
      ? record.nominalHealthPercent : record.healthPercent
    return VStack(alignment: .trailing, spacing: 5) {
      Text(health / 100, format: .percent.precision(.fractionLength(1)))
      .font(.system(.title2, weight: .semibold))
      .monospacedDigit()
      .foregroundStyle(health < 80 ? Color.red : health < 90 ? Color.orange : appSettings.accentColor.color)
      Text(record.cachedDiagnostic)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
      .fixedSize()
      .accessibilityLabel(L10n.string("battery_health", table: "Records"))
      .accessibilityValue(Text(health / 100, format: .percent.precision(.fractionLength(1))))
  }

  private var existingRow: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .center, spacing: 16) {
        recordLabel
        Spacer(minLength: 12)
        healthLabel
      }
      VStack(alignment: .leading, spacing: 12) {
        recordLabel
        healthLabel
      }
    }
    .padding(.vertical, 10)
  }

  private var recordLabel: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(record.logDate, style: .date)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)
      Label(String(format: L10n.string("cycle_count_format", table: "Analytics"), record.cycleCount),
        systemImage: "arrow.triangle.2.circlepath")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var healthLabel: some View {
    let health = appSettings.analysisDataSource == .nominal
      ? record.nominalHealthPercent : record.healthPercent
    return VStack(alignment: .leading, spacing: 5) {
      Text(health / 100, format: .percent.precision(.fractionLength(1)))
        .font(.system(.title3, design: .rounded, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(healthColor(health))
      Text(record.cachedDiagnostic)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }

  private func healthColor(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return .green
  }
}
// MARK: - Previews ✅
#if DEBUG
  struct RecordViews_Previews: PreviewProvider {
    static var previews: some View {
      let sample = BatteryRecord(
        date: Date(), cycleCount: 420, maxCapacityPercent: 90, realCapacitymAh: 3200,
        designCapacitymAh: 3500, deviceName: "iPhone 15 Pro")

      Group {
        NavigationStack {
          RecordDetailView(record: sample)
        }
        .previewDevice(PreviewDevice(rawValue: "iPad Air (5th generation)"))
        .previewDisplayName("iPad - Regular")

        NavigationStack {
          RecordDetailView(record: sample)
        }
        .previewDevice(PreviewDevice(rawValue: "iPhone 14"))
        .previewDisplayName("iPhone - Compact")
      }
    }
  }
#endif
// Small card component for iPad detail layout
struct DetailCard<Content: View>: View {
  let title: String
  let systemImage: String?
  let content: Content

  init(title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.systemImage = systemImage
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 12) {
        if let sys = systemImage {
          ZStack {
            Circle()
              .fill(
                LinearGradient(
                  gradient: Gradient(colors: [
                    AppSettings.shared.accentColor.color.opacity(0.16),
                    Color(uiColor: .systemBackground).opacity(0.06),
                  ]),
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
              .frame(width: 44, height: 44)
            Image(systemName: sys)
              .foregroundStyle(AppSettings.shared.accentColor.color)
              .font(.system(size: 18, weight: .semibold))
          }
          .frame(width: 44, height: 44)
        }
        Text(title).font(.subheadline.weight(.semibold))
        Spacer()
      }
      content
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .mochiCard()
  }
}

struct RecordDetailView: View {
  let record: BatteryRecord
  var showsCloseButton = false
  @StateObject private var appSettings = AppSettings.shared
  @Environment(\.dismiss) private var dismiss
  @Environment(\.displayScale) private var displayScale
  @Environment(\.colorScheme) private var colorScheme

  @EnvironmentObject private var dataStore: DataStore
  @State private var shareImage: Image?
  @State private var isShowingSharingSheet = false
  @State private var shareItems: [Any] = []
  @State private var isGeneratingImage = false
  @State private var cachedChartImage: UIImage?

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  private var isMagSafe: Bool {
    record.deviceName == "iPhone Air MagSafeバッテリー"
  }

  var body: some View {

    GeometryReader { geometry in
    Group {
      // iPad / Regular width: bento-styleカードグリッド with polished header and summary panel
      if horizontalSizeClass == .regular && geometry.size.width >= 620 && !dynamicTypeSize.isAccessibilitySize {
        ScrollView {
          LazyVStack(spacing: 20) {
            // Header with large circular health ring and summary info
            HStack(alignment: .center, spacing: 20) {
              // 健康リング（動的コンテンツなのでCachedView削除）
              ZStack {
                Circle()
                  .stroke(Color(uiColor: .systemGray5), lineWidth: 10)
                  .frame(width: 120, height: 120)
                Circle()
                  .trim(
                    from: 0,
                    to: CGFloat(
                      min(
                        max(
                          appSettings.analysisDataSource == .nominal
                            ? record.nominalHealthPercent : record.healthPercent, 0), 100))
                      / 100.0
                  )
                  .stroke(
                    AppSettings.shared.accentColor.color,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                  )
                  .rotationEffect(.degrees(-90))
                  .frame(width: 120, height: 120)
                VStack {
                  let health =
                    appSettings.analysisDataSource == .nominal
                    ? record.nominalHealthPercent : record.healthPercent
                  Text("\(String(format: "%.0f", health))%")
                    .font(.title)
                    .bold()
                    .foregroundStyle(healthColorLocal(health))
                }
              }
              .padding(10)

              VStack(alignment: .leading, spacing: 6) {
                Text(record.localizedDeviceName).font(.title2).bold()
                if let code = record.deviceModelCode {
                  Text(code).font(.subheadline).foregroundStyle(.secondary)
                }
                Text(record.logDate, style: .date).font(.subheadline).foregroundStyle(.secondary)

                HStack(spacing: 12) {
                  Label(
                    String(
                      format: L10n.string("cycle_count_format", table: "Analytics"),
                      record.cycleCount),
                    systemImage: "gauge"
                  )
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  Label("\(record.nominalCapacity) mAh", systemImage: "battery.25")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }

              Spacer()

            }
            .padding(24)
            .mochiCard()

            // Device info spans full width on iPad
            DetailCard(
              title: L10n.string("device_info", table: "Records"), systemImage: "iphone"
            ) {
              VStack(alignment: .leading, spacing: 8) {
                LabeledContent(
                  L10n.string("device_name", table: "Common"), value: record.localizedDeviceName)

                if !isMagSafe {
                  if let soc = record.soc {
                    InfoLabeledContent(
                      L10n.string("soc", table: "Records"),
                      hint: L10n.string("hint_soc", table: "Records"),
                      value: soc)
                  }
                }

                if let modelCode = record.deviceModelCode {
                  InfoLabeledContent(
                    L10n.string("model_code", table: "Records"),
                    hint: L10n.string("hint_model_code", table: "Records"),
                    value: modelCode)
                }
                if let productSku = record.productSku, !productSku.isEmpty {
                  InfoLabeledContent(
                    L10n.string("product_sku", table: "Records"),
                    hint: L10n.string("hint_product_sku", table: "Records"),
                    value: productSku)
                }

                if !isMagSafe {
                  if record.storage != nil, let formatted = record.formattedStorage {
                    InfoLabeledContent(
                      L10n.string("storage", table: "Records"),
                      hint: L10n.string("hint_storage", table: "Records"),
                      value: formatted)
                  }
                  if record.ram != nil, let formattedRam = record.formattedRAM {
                    InfoLabeledContent(
                      L10n.string("ram", table: "Records"),
                      hint: L10n.string("hint_ram", table: "Records"),
                      value: formattedRam)
                  }
                }

                LabeledContent(
                  L10n.string("log_date", table: "Records"), value: record.logDate,
                  format: .dateTime.year().month().day())
                if let firstUse = record.firstUseDate {
                  InfoLabeledContent(
                    L10n.string("first_use_date", table: "Records"),
                    hint: L10n.string("hint_first_use_date", table: "Records")
                  ) {
                    Text(firstUse, format: .dateTime.year().month().day())
                  }
                }
              }
              .padding(.vertical, 4)
            }

            // Battery capacity spans full width to avoid cut-off
            DetailCard(
              title: L10n.string("battery_capacity", table: "Analytics"),
              systemImage: "battery.100"
            ) {
              VStack(alignment: .leading, spacing: 8) {
                InfoLabeledContent(
                  L10n.string("cycle_count", table: "Analytics"),
                  hint: L10n.string("hint_cycle_count", table: "Records"),
                  value: String(
                    format: L10n.string("cycle_count_format", table: "Analytics"),
                    record.cycleCount))
                if record.designCapacity > 0 {
                  InfoLabeledContent(
                    L10n.string("design_capacity", table: "Analytics"),
                    hint: L10n.string("hint_design_capacity", table: "Records"),
                    value: "\(record.designCapacity) mAh (100%)")
                } else {
                  InfoLabeledContent(
                    L10n.string("design_capacity", table: "Analytics"),
                    hint: L10n.string("hint_design_capacity", table: "Records"),
                    value: L10n.string("unknown", table: "Common"))
                }
                if let simProfile = simCapacityProfile(for: record) {
                  LabeledContent(L10n.string("sim_profile", table: "Records"), value: simProfile)
                }
                InfoLabeledContent(
                  L10n.string("nominal_capacity", table: "Analytics"),
                  hint: L10n.string("hint_nominal_capacity", table: "Records")
                ) {
                  HStack(spacing: 8) {
                    Text("\(record.nominalCapacity) mAh")
                    let nominalPercent =
                      record.designCapacity > 0
                      ? (Double(record.nominalCapacity) / Double(record.designCapacity)) * 100.0
                      : record.realHealthPercent
                    Text("(\(String(format: "%.1f%%", nominalPercent)))")
                      .foregroundStyle(healthColorLocal(nominalPercent))
                  }
                }
                if !isMagSafe {
                  InfoLabeledContent(
                    L10n.string("raw_capacity", table: "Analytics"),
                    hint: L10n.string("hint_raw_capacity", table: "Records")
                  ) {
                    HStack(spacing: 8) {
                      Text("\(record.rawCapacity) mAh")
                      let health =
                        appSettings.analysisDataSource == .nominal
                        ? record.nominalHealthPercent : record.healthPercent
                      Text("(\(String(format: "%.1f%%", record.healthPercent)))")
                        .foregroundStyle(healthColorLocal(health))
                    }
                  }
                  if let lowRate = record.lowRateCapacity {
                    let lowRateRatio = record.designCapacity > 0 ? (Double(lowRate) / Double(record.designCapacity)) * 100.0 : 0.0
                    InfoLabeledContent(
                      L10n.string("low_rate_capacity", table: "Records"),
                      hint: L10n.string("hint_low_rate_capacity", table: "Records"),
                      value: "\(lowRate) mAh (\(String(format: "%.1f%%", lowRateRatio)))"
                    )
                  }
                  if let display = record.settingsDisplayPercent {
                    InfoLabeledContent(
                      L10n.string("os_display", table: "Records"),
                      hint: L10n.string("hint_os_display", table: "Records"),
                      value: "\(min(display, 100))%")
                  }
                }

                Divider().padding(.vertical, 6)

                if let deflator = record.deflator {
                  InfoLabeledContent(
                    L10n.string("deflator", table: "Records"),
                    hint: L10n.string("hint_deflator", table: "Records"),
                    value: String(format: "%.1f%%", deflator)
                  )
                }
                InfoLabeledContent(
                  L10n.string("diagnostic_result", table: "Records"),
                  hint: L10n.string("hint_diagnostic_result", table: "Records"),
                  value: record.cachedDiagnostic)
                if !isMagSafe {
                  if let displayDiagnostic = settingsDisplayDiagnosticMessage(
                    record.settingsDisplayPercent)
                  {
                    InfoLabeledContent(
                      L10n.string("settings_display_diagnostic", table: "Records"),
                      hint: L10n.string("hint_settings_display_diagnostic", table: "Records"),
                      value: displayDiagnostic
                    )
                  }
                }
                Text(L10n.string("not_official_note", table: "Records"))
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              .padding(.vertical, 4)
            }

            // Remaining cards in grid
            LazyVGrid(
              columns: [GridItem(.adaptive(minimum: 280, maximum: 500), spacing: 20)],
              alignment: .leading,
              spacing: 20
            ) {
              // Temperature (optional)
              if record.avgTemp != nil || record.maxTemp != nil || record.minTemp != nil {
                DetailCard(
                  title: L10n.string("temperature_daily", table: "Records"),
                  systemImage: "thermometer"
                ) {
                  VStack(alignment: .leading, spacing: 8) {
                    if let avg = record.avgTemp {
                      InfoLabeledContent(
                        L10n.string("average", table: "Analytics"),
                        hint: L10n.string("hint_temperature", table: "Records"),
                        value: String(format: "%.1f°C", avg))
                    }
                    if let max = record.maxTemp {
                      InfoLabeledContent(
                        L10n.string("maximum", table: "Analytics"),
                        hint: L10n.string("hint_temperature", table: "Records"),
                        value: String(format: "%.1f°C", max))
                    }
                    if let min = record.minTemp {
                      InfoLabeledContent(
                        L10n.string("minimum", table: "Analytics"),
                        hint: L10n.string("hint_temperature", table: "Records"),
                        value: String(format: "%.1f°C", min))
                    }
                  }
                  .padding(.vertical, 4)
                }
              }

              // Voltage (optional)
              if record.maxVoltage != nil || record.minVoltage != nil {
                DetailCard(
                  title: L10n.string("voltage", table: "Records"), systemImage: "bolt.fill"
                ) {
                  VStack(alignment: .leading, spacing: 8) {
                    if let max = record.maxVoltage {
                      InfoLabeledContent(
                        L10n.string("maximum", table: "Analytics"),
                        hint: L10n.string("hint_voltage", table: "Records"),
                        value: String(format: "%.0f mV", max))
                    }
                    if let min = record.minVoltage {
                      InfoLabeledContent(
                        L10n.string("minimum", table: "Analytics"),
                        hint: L10n.string("hint_voltage", table: "Records"),
                        value: String(format: "%.0f mV", min))
                    }
                  }
                  .padding(.vertical, 4)
                }
              }

              // Charge range (optional)
              if record.maxSoC != nil || record.minSoC != nil {
                DetailCard(
                  title: L10n.string("charge_range_daily", table: "Records"),
                  systemImage: "battery.75"
                ) {
                  VStack(alignment: .leading, spacing: 8) {
                    if let max = record.maxSoC {
                      InfoLabeledContent(
                        L10n.string("max_soc", table: "Records"),
                        hint: L10n.string("hint_charge_range", table: "Records"),
                        value: "\(max)%")
                    }
                    if let min = record.minSoC {
                      InfoLabeledContent(
                        L10n.string("min_soc", table: "Records"),
                        hint: L10n.string("hint_charge_range", table: "Records"),
                        value: "\(min)%")
                    }
                  }
                  .padding(.vertical, 4)
                }
              }
            }
            .padding(.vertical, 18)
          }
        }
        .frame(maxWidth: 960)
        .frame(maxWidth: .infinity)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
      } else {
        // Compact width (iPhone): 既存の List ベース UI
        List {
          Section {
            detailOverview
              .listRowInsets(EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))
          }
          Section(L10n.string("device_info", table: "Records")) {
            LabeledContent(
              L10n.string("device_name", table: "Common"), value: record.localizedDeviceName)

            if !isMagSafe {
              if let soc = record.soc {
                InfoLabeledContent(
                  L10n.string("soc", table: "Records"),
                  hint: L10n.string("hint_soc", table: "Records"),
                  value: soc)
              }
            }

            if let modelCode = record.deviceModelCode {
              InfoLabeledContent(
                L10n.string("model_code", table: "Records"),
                hint: L10n.string("hint_model_code", table: "Records"),
                value: modelCode)
            }
            if let productSku = record.productSku, !productSku.isEmpty {
              InfoLabeledContent(
                L10n.string("product_sku", table: "Records"),
                hint: L10n.string("hint_product_sku", table: "Records"),
                value: productSku)
            }

            if !isMagSafe {
              if record.storage != nil, let formatted = record.formattedStorage {
                InfoLabeledContent(
                  L10n.string("storage", table: "Records"),
                  hint: L10n.string("hint_storage", table: "Records"),
                  value: formatted)
              }
              if record.ram != nil, let formattedRam = record.formattedRAM {
                InfoLabeledContent(
                  L10n.string("ram", table: "Records"),
                  hint: L10n.string("hint_ram", table: "Records"),
                  value: formattedRam)
              }
            }

            LabeledContent(
              L10n.string("log_date", table: "Records"), value: record.logDate,
              format: .dateTime.year().month().day())
            if let firstUse = record.firstUseDate {
              InfoLabeledContent(
                L10n.string("first_use_date", table: "Records"),
                hint: L10n.string("hint_first_use_date", table: "Records")
              ) {
                Text(firstUse, format: .dateTime.year().month().day())
              }
            }
          }

          Section(L10n.string("battery_capacity", table: "Analytics")) {
            InfoLabeledContent(
              L10n.string("cycle_count", table: "Analytics"),
              hint: L10n.string("hint_cycle_count", table: "Records"),
              value: String(
                format: L10n.string("cycle_count_format", table: "Analytics"),
                record.cycleCount))
            if record.designCapacity > 0 {
              InfoLabeledContent(
                L10n.string("design_capacity", table: "Analytics"),
                hint: L10n.string("hint_design_capacity", table: "Records"),
                value: "\(record.designCapacity) mAh (100%)")
            } else {
              InfoLabeledContent(
                L10n.string("design_capacity", table: "Analytics"),
                hint: L10n.string("hint_design_capacity", table: "Records"),
                value: L10n.string("unknown", table: "Common"))
            }
            if let simProfile = simCapacityProfile(for: record) {
              LabeledContent(L10n.string("sim_profile", table: "Records"), value: simProfile)
            }
            InfoLabeledContent(
              L10n.string("nominal_capacity", table: "Analytics"),
              hint: L10n.string("hint_nominal_capacity", table: "Records")
            ) {
              HStack(spacing: 8) {
                Text("\(record.nominalCapacity) mAh")
                let nominalPercent =
                  record.designCapacity > 0
                  ? (Double(record.nominalCapacity) / Double(record.designCapacity)) * 100.0
                  : record.realHealthPercent
                Text("(\(String(format: "%.1f%%", nominalPercent)))")
                  .foregroundStyle(healthColorLocal(nominalPercent))
              }
            }
            if !isMagSafe {
              InfoLabeledContent(
                L10n.string("raw_capacity", table: "Analytics"),
                hint: L10n.string("hint_raw_capacity", table: "Records")
              ) {
                HStack(spacing: 8) {
                  Text("\(record.rawCapacity) mAh")
                  let health =
                    appSettings.analysisDataSource == .nominal
                    ? record.nominalHealthPercent : record.healthPercent
                  Text("(\(String(format: "%.1f%%", record.healthPercent)))")
                    .foregroundStyle(healthColorLocal(health))
                }
              }
              if let lowRate = record.lowRateCapacity {
                let lowRateRatio = record.designCapacity > 0 ? (Double(lowRate) / Double(record.designCapacity)) * 100.0 : 0.0
                InfoLabeledContent(
                  L10n.string("low_rate_capacity", table: "Records"),
                  hint: L10n.string("hint_low_rate_capacity", table: "Records"),
                  value: "\(lowRate) mAh (\(String(format: "%.1f%%", lowRateRatio)))"
                )
              }
              if let display = record.settingsDisplayPercent {
                InfoLabeledContent(
                  L10n.string("os_display", table: "Records"),
                  hint: L10n.string("hint_os_display", table: "Records"),
                  value: "\(min(display, 100))%")
              }
            }

            if let deflator = record.deflator {
              InfoLabeledContent(
                L10n.string("deflator", table: "Records"),
                hint: L10n.string("hint_deflator", table: "Records"),
                value: String(format: "%.1f%%", deflator))
            }
            InfoLabeledContent(
              L10n.string("diagnostic_result", table: "Records"),
              hint: L10n.string("hint_diagnostic_result", table: "Records"),
              value: record.dynamicDiagnosticResult)
            if !isMagSafe {
              if let displayDiagnostic = settingsDisplayDiagnosticMessage(
                record.settingsDisplayPercent)
              {
                InfoLabeledContent(
                  L10n.string("settings_display_diagnostic", table: "Records"),
                  hint: L10n.string("hint_settings_display_diagnostic", table: "Records"),
                  value: displayDiagnostic)
              }
            }
            Text(L10n.string("not_official_note", table: "Records"))
              .font(.caption2)
              .foregroundStyle(.secondary)
          }

          if record.avgTemp != nil || record.maxTemp != nil || record.minTemp != nil {
            Section(L10n.string("temperature_daily", table: "Records")) {
              if let avg = record.avgTemp {
                InfoLabeledContent(
                  L10n.string("average", table: "Analytics"),
                  hint: L10n.string("hint_temperature", table: "Records"),
                  value: String(format: "%.1f°C", avg))
              }
              if let max = record.maxTemp {
                InfoLabeledContent(
                  L10n.string("maximum", table: "Analytics"),
                  hint: L10n.string("hint_temperature", table: "Records"),
                  value: String(format: "%.1f°C", max))
              }
              if let min = record.minTemp {
                InfoLabeledContent(
                  L10n.string("minimum", table: "Analytics"),
                  hint: L10n.string("hint_temperature", table: "Records"),
                  value: String(format: "%.1f°C", min))
              }
            }
          }

          if record.maxVoltage != nil || record.minVoltage != nil {
            Section(L10n.string("voltage", table: "Records")) {
              if let max = record.maxVoltage {
                InfoLabeledContent(
                  L10n.string("maximum", table: "Analytics"),
                  hint: L10n.string("hint_voltage", table: "Records"),
                  value: String(format: "%.0f mV", max))
              }
              if let min = record.minVoltage {
                InfoLabeledContent(
                  L10n.string("minimum", table: "Analytics"),
                  hint: L10n.string("hint_voltage", table: "Records"),
                  value: String(format: "%.0f mV", min))
              }
            }
          }

          if record.maxSoC != nil || record.minSoC != nil {
            Section(L10n.string("charge_range_daily", table: "Records")) {
              if let max = record.maxSoC {
                InfoLabeledContent(
                  L10n.string("max_soc", table: "Records"),
                  hint: L10n.string("hint_charge_range", table: "Records"),
                  value: "\(max)%")
              }
              if let min = record.minSoC {
                InfoLabeledContent(
                  L10n.string("min_soc", table: "Records"),
                  hint: L10n.string("hint_charge_range", table: "Records"),
                  value: "\(min)%")
              }
            }
          }
        }
      }
    }
    }
    .navigationTitle(L10n.string("detail", table: "Records"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if showsCloseButton {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(L10n.string("close", table: "Common")) {
            dismiss()
          }
        }
      }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            Task {
              isGeneratingImage = true
              let image: UIImage?
              if let cached = cachedChartImage {
                image = cached
              } else {
                image = await generateChartImageAsync()
              }
              isGeneratingImage = false
              shareContent(text: generateShareText(), image: image)
            }
          } label: {
            if isGeneratingImage {
              ProgressView()
            } else {
              Image(systemName: "square.and.arrow.up")
            }
          }
          .accessibilityIdentifier("record.share")
        }
    }
    .scrollContentBackground(.hidden)
    .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    .sheet(isPresented: $isShowingSharingSheet) {
      if !shareItems.isEmpty {
        ActivityViewController(
          activityItems: shareItems,
          thumbnailImage: cachedChartImage
        )
      }
    }


  }

  private var detailOverview: some View {
    let health = appSettings.analysisDataSource == .nominal
      ? record.nominalHealthPercent : record.healthPercent
    return VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 5) {
        Text(record.localizedDeviceName).font(.title2.weight(.semibold))
        Text(record.logDate, style: .date).foregroundStyle(.secondary).font(.subheadline)
      }
      Divider()
      VStack(alignment: .leading, spacing: 6) {
        Text(L10n.string("battery_health", table: "Records"))
          .font(.subheadline).foregroundStyle(.secondary)
        Text(health / 100, format: .percent.precision(.fractionLength(1)))
          .font(.system(.largeTitle, design: .rounded, weight: .semibold))
          .monospacedDigit().foregroundStyle(healthColorLocal(health))
        Text(record.cachedDiagnostic).font(.subheadline).foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityIdentifier("record.overview")
  }

  // Generate share text for the record
  private func generateShareText() -> String {
    let health =
      appSettings.analysisDataSource == .nominal
      ? record.nominalHealthPercent : record.healthPercent
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.locale = L10n.locale

    // タイトル
    var text = L10n.string("share_title", table: "Records")
    text += "\n\n"

    // デバイス名（モデルコードは表示しない）
    text += "\(record.localizedDeviceName)\n"

    // 記録日付
    text += "\(dateFormatter.string(from: record.logDate))\n\n"

    // バッテリー最大容量
    text +=
      "\(L10n.string("battery_health", table: "Records")): \(String(format: "%.1f", health))%\n"
    text += "\(record.cachedDiagnostic)\n\n"

    // 使用期間（初使用日がある場合）
    if let firstUse = record.firstUseDate {
      let calendar = Calendar.current
      let components = calendar.dateComponents([.day], from: firstUse, to: record.logDate)
      if let days = components.day {
        text += "\(L10n.string("share_usage_period", table: "Records")): "

        if days >= 365 {
          let years = days / 365
          let remainingDays = days % 365
          text += String(
            format: L10n.string("share_years_days", table: "Records"),
            years, remainingDays
          )
        } else {
          text += String(
            format: L10n.string("share_days", table: "Records"),
            days
          )
        }
        text += "\n"
      }
    }

    // サイクルカウント
    text += String(
      format:
        "\(L10n.string("cycle_count", table: "Analytics")): \(L10n.string("cycle_count_format", table: "Analytics"))",
      record.cycleCount
    )
    text += "\n"

    // 実測容量
    text +=
      "\(L10n.string("raw_capacity", table: "Analytics")): \(record.rawCapacity) mAh"
    text += "\n"

    // 公称容量
    text +=
      "\(L10n.string("nominal_capacity", table: "Analytics")): \(record.nominalCapacity) mAh"
    text += "\n"

    // 設計容量（ある場合）
    if record.designCapacity > 0 {
      text +=
        "\(L10n.string("design_capacity", table: "Analytics")): \(record.designCapacity) mAh"
      text += "\n"
    }

    // フッター（アプリ名とハッシュタグ）
    text += L10n.string("share_footer", table: "Records")

    return text
  }

  // グラフ画像を非同期生成（UIスレッドをブロックしない）
  @MainActor
  private func generateChartImageAsync() async -> UIImage? {
    let deviceName = record.deviceName
    let deviceRecords = dataStore.fetchRecords(for: deviceName)

    guard !deviceRecords.isEmpty else { return nil }

    let calendar = Calendar.current
    let now = Date()

    // 分析タブと同じレンジを使用（AppSettingsから取得）
    let range: RangePreset
    if let savedRangeString = appSettings.selectedChartRange,
      let savedRange = RangePreset(rawValue: savedRangeString)
    {
      range = savedRange
    } else {
      // 自動レンジ: データ期間に基づいて計算
      let pastRecords = deviceRecords.filter { $0.logDate <= now }
      guard let first = pastRecords.min(by: { $0.logDate < $1.logDate })?.logDate,
        let last = pastRecords.max(by: { $0.logDate < $1.logDate })?.logDate
      else { return nil }

      let days = calendar.dateComponents([.day], from: first, to: last).day ?? 0
      if days <= 7 {
        range = .oneWeek
      } else if days <= 14 {
        range = .twoWeeks
      } else if days <= 30 {
        range = .oneMonth
      } else if days <= 90 {
        range = .threeMonths
      } else if days <= 180 {
        range = .sixMonths
      } else if days <= 365 {
        range = .oneYear
      } else if days <= 730 {
        range = .twoYears
      } else {
        range = .threeYears
      }
    }

    // 最新のレコード日付を終了日として使用
    guard let windowEnd = deviceRecords.max(by: { $0.logDate < $1.logDate })?.logDate else {
      return nil
    }

    let startDate = ChartWindowNavigator.windowStart(
      for: windowEnd, range: range, allRecords: deviceRecords)
    let startDay = calendar.startOfDay(for: startDate)
    let endDay = calendar.startOfDay(for: windowEnd)

    let visibleRecords = deviceRecords.filter { record in
      let d = calendar.startOfDay(for: record.logDate)
      return d >= startDay && d <= endDay
    }

    let dataSource = appSettings.analysisDataSource
    let points = visibleRecords.map { entry in
      ShareChartRenderer.Point(
        date: entry.logDate,
        capacity: dataSource == .nominal ? entry.nominalCapacity : entry.rawCapacity)
    }
    // Let the spinner appear before drawing. The small UIKit plot does not create a second
    // SwiftUI/Charts graph while the detail screen presents the share sheet.
    await Task.yield()
    return ShareChartRenderer.render(
      points: points, tint: UIColor(appSettings.accentColor.color),
      isDark: colorScheme == .dark, scale: displayScale,
      locale: Locale(identifier: L10n.language))
  }

  // 共有処理
  private func shareContent(text: String, image: UIImage?) {
    var items: [Any] = []
    if let image = image {
      items.append(image)
    }
    items.append(text)

    shareItems = items

    // 次のrunloopで共有シートを表示（ActivityViewControllerの初回初期化を待つ）
    DispatchQueue.main.async {
      self.isShowingSharingSheet = true
    }
  }

  // Local helper that uses accent color for 'good' state when available
  private func healthColorLocal(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return .green
  }

  private func healthColor(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return .green
  }

  private func settingsDisplayDiagnosticMessage(_ percent: Int?) -> String? {
    guard let p = percent else { return nil }
    if p >= 100 {
      // 100%以上：正常（良好）
      return String(
        format: L10n.string("settings_display_diagnostic_high", table: "Records"), p)
    }
    if p >= 90 {
      // 90%以上100%未満：やや劣化
      return String(
        format: L10n.string("settings_display_diagnostic_slight", table: "Records"), p)
    }
    if p >= 80 {
      // 80%以上90%未満：中間（劣化傾向）
      return String(
        format: L10n.string("settings_display_diagnostic_normal", table: "Records"), p)
    }
    // 80%未満：交換を検討
    return String(format: L10n.string("settings_display_diagnostic_low", table: "Records"), p)
  }
}
