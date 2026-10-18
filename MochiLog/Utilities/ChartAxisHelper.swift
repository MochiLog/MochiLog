import Foundation
import SwiftUI

// MARK: - チャート軸ヘルパー
/// チャートの横軸ラベル表示とデータポイント表示に関する共通ロジック
struct ChartAxisHelper {

  // MARK: - データポイント表示判定

  /// 期間に応じて「何日ごとに1点」かを決定
  /// - Parameters:
  ///   - startDay: 表示開始日
  ///   - endDay: 表示終了日
  /// - Returns: 何日ごとに1点か（最低1日）
  static func pointIntervalDays(startDay: Date, endDay: Date) -> Int {
    let calendar = Calendar.current
    let displayDays = max(1, calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0)

    // 期間に応じて「何日ごとに1点」かを自動調整
    let intervalDays: Int
    switch displayDays {
    case 0...14:
      intervalDays = 1
    case 15...31:
      intervalDays = 5
    case 32...92:
      intervalDays = 4
    case 93...183:
      intervalDays = 7
    case 184...365:
      intervalDays = 14
    case 366...730:
      intervalDays = 30
    default:
      intervalDays = 45
    }
    return max(1, intervalDays)
  }

  /// 期間に応じてデータポイントを間引く
  /// - Parameters:
  ///   - records: 表示対象レコード
  ///   - startDay: 表示開始日
  ///   - endDay: 表示終了日
  /// - Returns: 表示するポイント用レコード
  static func downsampledRecords(
    _ records: [BatteryRecord],
    startDay: Date,
    endDay: Date
  ) -> [BatteryRecord] {
    let sorted = records.sorted { $0.logDate < $1.logDate }
    let intervalDays = pointIntervalDays(startDay: startDay, endDay: endDay)
    guard intervalDays > 1 else { return sorted }
    let calendar = Calendar.current
    var result: [BatteryRecord] = []
    for deviceRecords in Dictionary(grouping: sorted, by: \.deviceName).values {
      let buckets = Dictionary(grouping: deviceRecords) { record in
        (calendar.dateComponents(
          [.day], from: startDay,
          to: calendar.startOfDay(for: record.logDate)
        ).day ?? 0) / intervalDays
      }
      for bucket in buckets.values {
        // Keep endpoints and extrema: choosing only the first record hid drops and recoveries.
        var selected = [bucket.first!, bucket.last!]
        for key in [\BatteryRecord.healthPercent, \BatteryRecord.nominalHealthPercent] {
          selected.append(bucket.min { $0[keyPath: key] < $1[keyPath: key] }!)
          selected.append(bucket.max { $0[keyPath: key] < $1[keyPath: key] }!)
        }
        selected.append(bucket.min { $0.cycleCount < $1.cycleCount }!)
        selected.append(bucket.max { $0.cycleCount < $1.cycleCount }!)
        result.append(contentsOf: selected)
      }
    }
    var seen = Set<UUID>()
    return result.filter { seen.insert($0.id).inserted }.sorted { $0.logDate < $1.logDate }
  }

  /// 期間に応じてデータポイントのインデックスを間引く
  /// - Parameters:
  ///   - recordInfos: (date, deviceName) の配列
  ///   - startDay: 表示開始日
  ///   - endDay: 表示終了日
  ///   - maxPoints: 目標の最大点数
  /// - Returns: 表示するインデックス
  static func downsampledIndexes(
    recordInfos: [(date: Date, deviceName: String)],
    startDay: Date,
    endDay: Date,
    maxPoints: Int
  ) -> [Int] {
    let intervalDays = pointIntervalDays(startDay: startDay, endDay: endDay)
    let calendar = Calendar.current
    let visibleIndices = recordInfos.enumerated().compactMap { index, info in
      let d = calendar.startOfDay(for: info.date)
      return (d >= startDay && d <= endDay) ? index : nil
    }

    if visibleIndices.count <= maxPoints || intervalDays <= 1 {
      return visibleIndices
    }

    var buckets: [String: [Int: Int]] = [:]

    for index in visibleIndices {
      let info = recordInfos[index]
      let day = calendar.startOfDay(for: info.date)
      let diff = calendar.dateComponents([.day], from: startDay, to: day).day ?? 0
      let bucket = diff / intervalDays
      var deviceBuckets = buckets[info.deviceName] ?? [:]
      if deviceBuckets[bucket] == nil {
        deviceBuckets[bucket] = index
      }
      buckets[info.deviceName] = deviceBuckets
    }

    let indices = buckets
      .values
      .flatMap { deviceBuckets in
        deviceBuckets.keys.sorted().compactMap { deviceBuckets[$0] }
      }

    return indices.sorted { recordInfos[$0].date < recordInfos[$1].date }
  }

  // MARK: - 横軸ラベル間引き

  /// 横軸ラベルの間引きストライドとフォーマット指定を計算
  /// - Parameters:
  ///   - startDay: 表示開始日
  ///   - endDay: 表示終了日
  ///   - isCompact: コンパクト画面（iPhone）かどうか
  /// - Returns: (strideComponent, strideCount, labelFormat)
  static func calculateXAxisStride(
    startDay: Date, endDay: Date, isCompact: Bool
  ) -> (strideComponent: Calendar.Component, strideCount: Int, labelFormat: XAxisLabelFormat) {
    let calendar = Calendar.current
    let displayDays = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    let displayMonths = calendar.dateComponents([.month], from: startDay, to: endDay).month ?? 0

    // 表示期間に応じて適切な単位とストライドを決定
    let (strideComponent, strideCount): (Calendar.Component, Int)
    let labelFormat: XAxisLabelFormat

    if displayDays <= 7 {
      // 1週間以下: 日単位、1日ごと
      strideComponent = .day
      strideCount = 1
      labelFormat = .monthDay
    } else if displayDays <= 14 {
      // 2週間以下: 日単位、コンパクトなら2日ごと、レギュラーなら1日ごと
      strideComponent = .day
      strideCount = isCompact ? 2 : 1
      labelFormat = .monthDay
    } else if displayDays <= 30 {
      // 1ヶ月以下: 日単位、コンパクトなら3日ごと、レギュラーなら2日ごと
      strideComponent = .day
      strideCount = isCompact ? 3 : 2
      labelFormat = .monthDay
    } else if displayDays <= 60 {
      // 2ヶ月以下: 週単位、1週間ごと
      strideComponent = .weekOfYear
      strideCount = 1
      labelFormat = .monthDay
    } else if displayMonths <= 3 {
      // 3ヶ月以下: 週単位、2週間ごと
      strideComponent = .weekOfYear
      strideCount = 2
      labelFormat = .monthDay
    } else if displayMonths <= 6 {
      // 6ヶ月以下: 月単位、1ヶ月ごと
      strideComponent = .month
      strideCount = 1
      labelFormat = .monthDay
    } else if displayMonths <= 12 {
      // 1年以下: 月単位、コンパクトなら3ヶ月ごと、レギュラーなら2ヶ月ごと
      strideComponent = .month
      strideCount = isCompact ? 3 : 2
      labelFormat = .monthOnly
    } else if displayMonths <= 24 {
      // 2年以下: 月単位、コンパクトなら6ヶ月ごと、レギュラーなら4ヶ月ごと
      strideComponent = .month
      strideCount = isCompact ? 6 : 4
      labelFormat = .monthOnly
    } else if displayMonths <= 36 {
      // 3年以下: 年単位、1年ごと
      strideComponent = .year
      strideCount = 1
      labelFormat = .yearOnly
    } else {
      // 3年超: 年単位、1年ごと
      strideComponent = .year
      strideCount = 1
      labelFormat = .yearOnly
    }

    return (strideComponent, strideCount, labelFormat)
  }

  /// 横軸ラベルのフォーマット指定
  enum XAxisLabelFormat {
    case monthDay  // 月/日形式（例: 1/15）
    case monthOnly  // 月のみ（例: 3月）
    case yearOnly  // 年のみ（例: 2024年）
  }

  // MARK: - デバイス色パレット

  /// デバイス名に安定した色を割り当てるためのパレット
  static let deviceColorPalette: [Color] = [
    .blue, .green, .orange, .purple, .red, .pink, .cyan, .yellow, .mint, .indigo,
  ]

  /// ソート済みデバイス名に対応する色の配列を返す
  /// ページ切り替え時にデバイスの色が変わらないよう、全デバイス名のソート順で割り当てる
  static func stableDeviceColors(for sortedDeviceNames: [String]) -> [Color] {
    sortedDeviceNames.enumerated().map { index, _ in
      deviceColorPalette[index % deviceColorPalette.count]
    }
  }
}
