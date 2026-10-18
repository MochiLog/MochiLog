import SwiftUI

// MARK: - サンプルデータ分析ビュー
/// データがない時にサンプルデータでグラフを表示するビュー
/// 共通のグラフ表示コンポーネントを使用してコード重複を排除
@MainActor
struct SampleDataAnalyticsContent: View {
  @Binding var showingSampleData: Bool
  @Binding var selectedRange: RangePreset
  @State private var cycleRange: RangePreset = .auto
  @State private var cycleWindowEnd = Date()
  private var independentCharts: Bool { UIDevice.current.userInterfaceIdiom == .pad }
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var availableWidth: CGFloat = 0
  @State private var selectedDevice: String?
  @State private var windowEnd: Date = Date()
  @State private var hasInitialized = false

  private let sampleRecords = SampleDataProvider.generateSampleRecords()

  private var deviceNames: [String] {
    SampleDataProvider.sampleDeviceNames
  }

  private var filteredRecords: [BatteryRecord] {
    guard let device = selectedDevice else { return sampleRecords }
    return sampleRecords.filter { $0.deviceName == device }
  }

  /// 全デバイス名（ソート済み）— チャートの色安定割り当て用
  private var sortedAllDeviceNames: [String] {
    SampleDataProvider.sampleDeviceNames.sorted()
  }

  // MARK: - 共通ユーティリティを使用したプロパティ

  private var canMoveNext: Bool {
    ChartWindowNavigator.canMoveNext(
      currentEnd: windowEnd, range: selectedRange, records: filteredRecords)
  }

  private var canMovePrevious: Bool {
    ChartWindowNavigator.canMovePrevious(
      currentEnd: windowEnd, range: selectedRange, records: filteredRecords)
  }

  private func shiftWindow(backward: Bool) {
    windowEnd = ChartWindowNavigator.shiftWindow(
      currentEnd: windowEnd,
      backward: backward,
      range: selectedRange,
      records: filteredRecords
    )
  }

  private var cycleShiftWindow: ((Bool) -> Void)? {
    if independentCharts { return nil }
    return { shiftWindow(backward: $0) }
  }

  private func cycleTrend(unit: AppSettings.ChartUnit) -> some View {
    CycleTrendView(
      allRecords: filteredRecords, unit: unit,
      initialRange: selectedRange, allDeviceNames: sortedAllDeviceNames,
      sharedSelectedRange: independentCharts ? $cycleRange : $selectedRange,
      sharedWindowEnd: independentCharts ? $cycleWindowEnd : $windowEnd,
      sharedCanMoveNext: independentCharts ? nil : canMoveNext,
      sharedCanMovePrevious: independentCharts ? nil : canMovePrevious,
      sharedShiftWindow: cycleShiftWindow,
      sharedWindowEndValue: independentCharts ? cycleWindowEnd : windowEnd)
  }

  var body: some View {
    let _ = print("[Performance] SampleDataAnalyticsContent.body構築開始")
    let bodyStartTime = CFAbsoluteTimeGetCurrent()

    return VStack(spacing: 20) {
      // サンプルデータバナー
      SampleDataBanner(
        onClose: {
          withAnimation {
            showingSampleData = false
          }
        },
        onAddData: {}
      )

      // デバイス選択ピッカー
      DevicePickerView(deviceNames: deviceNames, selectedDevice: $selectedDevice)

      // 期間計算（共通ロジック）
      let dates = filteredRecords.map { $0.logDate }
      let window = computeWindow(recordDates: dates, windowEnd: windowEnd, range: selectedRange)

      let calendar = Calendar.current
      let startDay = window.startDay
      let endDay = window.endDay

      let visibleRecords = filteredRecords.filter {
        let d = calendar.startOfDay(for: $0.logDate)
        return d >= startDay && d <= endDay
      }

      // チャート用：ウィンドウ外の前後コンテキストレコードを含む（補間線描画用）
      let chartRecords = ChartWindowNavigator.visibleRecordsWithContext(
        in: filteredRecords,
        start: startDay,
        end: endDay
      )

      let unit = window.unit

      let _ = {
        let elapsed = (CFAbsoluteTimeGetCurrent() - bodyStartTime) * 1000
        print(
          "[Performance] SampleDataAnalyticsContent.body計算完了: \(String(format: "%.2f", elapsed))ms")
      }()

      // iPad: 2列レイアウト、iPhone: 1列レイアウト
      if horizontalSizeClass == .regular && availableWidth >= 740
        && !dynamicTypeSize.isAccessibilitySize
      {
        // iPad向け2列グリッド
        VStack(spacing: 20) {
          HStack(alignment: .top, spacing: 20) {
            // ヘルス推移グラフ
            HealthTrendView(
              visibleRecords: chartRecords,
              startDay: startDay,
              endDay: endDay,
              unit: unit,
              selectedRange: $selectedRange,
              canMoveNext: canMoveNext,
              canMovePrevious: canMovePrevious,
              shiftWindow: shiftWindow,
              allDeviceNames: sortedAllDeviceNames
            )

            // サイクル推移グラフ（iPadは独立動作、initialRangeで初期化）
            cycleTrend(unit: unit)
          }

          // 統計情報（iPad）
          StatisticsView(filteredRecords: visibleRecords)
        }
        .frame(maxWidth: 1200)
      } else {
        // iPhone向け1列レイアウト
        // ヘルス推移グラフ
        HealthTrendView(
          visibleRecords: chartRecords,
          startDay: startDay,
          endDay: endDay,
          unit: unit,
          selectedRange: $selectedRange,
          canMoveNext: canMoveNext,
          canMovePrevious: canMovePrevious,
          shiftWindow: shiftWindow,
          allDeviceNames: sortedAllDeviceNames
        )

        // サイクル推移グラフ（iPhoneでは親と期間を共有）
        cycleTrend(unit: unit)

        // 統計情報（iPhone）
        StatisticsView(filteredRecords: visibleRecords)
      }
    }
    .frame(maxWidth: 1200)
    .padding(.horizontal)
    .frame(maxWidth: .infinity)
    .background {
      GeometryReader { geometry in
        Color.clear.onAppear { availableWidth = geometry.size.width }
          .onChange(of: geometry.size.width) { availableWidth = $0 }
      }
    }
    .onAppear {
      guard !hasInitialized else { return }
      hasInitialized = true

      // ウィンドウ終了日を初期化
      windowEnd = ChartWindowNavigator.initializeWindowEnd(
        for: filteredRecords, range: selectedRange)
      // 自動でレンジを設定
      let autoRange: RangePreset = .auto
      if selectedRange != autoRange {
        selectedRange = autoRange
      }
    }
    .onChange(of: selectedRange) { newValue in
      windowEnd = ChartWindowNavigator.adjustedWindowEndForRangeChange(
        range: newValue,
        currentEnd: windowEnd,
        records: filteredRecords
      )
    }
  }

  private func computeWindow(
    recordDates: [Date],
    windowEnd: Date,
    range: RangePreset
  ) -> (startDay: Date, endDay: Date, unit: AppSettings.ChartUnit) {
    ChartWindowNavigator.computeChartWindow(
      recordDates: recordDates,
      windowEnd: windowEnd, range: range)
  }
}
