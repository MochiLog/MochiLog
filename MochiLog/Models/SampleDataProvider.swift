import Foundation

/// サンプルデータプロバイダー
/// データがない時のプレビュー用サンプルデータを生成
enum SampleDataProvider {

  /// サンプルデータの設定（3年分のデータ）
  private static let sampleDevices:
    [(
      name: String, modelCode: String, designCapacity: Int, startHealth: Double,
      currentHealth: Double, currentCycles: Int
    )] =
      [
        ("iPhone 15 Pro", "iPhone16,1", 3274, 100.0, 89.0, 420),
        ("iPhone 14", "iPhone14,7", 3279, 100.0, 82.5, 950),
        ("Apple Watch Series 9", "Watch7,3", 308, 100.0, 86.0, 580),
      ]

  /// 3年分のサンプルレコードを生成（非線形な変動を含む）
  static func generateSampleRecords() -> [BatteryRecord] {
    var records: [BatteryRecord] = []
    let calendar = Calendar.current
    let today = Date()

    for sampleDevice in sampleDevices {
      var device = sampleDevice
      #if DEBUG
      // Exercise a name whose localized display value differs from its stored chart key.
      if ProcessInfo.processInfo.environment["MOCHI_CHART_LOCALIZATION_TEST"] == "1",
        device.name == "iPhone 15 Pro" {
        device.name = "iPad Pro 11 (第1世代)"
        device.modelCode = "iPad8,1"
      }
      #endif
      // 3年分のデータを生成（月1回のレコード、計36レコード）
      var previousCycles = 0

      for monthOffset in stride(from: 35, through: 0, by: -1) {
        guard let logDate = calendar.date(byAdding: .month, value: -monthOffset, to: today) else {
          continue
        }

        // 進捗率（0 = 3年前、1 = 今日）
        let progress = Double(35 - monthOffset) / 35.0

        // ヘルスは非線形に減少（使い始めは緩やか、後半で加速）+ ランダム変動
        // 公称容量（Nominal）は滑らかに減少
        // startHealth から currentHealth へ、非線形カーブで推移
        let progressDecay = pow(progress, 1.2)
        let currentNominalHealth =
          device.startHealth - (device.startHealth - device.currentHealth) * progressDecay
        let nominalCapacity = Int(Double(device.designCapacity) * (currentNominalHealth / 100.0))

        // 実測容量（Raw）は公称容量を基準に、大きなブレ（ノイズ）と外れ値を持つ
        // ノイズ: 通常 ±2.0% 程度のブレ（かなり大きい）
        var noisePercent = Double.random(in: -2.0...2.0)

        // 外れ値: 10%の確率でさらに大きくブレる（主に下振れ）
        if Int.random(in: 1...10) == 1 {
          noisePercent += Double.random(in: -5.0...(-1.0))
        }

        let currentRawHealth = currentNominalHealth + noisePercent
        let rawCapacity = Int(Double(device.designCapacity) * (currentRawHealth / 100.0))

        // サイクルカウントは非線形（季節変動、使用頻度の変化をシミュレート）
        // 夏と冬は使用量増加、春秋は少なめ
        let month = calendar.component(.month, from: logDate)
        let seasonalFactor: Double = {
          switch month {
          case 1, 2, 7, 8, 12: return 1.3  // 冬・夏は多い
          case 3, 4, 5, 9, 10, 11: return 0.85  // 春・秋は少なめ
          default: return 1.0
          }
        }()

        // 基本増加量 + 非線形性 + 季節変動 + ランダム
        let baseMonthlyIncrease = Double(device.currentCycles) / 36.0
        let nonLinearFactor = 0.7 + 0.6 * sin(progress * Double.pi * 2.5)  // うねり
        let monthlyIncrease = baseMonthlyIncrease * seasonalFactor * nonLinearFactor
        let randomCycleVariation = Double.random(in: -3...5)

        let currentCycles =
          monthOffset == 35
          ? 0 : previousCycles + max(Int(monthlyIncrease + randomCycleVariation), 5)
        previousCycles = currentCycles

        // 表示用ヘルス（設定画面での表示）は公称値をベースにするのが一般的
        let settingsDisplayPercent = Int(currentNominalHealth)

        // 温度：先に最低・最高を生成してから平均を計算
        let minTemp = Double.random(in: 1.0...25.0)
        let maxTemp = Double.random(in: 33.0...50.0)
        let avgTemp = (minTemp + maxTemp) / 2.0

        // 電圧：リチウムイオンバッテリーの現実的な範囲 (mV)
        let maxVoltage = Double.random(in: 4200...4350)
        let minVoltage = Double.random(in: 3000...3200)

        let record = BatteryRecord(
          logDate: logDate,
          deviceName: device.name,
          deviceModelCode: device.modelCode,
          osVersion: device.name.contains("Watch") ? "watchOS 11.0" : "iOS 18.0",
          storage: nil,
          ram: nil,
          manufactureDate: nil,
          firstUseDate: calendar.date(byAdding: .year, value: -3, to: today),
          cycleCount: currentCycles,
          designCapacity: device.designCapacity,
          nominalCapacity: nominalCapacity,
          rawCapacity: rawCapacity,
          lowRateCapacity: nil,
          deflator: nil,
          settingsDisplayPercent: settingsDisplayPercent,
          diagnosticResult: currentNominalHealth >= 80
            ? L10n.string("diag_normal", table: "Records") : L10n.string("diag_slightly_degraded", table: "Records"),
          avgTemp: avgTemp,
          maxTemp: maxTemp,
          minTemp: minTemp,
          maxVoltage: maxVoltage,
          minVoltage: minVoltage,
          minSoC: Int.random(in: 15...30),
          maxSoC: Int.random(in: 90...100)
        )
        records.append(record)
      }
    }

    // 日付順にソート（古い順 = 昇順）
    // StatisticsView で .last を取得した際に最新（現在に近い）データになるようにする
    return records.sorted { $0.logDate < $1.logDate }
  }

  /// サンプルデータのデバイス名一覧
  static var sampleDeviceNames: [String] {
    return sampleDevices.map { $0.name }
  }
}
