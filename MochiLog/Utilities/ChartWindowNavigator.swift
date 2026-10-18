import Foundation

// MARK: - グラフウィンドウナビゲーションユーティリティ
/// グラフの期間移動に関する共通ロジック
struct ChartWindowNavigator {

  /// IDs alone cannot detect CloudKit updates to an existing record's measurements.
  static func recordSignature(_ records: [BatteryRecord], selectedDevice: String?) -> Int {
    var hasher = Hasher()
    for record in records {
      hasher.combine(record.id)
      hasher.combine(record.deviceName)
      hasher.combine(record.logDate)
      hasher.combine(record.cycleCount)
      hasher.combine(record.healthPercent)
      hasher.combine(record.nominalHealthPercent)
    }
    hasher.combine(selectedDevice)
    return hasher.finalize()
  }

  // MARK: - 共通チャート計算

  /// レンジに応じた実効レンジを決定（autoの場合のみ）
  static func effectiveRange(for recordDates: [Date], range: RangePreset) -> RangePreset {
    guard range == .auto else { return range }
    let now = Date()
    let pastDates = recordDates.filter { $0 <= now }
    return autoRange(forDates: pastDates)
  }

  /// レンジに応じた実効終了日を決定（autoの場合のみ、未来日を回避）
  static func effectiveEndDate(
    for recordDates: [Date],
    windowEnd: Date,
    range: RangePreset
  ) -> Date {
    guard range == .auto else { return windowEnd }
    let now = Date()
    // Auto always follows the latest eligible log, including newly synced records.
    return recordDates.filter { $0 <= now }.max() ?? now
  }

  /// recordDatesに基づいてウィンドウ開始・終了日と表示単位を計算
  static func computeChartWindow(
    recordDates: [Date],
    windowEnd: Date,
    range: RangePreset
  ) -> (startDay: Date, endDay: Date, unit: AppSettings.ChartUnit) {
    let calendar = Calendar.current
    let effectiveRange = effectiveRange(for: recordDates, range: range)
    let effectiveEnd = effectiveEndDate(for: recordDates, windowEnd: windowEnd, range: range)
    let startDate = windowStart(for: effectiveEnd, range: effectiveRange, allRecords: [])
    let automaticStart = recordDates.filter { $0 <= effectiveEnd }.min() ?? startDate
    let startDay = calendar.startOfDay(
      for: range == .auto ? min(startDate, automaticStart) : startDate)
    let endDay = calendar.startOfDay(for: effectiveEnd)

    let visibleDates = recordDates.filter {
      let d = calendar.startOfDay(for: $0)
      return d >= startDay && d <= endDay
    }

    let unit = autoUnit(forDates: visibleDates, startDay: startDay, endDay: endDay)
    return (startDay, endDay, unit)
  }

  /// レンジ変更時の終了日を共通で算出
  static func adjustedWindowEndForRangeChange(
    range: RangePreset,
    currentEnd: Date,
    records: [BatteryRecord]
  ) -> Date {
    if range == .auto { return initializeWindowEnd(for: records, range: range) }
    let end = alignedEnd(currentEnd, range: range)
    let start = windowStart(for: end, range: range, allRecords: records)
    return windowContainsData(start: start, end: end, in: records)
      ? end : initializeWindowEnd(for: records, range: range)
  }

  private static func alignedEnd(_ date: Date, range: RangePreset) -> Date {
    switch range {
    case .oneMonth: return endOfMonth(for: date)
    case .threeMonths: return endOfQuarter(for: date)
    case .sixMonths: return endOfHalfYear(for: date)
    case .oneYear, .twoYears, .threeYears: return endOfYear(for: date)
    default: return date
    }
  }

  // MARK: - 期間コンポーネント

  /// 選択されたレンジに対応するDateComponentsを返す
  static func periodComponent(for preset: RangePreset) -> DateComponents? {
    switch preset {
    case .auto:
      return nil
    case .oneWeek:
      return DateComponents(day: 7)
    case .twoWeeks:
      return DateComponents(day: 14)
    case .oneMonth:
      return DateComponents(month: 1)
    case .threeMonths:
      return DateComponents(month: 3)
    case .sixMonths:
      return DateComponents(month: 6)
    case .oneYear:
      return DateComponents(year: 1)
    case .twoYears:
      return DateComponents(year: 2)
    case .threeYears:
      return DateComponents(year: 3)
    }
  }

  // MARK: - ウィンドウ開始日計算

  /// 指定した終了日とレンジから開始日を計算
  static func windowStart(for endDate: Date, range: RangePreset, allRecords: [BatteryRecord])
    -> Date
  {
    let calendar = Calendar.current
    switch range {
    case .auto:
      // 自動：データ分布に応じた実効レンジを適用
      let effectiveRange = autoRange(for: allRecords)
      return windowStart(for: endDate, range: effectiveRange, allRecords: allRecords)
    case .oneWeek:
      return calendar.date(byAdding: .day, value: -6, to: endDate) ?? endDate
    case .twoWeeks:
      return calendar.date(byAdding: .day, value: -13, to: endDate) ?? endDate
    case .oneMonth:
      // カレンダー月に固定：終了日の月の1日を開始日とする
      let components = calendar.dateComponents([.year, .month], from: endDate)
      return calendar.date(from: components) ?? endDate
    case .threeMonths:
      // 四半期境界に固定：Q1(1-3月), Q2(4-6月), Q3(7-9月), Q4(10-12月)
      let month = calendar.component(.month, from: endDate)
      let year = calendar.component(.year, from: endDate)
      let quarterStartMonth = ((month - 1) / 3) * 3 + 1  // 1, 4, 7, 10
      var components = DateComponents()
      components.year = year
      components.month = quarterStartMonth
      components.day = 1
      return calendar.date(from: components) ?? endDate
    case .sixMonths:
      // 半年基準：前半（1-6月）か後半（7-12月）の開始月を返す
      let month = calendar.component(.month, from: endDate)
      let year = calendar.component(.year, from: endDate)
      var components = DateComponents()
      components.year = year
      components.month = month <= 6 ? 1 : 7  // 前半なら1月、後半なら7月
      components.day = 1
      return calendar.date(from: components) ?? endDate
    case .oneYear:
      // カレンダー年に固定：終了日の年の1月1日を開始日とする
      let components = calendar.dateComponents([.year], from: endDate)
      return calendar.date(from: components) ?? endDate
    case .twoYears:
      // 2年前の1月1日を開始日とする
      let year = calendar.component(.year, from: endDate)
      var components = DateComponents()
      components.year = year - 1
      components.month = 1
      components.day = 1
      return calendar.date(from: components) ?? endDate
    case .threeYears:
      // 2年前の1月1日を開始日とする（3年分表示）
      let year = calendar.component(.year, from: endDate)
      var components = DateComponents()
      components.year = year - 2
      components.month = 1
      components.day = 1
      return calendar.date(from: components) ?? endDate
    }
  }

  /// 指定した期間内にデータが存在するかチェック
  static func windowContainsData(start: Date, end: Date, in records: [BatteryRecord]) -> Bool {
    let cal = Calendar.current
    let startDay = cal.startOfDay(for: start)
    let endDay = cal.startOfDay(for: end)
    return records.contains {
      let d = cal.startOfDay(for: $0.logDate)
      return d >= startDay && d <= endDay
    }
  }

  /// 指定期間の前後1点ずつを含めたレコードを抽出（グラフの連続性を保つため）
  /// 各デバイスごとにウィンドウの前後にある最寄りデータを含めて補間描画を可能にする
  static func visibleRecordsWithContext(
    in records: [BatteryRecord],
    start: Date,
    end: Date
  ) -> [BatteryRecord] {
    let cal = Calendar.current
    let startDay = cal.startOfDay(for: start)
    let endDay = cal.startOfDay(for: end)

    // デバイスごとにグループ化
    let deviceGroups = Dictionary(grouping: records) { $0.deviceName }
    var result: [BatteryRecord] = []

    for (_, unsortedRecords) in deviceGroups {
      let deviceRecords = unsortedRecords.sorted { $0.logDate < $1.logDate }
      // このデバイスのウィンドウ内のレコード
      let visibleRecords = deviceRecords.filter {
        let d = cal.startOfDay(for: $0.logDate)
        return d >= startDay && d <= endDay
      }

      // ウィンドウ内のレコードを追加
      result.append(contentsOf: visibleRecords)

      // このデバイスのウィンドウ前の最寄りデータ
      if let beforeRecord = deviceRecords.last(where: {
        cal.startOfDay(for: $0.logDate) < startDay
      }) {
        result.append(beforeRecord)
      }

      // このデバイスのウィンドウ後の最寄りデータ
      if let afterRecord = deviceRecords.first(where: {
        cal.startOfDay(for: $0.logDate) > endDay
      }) {
        result.append(afterRecord)
      }
    }

    return result.sorted { $0.logDate < $1.logDate }
  }

  // MARK: - 日付計算ヘルパー

  /// DateComponentsを倍数で加算
  static func dateByAdding(_ comp: DateComponents, multiplier: Int, to date: Date) -> Date? {
    var c = DateComponents()
    if let d = comp.day { c.day = d * multiplier }
    if let m = comp.month { c.month = m * multiplier }
    if let y = comp.year { c.year = y * multiplier }
    if let h = comp.hour { c.hour = h * multiplier }
    return Calendar.current.date(byAdding: c, to: date)
  }

  /// 指定した日付が含まれる月の末日を取得
  static func endOfMonth(for date: Date) -> Date {
    let calendar = Calendar.current
    // 月の1日を取得
    let components = calendar.dateComponents([.year, .month], from: date)
    guard let firstOfMonth = calendar.date(from: components) else { return date }
    // 翌月の1日から1日引いて末日を取得
    guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth),
      let endOfMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth)
    else {
      return date
    }
    return endOfMonth
  }

  /// 指定した日付が含まれる年の末日（12月31日）を取得
  static func endOfYear(for date: Date) -> Date {
    let calendar = Calendar.current
    // 年の1月1日を取得
    var components = calendar.dateComponents([.year], from: date)
    components.month = 12
    components.day = 31
    return calendar.date(from: components) ?? date
  }

  /// 指定した日付が含まれる四半期の末日を取得
  static func endOfQuarter(for date: Date) -> Date {
    let calendar = Calendar.current
    let month = calendar.component(.month, from: date)
    let year = calendar.component(.year, from: date)
    // 四半期の最終月を計算（3, 6, 9, 12）
    let quarterEndMonth = ((month - 1) / 3 + 1) * 3
    var components = DateComponents()
    components.year = year
    components.month = quarterEndMonth + 1  // 翌月の1日
    components.day = 1
    guard let firstOfNextMonth = calendar.date(from: components),
      let endOfQuarter = calendar.date(byAdding: .day, value: -1, to: firstOfNextMonth)
    else {
      return date
    }
    return endOfQuarter
  }

  /// 指定した日付が含まれる半年（四半期2つ分）の末日を取得
  /// 1-6月 → 6月30日、7-12月 → 12月31日
  static func endOfHalfYear(for date: Date) -> Date {
    let calendar = Calendar.current
    let month = calendar.component(.month, from: date)
    let year = calendar.component(.year, from: date)

    // 前半（1-6月）か後半（7-12月）かを判定
    if month <= 6 {
      // 前半 → 6月30日
      var components = DateComponents()
      components.year = year
      components.month = 6
      components.day = 30
      return calendar.date(from: components) ?? date
    } else {
      // 後半 → 12月31日
      var components = DateComponents()
      components.year = year
      components.month = 12
      components.day = 31
      return calendar.date(from: components) ?? date
    }
  }

  // MARK: - 次のウィンドウ検索

  /// 次の（未来方向の）ウィンドウ終了日を検索
  /// まず1期間分先にステップし、データがなければ最寄りの未来データにジャンプする
  static func findNextWindowEnd(
    currentEnd: Date,
    range: RangePreset,
    records: [BatteryRecord]
  ) -> Date? {
    let cal = Calendar.current
    let currentEndDay = cal.startOfDay(for: currentEnd)

    // 現在のウィンドウより先にデータがあるか確認
    let futureRecords = records.filter { cal.startOfDay(for: $0.logDate) > currentEndDay }
    guard !futureRecords.isEmpty else { return nil }

    // ステップ1: 1期間分先のウィンドウ終了日を計算
    let steppedEnd: Date?
    switch range {
    case .auto:
      return nil
    case .oneMonth:
      // 翌月の末日
      if let nextMonth = cal.date(byAdding: .month, value: 1, to: currentEnd) {
        steppedEnd = endOfMonth(for: nextMonth)
      } else {
        steppedEnd = nil
      }
    case .threeMonths:
      // 次の四半期の末日
      if let nextQuarter = cal.date(byAdding: .month, value: 3, to: currentEnd) {
        steppedEnd = endOfQuarter(for: nextQuarter)
      } else {
        steppedEnd = nil
      }
    case .sixMonths:
      // 次の半年の末日
      if let nextHalf = cal.date(byAdding: .month, value: 6, to: currentEnd) {
        steppedEnd = endOfHalfYear(for: nextHalf)
      } else {
        steppedEnd = nil
      }
    case .oneYear, .twoYears, .threeYears:
      // 翌年の末日
      let years = range == .threeYears ? 3 : range == .twoYears ? 2 : 1
      if let nextYear = cal.date(byAdding: .year, value: years, to: currentEnd) {
        steppedEnd = endOfYear(for: nextYear)
      } else {
        steppedEnd = nil
      }
    default:
      // oneWeek, twoWeeks: currentEndから1期間分足す
      if let comp = periodComponent(for: range) {
        steppedEnd = dateByAdding(comp, multiplier: 1, to: currentEnd)
      } else {
        steppedEnd = nil
      }
    }

    guard let newEnd = steppedEnd else { return nil }

    // ステップ2: 新しいウィンドウにデータが含まれるか確認
    let start = windowStart(for: newEnd, range: range, allRecords: records)
    if windowContainsData(start: start, end: newEnd, in: records) {
      return newEnd
    }

    // ステップ3: データがない場合、最寄りの未来データにジャンプ
    guard let nextDataDate = futureRecords.min(by: { $0.logDate < $1.logDate })?.logDate else {
      return nil
    }

    // 未来データを含むウィンドウの終了日を決定
    switch range {
    case .oneMonth: return endOfMonth(for: nextDataDate)
    case .threeMonths: return endOfQuarter(for: nextDataDate)
    case .sixMonths: return endOfHalfYear(for: nextDataDate)
    case .oneYear, .twoYears, .threeYears: return endOfYear(for: nextDataDate)
    default:
      let days = range == .twoWeeks ? 13 : 6
      return cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: nextDataDate))
        ?? nextDataDate
    }
  }

  // MARK: - 前のウィンドウ検索

  /// 前の（過去方向の）ウィンドウ終了日を検索
  /// まず1期間分前にステップし、データがなければ最寄りの過去データにジャンプする
  static func findPreviousWindowEnd(
    currentEnd: Date,
    range: RangePreset,
    records: [BatteryRecord]
  ) -> Date? {
    let cal = Calendar.current

    // ステップ1: 1期間分前のウィンドウ終了日を計算
    let steppedEnd: Date?
    switch range {
    case .auto:
      return nil
    case .oneMonth:
      // 前月の末日: 現在の月の1日の1日前
      let components = cal.dateComponents([.year, .month], from: currentEnd)
      if let firstOfMonth = cal.date(from: components),
        let prevMonthEnd = cal.date(byAdding: .day, value: -1, to: firstOfMonth)
      {
        steppedEnd = endOfMonth(for: prevMonthEnd)
      } else {
        steppedEnd = nil
      }
    case .threeMonths:
      // 前四半期の末日
      let currentStart = windowStart(for: currentEnd, range: range, allRecords: records)
      if let prevDay = cal.date(byAdding: .day, value: -1, to: currentStart) {
        steppedEnd = endOfQuarter(for: prevDay)
      } else {
        steppedEnd = nil
      }
    case .sixMonths:
      // 前半年の末日
      let currentStart = windowStart(for: currentEnd, range: range, allRecords: records)
      if let prevDay = cal.date(byAdding: .day, value: -1, to: currentStart) {
        steppedEnd = endOfHalfYear(for: prevDay)
      } else {
        steppedEnd = nil
      }
    case .oneYear, .twoYears, .threeYears:
      // 前年の末日
      let currentStart = windowStart(for: currentEnd, range: range, allRecords: records)
      if let prevDay = cal.date(byAdding: .day, value: -1, to: currentStart) {
        steppedEnd = endOfYear(for: prevDay)
      } else {
        steppedEnd = nil
      }
    default:
      // oneWeek, twoWeeks: currentEndから1期間分引く
      if let comp = periodComponent(for: range) {
        steppedEnd = dateByAdding(comp, multiplier: -1, to: currentEnd)
      } else {
        steppedEnd = nil
      }
    }

    guard let newEnd = steppedEnd else { return nil }

    // ステップ2: 新しいウィンドウにデータが含まれるか確認
    let start = windowStart(for: newEnd, range: range, allRecords: records)
    if windowContainsData(start: start, end: newEnd, in: records) {
      return newEnd
    }

    // ステップ3: データがない場合、最寄りの過去データにジャンプ
    let currentStart = windowStart(for: currentEnd, range: range, allRecords: records)
    let currentStartDay = cal.startOfDay(for: currentStart)
    let pastRecords = records.filter { cal.startOfDay(for: $0.logDate) < currentStartDay }
    guard let prevDataDate = pastRecords.max(by: { $0.logDate < $1.logDate })?.logDate else {
      return nil
    }

    // 過去データを含むウィンドウの終了日を決定
    switch range {
    case .oneMonth: return endOfMonth(for: prevDataDate)
    case .threeMonths: return endOfQuarter(for: prevDataDate)
    case .sixMonths: return endOfHalfYear(for: prevDataDate)
    case .oneYear, .twoYears, .threeYears: return endOfYear(for: prevDataDate)
    default:
      return cal.startOfDay(for: prevDataDate)
    }
  }

  // MARK: - ウィンドウ移動

  /// ウィンドウを前後に移動し、新しい終了日を返す
  static func shiftWindow(
    currentEnd: Date,
    backward: Bool,
    range: RangePreset,
    records: [BatteryRecord]
  ) -> Date {
    if backward {
      return findPreviousWindowEnd(currentEnd: currentEnd, range: range, records: records)
        ?? currentEnd
    } else {
      return findNextWindowEnd(currentEnd: currentEnd, range: range, records: records) ?? currentEnd
    }
  }

  // MARK: - 移動可否判定

  /// 次へ移動可能かどうか
  static func canMoveNext(currentEnd: Date, range: RangePreset, records: [BatteryRecord]) -> Bool {
    findNextWindowEnd(currentEnd: currentEnd, range: range, records: records) != nil
  }

  /// 前へ移動可能かどうか
  static func canMovePrevious(currentEnd: Date, range: RangePreset, records: [BatteryRecord])
    -> Bool
  {
    findPreviousWindowEnd(currentEnd: currentEnd, range: range, records: records) != nil
  }

  /// 最もデータが密集しているウィンドウを探索する
  static func findWindowWithMostData(
    in records: [BatteryRecord],
    range: RangePreset
  ) -> Date? {
    guard !records.isEmpty else { return nil }

    // レコードが少なすぎる場合は単純に最後を返す
    if records.count <= 2 {
      return records.last?.logDate
    }

    let cal = Calendar.current
    var maxCount = 0
    var bestEnd: Date?

    // 探索のステップを決定（レンジが長い場合は大雑把に）
    // 基本は各レコードを終了日候補としてスライディングウィンドウを試す
    // パフォーマンスのため、最大100個程度の候補に絞る
    let step = max(1, records.count / 100)

    for i in stride(from: records.count - 1, through: 0, by: -step) {
      let candidateEnd = records[i].logDate
      let candidateStart = windowStart(for: candidateEnd, range: range, allRecords: records)

      let startDay = cal.startOfDay(for: candidateStart)
      let endDay = cal.startOfDay(for: candidateEnd)

      // このウィンドウに含まれるレコード数をカウント
      let count = records.filter {
        let d = cal.startOfDay(for: $0.logDate)
        return d >= startDay && d <= endDay
      }.count

      if count > maxCount {
        maxCount = count
        bestEnd = candidateEnd
      }
    }

    return bestEnd
  }

  // MARK: - 自動レンジ決定

  /// データ分布に基づいて初期レンジを決定
  static func autoRange(for records: [BatteryRecord]) -> RangePreset {
    autoRange(forDates: records.map(\.logDate))
  }

  /// 日付配列に基づいて初期レンジを決定
  static func autoRange(forDates recordDates: [Date]) -> RangePreset {
    guard let first = recordDates.min(), let last = recordDates.max() else { return .oneMonth }
    let calendar = Calendar.current
    let days =
      calendar.dateComponents(
        [.day], from: calendar.startOfDay(for: first),
        to: calendar.startOfDay(for: last)
      ).day ?? 0

    if days < 7 { return .oneWeek }
    if days < 14 { return .twoWeeks }
    if days <= 30 { return .oneMonth }
    if days <= 90 { return .threeMonths }
    if days <= 180 { return .sixMonths }
    if days <= 365 { return .oneYear }
    if days <= 730 { return .twoYears }
    return .threeYears
  }

  // MARK: - 自動単位決定

  /// 期間に応じて表示単位を決定
  static func autoUnit(for records: [BatteryRecord], startDay: Date, endDay: Date)
    -> AppSettings.ChartUnit
  {
    let calendar = Calendar.current
    let days = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    let count = records.count

    if days <= 2 && count > 24 { return .hour }
    if days <= 14 { return .day }
    if days <= 120 { return .day }
    if days <= 730 { return .week }
    return .month
  }

  /// 日付配列に基づいて表示単位を決定
  static func autoUnit(forDates dates: [Date], startDay: Date, endDay: Date)
    -> AppSettings.ChartUnit
  {
    let calendar = Calendar.current
    let days = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    let count = dates.count

    if days <= 2 && count > 24 { return .hour }
    if days <= 14 { return .day }
    if days <= 120 { return .day }
    if days <= 730 { return .week }
    return .month
  }

  // MARK: - ウィンドウ終了日初期化

  /// レコードに基づいてウィンドウ終了日を初期化
  static func initializeWindowEnd(for records: [BatteryRecord], range: RangePreset) -> Date {
    if range == .auto {
      return effectiveEndDate(for: records.map(\.logDate), windowEnd: Date(), range: .auto)
    }
    guard let latest = records.max(by: { $0.logDate < $1.logDate })?.logDate else { return Date() }
    let nowEnd = alignedEnd(Date(), range: range)
    let start = windowStart(for: nowEnd, range: range, allRecords: records)
    if windowContainsData(start: start, end: nowEnd, in: records) { return nowEnd }
    return alignedEnd(latest, range: range)
  }
}
