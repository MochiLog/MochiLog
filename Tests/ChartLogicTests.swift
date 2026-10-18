import Foundation

// Lightweight models allow the production date/axis utilities to run without an app or iCloud.
struct BatteryRecord {
  let id = UUID()
  let logDate: Date
  var deviceName = "iPhone"
  var cycleCount = 100
  var healthPercent = 95.0
  var nominalHealthPercent = 96.0
}
enum AppSettings {
  enum ChartUnit { case hour, day, week, month }
}
enum RangePreset {
  case auto, oneWeek, twoWeeks, oneMonth, threeMonths, sixMonths, oneYear, twoYears, threeYears
}

@main
struct ChartLogicTests {
  static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
  }
  static func main() {
    let end = day(2024, 3, 12)
    let week = ChartWindowNavigator.windowStart(for: end, range: .oneWeek, allRecords: [])
    assert(
      Calendar.current.dateComponents([.day], from: week, to: end).day == 6,
      "One week must contain exactly seven calendar days, including DST changes")
    assert(
      ChartWindowNavigator.windowStart(for: end, range: .twoWeeks, allRecords: [])
        == day(2024, 2, 28))

    let old = [BatteryRecord(logDate: day(2020, 2, 15))]
    assert(ChartWindowNavigator.initializeWindowEnd(for: old, range: .oneMonth) == day(2020, 2, 29))
    assert(
      ChartWindowNavigator.adjustedWindowEndForRangeChange(
        range: .sixMonths,
        currentEnd: end, records: old) == day(2020, 6, 30))

    let shuffled = [1, 20, 5, 15, 9].map { BatteryRecord(logDate: day(2024, 3, $0)) }
    let context = ChartWindowNavigator.visibleRecordsWithContext(
      in: shuffled,
      start: day(2024, 3, 8), end: day(2024, 3, 12))
    assert(
      context.map(\.logDate) == [5, 9, 15].map { day(2024, 3, $0) },
      "Context must use nearest neighbors regardless of input order")

    let sparse = [BatteryRecord(logDate: day(2024, 3, 5))]
    assert(
      ChartWindowNavigator.findPreviousWindowEnd(
        currentEnd: day(2024, 3, 25),
        range: .oneWeek, records: sparse) == day(2024, 3, 5),
      "Previous navigation must move backwards")
    let future = [BatteryRecord(logDate: day(2024, 5, 1))]
    let next = ChartWindowNavigator.findNextWindowEnd(
      currentEnd: day(2024, 3, 25),
      range: .oneWeek, records: future)!
    assert(
      ChartWindowNavigator.windowContainsData(
        start: ChartWindowNavigator.windowStart(for: next, range: .oneWeek, allRecords: future),
        end: next, in: future), "Jumping forward must include the record it jumps to")
    let years = [2021, 2023, 2025].map { BatteryRecord(logDate: day($0, 5, 1)) }
    let previous = ChartWindowNavigator.findPreviousWindowEnd(
      currentEnd: day(2025, 12, 31),
      range: .twoYears, records: years)!
    assert(previous == day(2023, 12, 31))
    assert(
      ChartWindowNavigator.findNextWindowEnd(
        currentEnd: previous,
        range: .twoYears, records: years) == day(2025, 12, 31))

    let autoDates = [day(2024, 2, 25), day(2024, 3, 12)]
    let auto = ChartWindowNavigator.computeChartWindow(
      recordDates: autoDates,
      windowEnd: autoDates[1], range: .auto)
    assert(
      auto.startDay <= autoDates[0] && auto.endDay >= autoDates[1],
      "Auto range must include data crossing calendar boundaries")

    let updatedAuto = ChartWindowNavigator.computeChartWindow(
      recordDates: autoDates + [day(2024, 4, 2)], windowEnd: autoDates[1], range: .auto)
    assert(
      updatedAuto.endDay == day(2024, 4, 2),
      "Auto must follow newly synced logs, not the old window end")
    let filteredAuto = ChartWindowNavigator.computeChartWindow(
      recordDates: [day(2020, 6, 3)], windowEnd: day(2024, 4, 2), range: .auto)
    assert(
      filteredAuto.endDay == day(2020, 6, 3),
      "Device filtering must remove trailing years of empty space")
    let futureDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
    let mixedAuto = ChartWindowNavigator.computeChartWindow(
      recordDates: autoDates + [futureDate], windowEnd: futureDate, range: .auto)
    assert(mixedAuto.endDay == autoDates[1], "Future logs must not extend Auto")
    assert(
      ChartWindowNavigator.initializeWindowEnd(
        for: autoDates.map { BatteryRecord(logDate: $0) },
        range: .auto) == autoDates[1], "Auto must end at latest log instead of a calendar boundary")
    let spanningYears = [day(2015, 12, 31), day(2024, 1, 1)]
    let longAuto = ChartWindowNavigator.computeChartWindow(
      recordDates: spanningYears,
      windowEnd: spanningYears[1], range: .auto)
    assert(longAuto.startDay <= spanningYears[0] && longAuto.endDay == spanningYears[1])
    let lateNight = Calendar.current.date(byAdding: .hour, value: 23, to: day(2024, 3, 1))!
    assert(
      ChartWindowNavigator.autoRange(forDates: [lateNight, day(2024, 3, 8)]) == .twoWeeks,
      "Eight calendar dates must not be classified as one week because of time of day")
    let emptyAuto = ChartWindowNavigator.computeChartWindow(
      recordDates: [], windowEnd: day(2020, 1, 1), range: .auto)
    assert(emptyAuto.startDay <= emptyAuto.endDay)
    let futureOnly = ChartWindowNavigator.computeChartWindow(
      recordDates: [futureDate], windowEnd: futureDate, range: .auto)
    assert(futureOnly.endDay == Calendar.current.startOfDay(for: Date()))

    let values = [95.0, 60, 98, 96, 94]
    let points = values.enumerated().map { index, value in
      BatteryRecord(logDate: day(2024, 3, index + 1), healthPercent: value)
    }
    let sampled = ChartAxisHelper.downsampledRecords(
      Array(points.reversed()),
      startDay: day(2024, 3, 1), endDay: day(2024, 3, 31))
    assert(sampled.contains { $0.healthPercent == 60 })
    assert(sampled.contains { $0.healthPercent == 98 })
    assert(sampled.first?.id == points.first?.id && sampled.last?.id == points.last?.id)
    var edited = points[0]
    let originalHash = ChartWindowNavigator.recordSignature([edited], selectedDevice: nil)
    edited.healthPercent = 70
    assert(
      ChartWindowNavigator.recordSignature([edited], selectedDevice: nil) != originalHash,
      "An edit with the same ID, count and date must invalidate the chart cache")
    print(
      "PASS: inclusive weeks, historical data, nearest context, sparse navigation, multi-year round trip, auto boundaries, extrema, endpoints and measurement edits"
    )
  }
}
