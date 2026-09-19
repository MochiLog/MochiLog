import Charts
import SwiftUI

struct CycleTrendView: View {
  let allRecords: [BatteryRecord]  // フィルタ前の全レコード（期間計算用）
  let unit: AppSettings.ChartUnit
  @State private var animateChart: Bool = false
  @State private var isChartReady: Bool = false  // 遅延レンダリング用
  var initialRange: RangePreset = .oneMonth  // 初期レンジ（サンプルモード用）
  var allDeviceNames: [String]?  // 全デバイス名（色固定用、nilの場合はallRecordsから計算）

  // iPhone用：親から渡される期間情報（Bindingがある場合は親と同期）
  var sharedSelectedRange: Binding<RangePreset>?
  var sharedWindowEnd: Binding<Date>?
  var sharedCanMoveNext: Bool?
  var sharedCanMovePrevious: Bool?
  var sharedShiftWindow: ((Bool) -> Void)?

  // iPhone用：windowEndの実値（SwiftUIのdiff検知用、Binding経由だと再描画がトリガーされない）
  var sharedWindowEndValue: Date?

  // iPad用：独自の期間設定
  @State private var localSelectedRange: RangePreset = .oneMonth
  @State private var localWindowEnd: Date = Date()
  @State private var hasInitialized: Bool = false
  @State private var isUserInteracted: Bool = false

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  private var chartHeight: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? 320 : (horizontalSizeClass == .regular ? 280 : 200)
  }

  // 使用する期間設定（親から渡されていれば親の値、なければローカル）
  private var selectedRange: RangePreset {
    sharedSelectedRange?.wrappedValue ?? localSelectedRange
  }

  private var windowEnd: Date {
    sharedWindowEndValue ?? sharedWindowEnd?.wrappedValue ?? localWindowEnd
  }

  // 現在のウィンドウに含まれるレコードを計算
  private var visibleRecords: [BatteryRecord] {
    let startDate = startDay
    return ChartWindowNavigator.visibleRecordsWithContext(
      in: allRecords,
      start: startDate,
      end: effectiveEndDate
    )
  }

  private var chartWindow: (startDay: Date, endDay: Date, unit: AppSettings.ChartUnit) {
    ChartWindowNavigator.computeChartWindow(recordDates: allRecords.map(\.logDate),
      windowEnd: windowEnd, range: selectedRange)
  }

  private var startDay: Date { chartWindow.startDay }
  private var endDay: Date { chartWindow.endDay }

  /// 全レコードのデバイス名（ソート済み）— 色の安定割り当て用
  private var sortedAllDeviceNames: [String] {
    allDeviceNames ?? Array(Set(allRecords.map { $0.deviceName })).sorted()
  }

  // ウィンドウ計算ヘルパー
  private func windowStart(for endDate: Date, range: RangePreset) -> Date {
    ChartWindowNavigator.windowStart(for: endDate, range: range, allRecords: allRecords)
  }

  private var canMoveNext: Bool {
    selectedRange != .auto && (sharedCanMoveNext
      ?? ChartWindowNavigator.canMoveNext(
        currentEnd: effectiveLocalWindowEnd, range: effectiveLocalRange, records: allRecords))
  }

  private var canMovePrevious: Bool {
    selectedRange != .auto && (sharedCanMovePrevious
      ?? ChartWindowNavigator.canMovePrevious(
        currentEnd: effectiveLocalWindowEnd, range: effectiveLocalRange, records: allRecords))
  }

  private var effectiveLocalRange: RangePreset {
    ChartWindowNavigator.effectiveRange(for: allRecords.map(\.logDate), range: selectedRange)
  }

  private var effectiveLocalWindowEnd: Date {
    ChartWindowNavigator.effectiveEndDate(for: allRecords.map(\.logDate),
      windowEnd: windowEnd, range: selectedRange)
  }

  private var effectiveEndDate: Date { effectiveLocalWindowEnd }

  private func shiftWindow(backward: Bool) {
    if let sharedShift = sharedShiftWindow {
      sharedShift(backward)
    } else {
      let newEnd = ChartWindowNavigator.shiftWindow(
        currentEnd: effectiveLocalWindowEnd,
        backward: backward,
        range: effectiveLocalRange,
        records: allRecords
      )
      if let sharedWindowEnd { sharedWindowEnd.wrappedValue = newEnd }
      else { localWindowEnd = newEnd }
    }
  }

  var body: some View {
    let _ = print(
      "[Performance] CycleTrendView.body構築開始 - allRecords: \(allRecords.count)件, visible: \(visibleRecords.count)件"
    )

    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text(L10n.string("cycle_trend", table: "Analytics"))
          .font(.headline)


      }

      if allRecords.isEmpty {
        Text(L10n.string("no_records_for_device", table: "Analytics"))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding()
      } else {
        // iPad向け期間セレクター
        if horizontalSizeClass == .regular || UIDevice.current.userInterfaceIdiom == .pad {
          ChartRangeSelector(
            selectedRange: Binding(
              get: { selectedRange },
              set: {
                isUserInteracted = true
                if let sharedSelectedRange {
                  sharedSelectedRange.wrappedValue = $0
                  if sharedShiftWindow == nil, let sharedWindowEnd {
                    sharedWindowEnd.wrappedValue = ChartWindowNavigator.adjustedWindowEndForRangeChange(
                      range: $0, currentEnd: windowEnd, records: allRecords)
                  }
                } else {
                  localSelectedRange = $0
                  localWindowEnd = ChartWindowNavigator.adjustedWindowEndForRangeChange(
                    range: $0, currentEnd: localWindowEnd, records: allRecords)
                }
              }
            ),
            canMoveNext: canMoveNext,
            canMovePrevious: canMovePrevious,
            shiftWindow: { backward in
              isUserInteracted = true
              shiftWindow(backward: backward)
            },
            startDay: startDay,
            endDay: endDay,
            identifierPrefix: "chart.cycle"
          )
        }

        if isChartReady {
          let chartRecords = ChartAxisHelper.downsampledRecords(
            visibleRecords, startDay: startDay, endDay: endDay)
          // 表示されているデバイス名とその色のマッピングを計算
          let visibleDeviceNames = Array(Set(chartRecords.map { $0.deviceName })).sorted()
          let visibleDeviceColors = visibleDeviceNames.map { deviceName -> Color in
            if let index = sortedAllDeviceNames.firstIndex(of: deviceName) {
              return ChartAxisHelper.deviceColorPalette[
                index % ChartAxisHelper.deviceColorPalette.count]
            }
            // フォールバック: sortedAllDeviceNamesにない場合はデバイス名のハッシュから色を選択
            print(
              "[Warning] Device '\(deviceName)' not found in sortedAllDeviceNames, using fallback color"
            )
            let fallbackIndex = Int(UInt(bitPattern: deviceName.hashValue) % UInt(ChartAxisHelper.deviceColorPalette.count))
            return ChartAxisHelper.deviceColorPalette[fallbackIndex]
          }

          cycleChartView(
            chartRecords: chartRecords, visibleDeviceNames: visibleDeviceNames,
            visibleDeviceColors: visibleDeviceColors
          )
          if dynamicTypeSize.isAccessibilitySize {
            AccessibleChartLegend(names: visibleDeviceNames, colors: visibleDeviceColors)
          }
        } else {
          Color.clear
            .frame(height: chartHeight)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .padding()
    .mochiCard()
    .onAppear {
      // 初期レンジを設定（一度だけ、親から渡されていない場合のみ）
      if !hasInitialized && sharedSelectedRange == nil {
        localSelectedRange = initialRange
        localWindowEnd = ChartWindowNavigator.initializeWindowEnd(
          for: allRecords, range: initialRange)
        hasInitialized = true
      }
      if !hasInitialized, sharedShiftWindow == nil, let sharedWindowEnd {
        sharedWindowEnd.wrappedValue = ChartWindowNavigator.adjustedWindowEndForRangeChange(
          range: selectedRange, currentEnd: windowEnd, records: allRecords)
        hasInitialized = true
      }
      // 次のランループでChart描画を開始（タブ切り替えアニメーションをブロックしない）
      if !isChartReady {
        DispatchQueue.main.async {
          isChartReady = true
        }
      }
      animateChart = true
    }
    .onChange(of: ChartWindowNavigator.recordSignature(allRecords, selectedDevice: nil)) { _ in
      guard sharedShiftWindow == nil else { return }
      let newEnd = ChartWindowNavigator.adjustedWindowEndForRangeChange(
        range: selectedRange, currentEnd: windowEnd, records: allRecords)
      if let sharedWindowEnd { sharedWindowEnd.wrappedValue = newEnd }
      else { localWindowEnd = newEnd }
    }
    .onChange(of: selectedRange) { _ in
      // レンジ変更時のみアニメーション実行
      animateChart = false
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
        withAnimation(.easeOut(duration: 0.4)) {
          animateChart = true
        }
      }
    }
    .onChange(of: windowEnd) { _ in
      // iPhone での連動：親の windowEnd が変わったらアニメーション実行
      // （戻る・進むボタンで期間移動した時）
      if sharedWindowEnd != nil {
        animateChart = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
          withAnimation(.easeOut(duration: 0.4)) {
            animateChart = true
          }
        }
      }
    }
    .onChange(of: initialRange) { _ in
      // iPad独立モードで、ユーザー操作がまだない場合は initialRange の変更に追従
      // （サンプルモード開始時などに外部から3年レンジを設定できるようにする）
      if !isUserInteracted && sharedSelectedRange == nil {
        localSelectedRange = initialRange
        localWindowEnd = ChartWindowNavigator.initializeWindowEnd(
          for: allRecords, range: initialRange)
      }
    }
  }

  // MARK: - チャートビュー（bodyから分離してコンパイラの型チェック負荷を軽減）
  @ViewBuilder
  private func cycleChartView(
    chartRecords: [BatteryRecord], visibleDeviceNames: [String], visibleDeviceColors: [Color]
  ) -> some View {
    Chart {
      ForEach(chartRecords) { record in
        LineMark(
          x: .value(
            L10n.string("date", table: "Common"),
            record.logDate),
          y: .value(L10n.string("cycle_count", table: "Analytics"), record.cycleCount)
        )
        .foregroundStyle(
          by: .value(L10n.string("device_name", table: "Common"), record.localizedDeviceName)
        )
        .interpolationMethod(.linear)
        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
      }

      if !chartRecords.isEmpty {
        let deviceGroups = Dictionary(grouping: chartRecords) { $0.deviceName }

        ForEach(Array(deviceGroups.keys.sorted()), id: \.self) { deviceName in
          let deviceRecords = deviceGroups[deviceName] ?? []
          let thinningFactor = max(1, deviceRecords.count / 10)

          ForEach(
            Array(deviceRecords.enumerated().filter { $0.offset % thinningFactor == 0 }),
            id: \.element.id
          ) { _, pointRecord in
            PointMark(
              x: .value(
                L10n.string("date", table: "Common"),
                pointRecord.logDate),
              y: .value(
                L10n.string("cycle_count", table: "Analytics"),
                pointRecord.cycleCount)
            )
            .foregroundStyle(
              by: .value(
                L10n.string("device_name", table: "Common"), pointRecord.deviceName)
            )
            .symbol(.circle)
            .symbolSize(40)
          }
        }
      }
    }
    .chartForegroundStyleScale(
      domain: visibleDeviceNames,
      range: visibleDeviceColors
    )
    .chartXAxis {
      let (strideComponent, strideCount, labelFormat) =
        ChartAxisHelper.calculateXAxisStride(
          startDay: startDay, endDay: endDay, isCompact: horizontalSizeClass == .compact)

      AxisMarks(values: .stride(by: strideComponent, count: strideCount)) { value in
        AxisGridLine()
          .foregroundStyle(Color.primary.opacity(0.06))

        AxisValueLabel {
          if let date = value.as(Date.self) {
            switch labelFormat {
            case .monthDay:
              Text(date.formatted(.dateTime.month(.defaultDigits).day()))
            case .monthOnly:
              Text(date.formatted(.dateTime.month(.defaultDigits)))
            case .yearOnly:
              Text(date.formatted(.dateTime.year()))
            }
          }
        }
      }
    }
    .chartYScale(
      domain: 0...max(10, Double(visibleRecords.map { $0.cycleCount }.max() ?? 0) * 1.15)
    )
    .chartXScale(domain: startDay...(Calendar.current.date(byAdding: .day, value: 1, to: endDay) ?? endDay))
    .chartPlotStyle { plotArea in
      plotArea
        .clipped()
        .padding(.trailing, 24)
    }
    .chartLegend(dynamicTypeSize.isAccessibilitySize ? .hidden : .automatic)
    // Keep numeric axes legible without letting them consume the entire plot.
    // The external legend and the surrounding statistics retain the user's text size.
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    .mochiChartRendering()
    .frame(height: chartHeight)
  }
}

#Preview {
  CycleTrendView(
    allRecords: [],
    unit: .day
  )
}
