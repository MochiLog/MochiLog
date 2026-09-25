import Foundation

/// バッテリーレコード（永続化レイヤーに依存しないプレーンなモデルクラス）
/// iOS 17+: SwiftData (CurrentBatterySchema.BatteryRecord) で永続化
/// iOS 16:  CoreData (CDBatteryRecord) で永続化
final class BatteryRecord: Identifiable, Hashable {
  let id: UUID
  // --- 基本情報 ---
  // Default values added to satisfy CloudKit requirements (attributes must be optional or have defaults)
  var logDate: Date = Date()  // ログファイルの日付
  var deviceName: String = "Unknown"  // 機種名 (例: iPhone 15 Pro)
  var deviceModelCode: String?  // 内部モデル名 (例: iPhone16,1)
  var osVersion: String?  // os_version (例: iOS 18.0)
  var productSku: String?  // 販売地域コード (例: C/A, J/A)
  /// MochiLog が割り当てた個体 ID。旧記録は nil のまま保持する。
  var physicalDeviceID: UUID?

  // --- ハードウェア/製造情報 ---
  var storage: String?  // ストレージ容量
  var ram: String?  // RAM
  var manufactureDate: String?  // バッテリー製造月
  var firstUseDate: Date?  // 初使用日

  // --- カウント/容量 (mAh) ---
  var cycleCount: Int = 0  // 充放電回数
  var designCapacity: Int = 0  // 設計容量 (Design)
  var nominalCapacity: Int = 0  // 公称容量 (Nominal)
  var rawCapacity: Int = 0  // 実測容量 (Raw)
  var lowRateCapacity: Int?  // 低レート放電容量 (計算値)

  // --- 補正/計算値 ---
  var deflator: Double?  // デフレーター
  var settingsDisplayPercent: Int?  // 設定上の表示 (%) (計算値)
  var diagnosticResult: String?  // 診断結果 (例: "正常", "交換推奨")

  // --- 環境データ (日次) ---
  var avgTemp: Double?  // 平均温度
  var maxTemp: Double?  // 最大温度
  var minTemp: Double?  // 最低温度

  var maxVoltage: Double?  // 最大電圧
  var minVoltage: Double?  // 最低電圧

  var minSoC: Int?  // 最小充電%
  var maxSoC: Int?  // 最大充電%

  var createdAt: Date = Date()

  // MARK: - Hashable
  static func == (lhs: BatteryRecord, rhs: BatteryRecord) -> Bool {
    lhs.id == rhs.id
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  init(
    id: UUID = UUID(),
    logDate: Date,
    deviceName: String,
    deviceModelCode: String? = nil,
    osVersion: String? = nil,
    productSku: String? = nil,
    physicalDeviceID: UUID? = nil,
    storage: String? = nil,
    ram: String? = nil,
    manufactureDate: String? = nil,
    firstUseDate: Date? = nil,
    cycleCount: Int,
    designCapacity: Int,
    nominalCapacity: Int,
    rawCapacity: Int,
    lowRateCapacity: Int? = nil,
    deflator: Double? = nil,
    settingsDisplayPercent: Int? = nil,
    diagnosticResult: String? = nil,
    avgTemp: Double? = nil,
    maxTemp: Double? = nil,
    minTemp: Double? = nil,
    maxVoltage: Double? = nil,
    minVoltage: Double? = nil,
    minSoC: Int? = nil,
    maxSoC: Int? = nil
  ) {
    self.id = id
    self.logDate = logDate
    self.deviceName = deviceName
    self.deviceModelCode = deviceModelCode
    self.osVersion = osVersion
    self.productSku = productSku
    self.physicalDeviceID = physicalDeviceID
    self.storage = storage
    self.ram = ram
    self.manufactureDate = manufactureDate
    self.firstUseDate = firstUseDate
    self.cycleCount = cycleCount
    self.designCapacity = designCapacity
    self.nominalCapacity = nominalCapacity
    self.rawCapacity = rawCapacity
    self.lowRateCapacity = lowRateCapacity
    self.deflator = deflator
    self.settingsDisplayPercent = settingsDisplayPercent
    self.diagnosticResult = diagnosticResult
    self.avgTemp = avgTemp
    self.maxTemp = maxTemp
    self.minTemp = minTemp
    self.maxVoltage = maxVoltage
    self.minVoltage = minVoltage
    self.minSoC = minSoC
    self.maxSoC = maxSoC
  }

  // 互換性のための計算プロパティ（UI側から既存の名前で参照されているため）
  var date: Date {
    return logDate
  }

  var localizedDeviceName: String {
    DeviceLibrary.localizedName(for: deviceName)
  }

  var realCapacitymAh: Int {
    return rawCapacity
  }

  var designCapacitymAh: Int {
    return designCapacity
  }

  // SoC (チップ名) を機種名から自動取得
  var soc: String? {
    return DeviceLibrary.getSoC(for: deviceName)
  }

  // 表示上の最大容量(パーセント)。もし `settingsDisplayPercent` があればそれを使い、なければ
  // nominal と raw の比率から算出する（保険的に0で割らないようガード）。
  var maxCapacityPercent: Double {
    if let s = settingsDisplayPercent {
      return Double(s)
    }
    if nominalCapacity > 0 {
      return (Double(rawCapacity) / Double(nominalCapacity)) * 100.0
    }
    return 0.0
  }

  // 実際のヘルス（%）を UI 側の `realHealthPercent` として提供
  // 注意: これは「実測容量 / 公称容量」であり、通常は100%前後になります。
  // 本来の意味でのヘルス（劣化度）を表すものではなく、公称値に対するばらつきを表します。
  var realHealthPercent: Double {
    if nominalCapacity > 0 {
      return (Double(rawCapacity) / Double(nominalCapacity)) * 100.0
    }
    return 0.0
  }

  // 公称容量ベースのヘルス（%）(Nominal / Design)
  var nominalHealthPercent: Double {
    if designCapacity > 0 && nominalCapacity > 0 {
      return (Double(nominalCapacity) / Double(designCapacity)) * 100.0
    }
    // designCapacity が不明な場合：settingsDisplayPercent → healthPercent の順にフォールバック
    if let s = settingsDisplayPercent, s > 0 {
      return Double(s)
    }
    return healthPercent
  }

  // 設計容量ベースのヘルス（%）(Raw / Design)
  // これが本来の意味での「実測容量ベースの劣化度」を表します。
  var healthPercent: Double {
    if designCapacity > 0 {
      return (Double(rawCapacity) / Double(designCapacity)) * 100.0
    }
    return realHealthPercent
  }

  // 分析基準に応じた動的な診断結果を返す
  // AppSettings.analysisDataSource の設定に基づいて公称/実測のどちらで計算するか切り替える
  var dynamicDiagnosticResult: String {
    let health: Double
    if AppSettings.shared.analysisDataSource == .nominal {
      health = nominalHealthPercent
    } else {
      health = healthPercent
    }

    if health < 80.0 {
      return L10n.string("diag_replace_recommended", table: "Records")
    } else if health < 90.0 {
      return L10n.string("diag_slightly_degraded", table: "Records")
    } else {
      return L10n.string("diag_normal", table: "Records")
    }
  }

  // ContentView 等から使われている簡易イニシャライザに合わせた利便性イニシャライザ
  convenience init(
    date: Date,
    cycleCount: Int,
    maxCapacityPercent: Int,
    realCapacitymAh: Int,
    designCapacitymAh: Int,
    deviceName: String = "Unknown"
  ) {
    self.init(
      logDate: date,
      deviceName: deviceName,
      deviceModelCode: nil,
      osVersion: nil,
      storage: nil,
      ram: nil,
      manufactureDate: nil,
      firstUseDate: nil,
      cycleCount: cycleCount,
      designCapacity: designCapacitymAh,
      nominalCapacity: realCapacitymAh,
      rawCapacity: realCapacitymAh,
      lowRateCapacity: nil,
      deflator: nil,
      settingsDisplayPercent: maxCapacityPercent,
      diagnosticResult: nil,
      avgTemp: nil,
      maxTemp: nil,
      minTemp: nil,
      maxVoltage: nil,
      minVoltage: nil,
      minSoC: nil,
      maxSoC: nil
    )
  }
  // MARK: - Formatted Helpers
  var formattedStorage: String? {
    guard let raw = storage?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
      return nil
    }
    let s = raw.replacingOccurrences(of: " ", with: "")
    let lower = s.lowercased()
    if lower.contains("tb") { return s.replacingOccurrences(of: " ", with: " ") }

    // Remove "gb" and parse
    let numberPart = lower.replacingOccurrences(of: "gb", with: "")
    if let doubleValue = Double(numberPart), doubleValue >= 1024 {
      let tbValue = doubleValue / 1024.0
      // If it's effectively an integer (e.g. 1.0), print as integer, else 1.5
      let isInteger = tbValue.truncatingRemainder(dividingBy: 1) == 0
      return String(format: isInteger ? "%.0f TB" : "%.1f TB", tbValue)
    }
    return s.replacingOccurrences(of: "gb", with: " GB", options: .caseInsensitive)
  }

  var formattedRAM: String? {
    guard let raw = ram?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
      return nil
    }
    let s = raw.replacingOccurrences(of: " ", with: "")
    // e.g. "6GB" -> "6 GB"
    var formatted = s.replacingOccurrences(of: "gb", with: " GB", options: .caseInsensitive)

    if formatted == "7.5 GB" || formatted == "7 GB" {
      formatted = "8 GB"
    } else if formatted == "15 GB" {
      formatted = "16 GB"
    }

    return formatted
  }
  var cachedDiagnostic: String {
    dynamicDiagnosticResult
  }
}
