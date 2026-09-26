import Charts
import Combine
import SwiftUI

struct HealthTrendView: View {
  let visibleRecords: [BatteryRecord]
  let startDay: Date
  let endDay: Date
  let unit: AppSettings.ChartUnit
  @Binding var selectedRange: RangePreset
  let canMoveNext: Bool
  let canMovePrevious: Bool
  let shiftWindow: (Bool) -> Void
  let allDeviceNames: [String]  // 色の安定割り当て用（全デバイス名ソート済み）
  @State private var animateChart: Bool = false
  @State private var isChartReady: Bool = false  // 遅延レンダリング用

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let appSettings = AppSettings.shared
  @State private var analysisDataSource = AppSettings.shared.analysisDataSource

  var body: some View {
    let _ = print(
      "[Performance] HealthTrendView.body構築開始 - visibleRecords: \(visibleRecords.count)件")

    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text(
          L10n.string(analysisDataSource == .nominal
              ? "health_trend_nominal" : "health_trend_actual",
            table: "Analytics")
        )
        .font(.headline)


      }

      if visibleRecords.isEmpty {
        Text(L10n.string("no_records_for_device", table: "Analytics"))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding()
      } else {
        // チャートコントロール：範囲のみ（表示単位は親が決定）
        ChartRangeSelector(
          selectedRange: $selectedRange,
          canMoveNext: canMoveNext,
          canMovePrevious: canMovePrevious,
          shiftWindow: shiftWindow,
          startDay: startDay,
          endDay: endDay
        )

        if isChartReady {
          let chartRecords = ChartAxisHelper.downsampledRecords(
            visibleRecords, startDay: startDay, endDay: endDay)
          // 表示されているデバイス名とその色のマッピングを計算
          let visibleDeviceNames = Array(Set(chartRecords.map { $0.deviceName })).sorted()
          let visibleDeviceColors = visibleDeviceNames.map { deviceName -> Color in
            if let index = allDeviceNames.firstIndex(of: deviceName) {
              return ChartAxisHelper.deviceColorPalette[
                index % ChartAxisHelper.deviceColorPalette.count]
            }
            // フォールバック: allDeviceNamesにない場合はデバイス名のハッシュから色を選択
            print(
              "[Warning] Device '\(deviceName)' not found in allDeviceNames, using fallback color")
            let fallbackIndex = Int(UInt(bitPattern: deviceName.hashValue) % UInt(ChartAxisHelper.deviceColorPalette.count))
            return ChartAxisHelper.deviceColorPalette[fallbackIndex]
          }

          healthChartView(
            chartRecords: chartRecords, visibleDeviceNames: visibleDeviceNames,
            visibleDeviceColors: visibleDeviceColors
          )
          AccessibleChartLegend(names: visibleDeviceNames, colors: visibleDeviceColors)
        } else {
          Color.clear
            .frame(height: horizontalSizeClass == .regular ? 280 : 200)
        }

      }
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .padding()
    .mochiCard()
    .onAppear {
      // 次のランループでChart描画を開始（タブ切り替えアニメーションをブロックしない）
      if !isChartReady {
        DispatchQueue.main.async {
          isChartReady = true
        }
      }
    }
    .onReceive(appSettings.$analysisDataSource.removeDuplicates()) { newValue in
      if analysisDataSource != newValue {
        analysisDataSource = newValue
      }
    }
  }

  private var healthDomain: ClosedRange<Double> {
    let values = visibleRecords.map {
      analysisDataSource == .nominal ? $0.nominalHealthPercent : $0.healthPercent
    }.filter { $0.isFinite }
    return min(68, (values.min() ?? 68) - 3)...max(107, (values.max() ?? 107) + 3)
  }

  // MARK: - チャートビュー（bodyから分離してコンパイラの型チェック負荷を軽減）
  @ViewBuilder
  private func healthChartView(
    chartRecords: [BatteryRecord], visibleDeviceNames: [String], visibleDeviceColors: [Color]
  ) -> some View {
    Chart {
      ForEach(chartRecords) { record in
        LineMark(
          x: .value(
            L10n.string("date", table: "Common"),
            record.logDate),
          y: .value(
            L10n.string("real_capacity", table: "Analytics"),
            analysisDataSource == .nominal
              ? record.nominalHealthPercent : record.healthPercent)
        )
        .foregroundStyle(
          by: .value(L10n.string("device_name", table: "Common"), record.deviceName)
        )
        .interpolationMethod(.linear)
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
                L10n.string("real_capacity", table: "Analytics"),
                analysisDataSource == .nominal
                  ? pointRecord.nominalHealthPercent : pointRecord.healthPercent)
            )
            .foregroundStyle(
              by: .value(
                L10n.string("device_name", table: "Common"), pointRecord.deviceName)
            )
            .symbol(.circle)
          }
        }
      }
    }
    .chartForegroundStyleScale(
      domain: visibleDeviceNames,
      range: visibleDeviceColors
    )
    .chartLegend(.hidden)
    .chartYScale(domain: healthDomain)
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
    .chartXScale(domain: startDay...(Calendar.current.date(byAdding: .day, value: 1, to: endDay) ?? endDay))
    .chartYAxis {
      AxisMarks(values: .automatic(desiredCount: 5)) { value in
        AxisGridLine()
        AxisValueLabel {
          if let intValue = value.as(Double.self) {
            Text(intValue / 100, format: .percent.precision(.fractionLength(0)))
          }
        }
      }
    }
    .chartPlotStyle { plotArea in
      plotArea
        .clipped()
        .padding(.trailing, 24)
    }
    .mochiChartRendering()
    .frame(height: horizontalSizeClass == .regular ? 280 : 200)
  }
}

#Preview {
  HealthTrendView(
    visibleRecords: [],
    startDay: Date(),
    endDay: Date(),
    unit: .day,
    selectedRange: .constant(.oneMonth),
    canMoveNext: false,
    canMovePrevious: false,
    shiftWindow: { _ in },
    allDeviceNames: []
  )
}
