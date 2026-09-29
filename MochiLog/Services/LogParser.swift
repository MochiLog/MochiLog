import Foundation

struct LogParser {

  // 解析結果の入れ物
  struct ParseResult {
    // --- 基本 ---
    var failureDescription: String?
    var logDate: Date?
    var osVersion: String?
    var deviceModelCode: String?
    var productSku: String?

    // --- ハードウェア ---
    var storage: String?  // GB
    var ram: String?  // GB

    // --- バッテリー ---
    var cycleCount: Int?
    var designCapacity: Int?  // 設計
    var nominalCapacity: Int?  // 公称
    var rawCapacity: Int?  // 実測
    var lowRateCapacity: Int?  // 低レート

    // --- 計算値 ---
    var nominalRatio: Double?  // 公称 / 設計 (%)
    var rawRatio: Double?  // 実測 / 設計 (%)
    var lowRateRatio: Double?  // 低レート / 設計 (%)
    var deflator: Double?  // デフレータ
    var settingsDisplayPercent: Int?  // 設定上の表示

    // --- その他 ---
    var firstUseDate: Date?
    var avgTemp: Double?
    var maxTemp: Double?
    var minTemp: Double?
    var maxVoltage: Double?
    var minVoltage: Double?
    var dailyMaxSoC: Int?
    var dailyMinSoC: Int?

    var diagnosticResult: String?
    // 検出された識別子 (board id -> identifier から決定される場合あり)
    var detectedIdentifier: String?
    // 検出された board id (ログ中に直接見つかった文字列)
    var detectedBoardId: String?

    // バリデーション
    var isCapacityMismatch: Bool = false
    // エラーログが保存されたか
    var hasErrorSaved: Bool = false
  }

  // JSONデコード用の構造体（ログの中身に合わせる）
  private struct HeaderJSON: Codable {
    let timestamp: String?
    let os_version: String?
    let bug_type: String?
  }

  private struct HardwareJSON: Codable {
    let deviceCapacity: Int?  // GB
    let dramSize: Double?  // GB（7.5のような小数を含む）
    let productSku: String?
  }

  private struct BatteryJSON: Codable {
    struct Message: Codable {
      let last_value_CycleCount: Int?
      let last_value_DesignCapacity: Int?
      let last_value_NominalChargeCapacity: Int?
      let last_value_AppleRawMaxCapacity: Int?
      let last_value_MinimumQmax: Int?
      let last_value_MaximumCapacityPercent: Int?

      let last_value_AverageTemperature: Double?
      let last_value_MaximumTemperature: Double?
      let last_value_MinimumTemperature: Double?

      let last_value_MaximumPackVoltage: Double?
      let last_value_MinimumPackVoltage: Double?

      let last_value_DailyMaxSoc: Int?
      let last_value_DailyMinSoc: Int?

      let last_value_DOFU: Double?  // UNIX Time
      let last_value_TotalOperatingTime: Double?  // おそらくHours?
    }
    let message: Message?
    // モデル名はルートにあることが多いが、headerから取るか、ここにあれば使う
    let hardwareModel: String?  // "iPhone14,2" etc
  }

  // ★メインの解析関数
  static func parse(
    text: String,
    enableValidation: Bool = true,
    validationThreshold: Double = 10.0
  ) -> ParseResult {
    var result = ParseResult()
    var headerJSONString: String?
    var hardwareJSONString: String?
    var lastBatteryJSONString: String?
    var lastCompleteBatteryJSONString: String?

    // 1パスで必要なJSONを走査する
    text.enumerateLines { line, _ in
      if headerJSONString == nil, line.contains("timestamp") {
        headerJSONString = extractJSON(from: line)
      }

      if hardwareJSONString == nil, line.contains("deviceCapacity") {
        hardwareJSONString = extractJSON(from: line)
      }

      if line.contains("NominalChargeCapacity") {
        if let json = extractJSON(from: line) {
          lastBatteryJSONString = json
          // Watch logs can end with BatteryShutdownHistogram rows that contain
          // NominalChargeCapacity but no cycle count or raw capacity. Keep the
          // latest complete measurement instead of replacing it with that row.
          if let data = json.data(using: .utf8),
            let battery = try? JSONDecoder().decode(BatteryJSON.self, from: data),
            let message = battery.message,
            message.last_value_CycleCount != nil,
            let nominal = message.last_value_NominalChargeCapacity, nominal > 0,
            let raw = message.last_value_AppleRawMaxCapacity, raw > 0 {
            lastCompleteBatteryJSONString = json
          }
        }
      }
    }

    // 1. ヘッダー情報の取得 (timestamp, os_version)
    if let headerMatch = headerJSONString,
      let headerData = headerMatch.data(using: .utf8),
      let header = try? JSONDecoder().decode(HeaderJSON.self, from: headerData)
    {

      if let ts = header.timestamp {
        // ISO8601などの変換が必要だが、ここでは簡易的にFormatterを使用
        result.logDate = parseDate(ts)
      }
      result.osVersion = header.os_version
    }

    // 2. スペック情報の取得 (deviceCapacity, dramSize)
    if let hwMatch = hardwareJSONString,
      let hwData = hwMatch.data(using: .utf8),
      let hw = try? JSONDecoder().decode(HardwareJSON.self, from: hwData)
    {

      if let cap = hw.deviceCapacity { result.storage = "\(cap) GB" }
      if let dram = hw.dramSize {
        result.ram = dram.rounded() == dram ? "\(Int(dram)) GB" : "\(dram) GB"
      }
      result.productSku = hw.productSku?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // 3. バッテリー情報の取得 (最後に見つかったものだけ採用)
    guard let lastMatch = lastCompleteBatteryJSONString ?? lastBatteryJSONString,
      let batData = lastMatch.data(using: .utf8),
      let batObj = try? JSONDecoder().decode(BatteryJSON.self, from: batData),
      let msg = batObj.message,
      msg.last_value_CycleCount != nil,
      let nominalValue = msg.last_value_NominalChargeCapacity, nominalValue > 0,
      let rawValue = msg.last_value_AppleRawMaxCapacity, rawValue > 0
    else {

      let msg = lastBatteryJSONString == nil
        ? L10n.string("import_no_battery_measurements", table: "Home")
        : L10n.string("import_invalid_battery_format", table: "Home")
      result.failureDescription = msg
      // デバッグログは常に保存
      ErrorLogStore.shared.saveLog(message: msg, rawText: text)
      NotificationCenter.default.post(name: NSNotification.Name("ParseErrorSaved"), object: nil)
      result.hasErrorSaved = true
      return result
    }

    // --- 値の詰め込み ---

    // 機種名 (HardwareModel) - まずはJSONに含まれるモデルコードを格納
    let modelCode = batObj.hardwareModel
    result.deviceModelCode = modelCode
    result.detectedIdentifier = modelCode

    // 識別子から機種名を解決して設計容量を取得（まずはライブラリを参照、無ければログの設計容量をフォールバック）
    if let id = result.deviceModelCode,
      !id.isEmpty,
      let name = DeviceLibrary.getDeviceName(for: id),
      let cap = DeviceProfileStore.shared.capacityVariant(for: name, productSku: result.productSku)?.capacity ?? DeviceLibrary.getCapacity(for: name)
    {
      result.designCapacity = cap
    }

    // 各種容量
    let nominal = msg.last_value_NominalChargeCapacity ?? 0
    let raw = msg.last_value_AppleRawMaxCapacity ?? 0
    let lowRate = msg.last_value_MinimumQmax ?? 0

    // バリデーション: ライブラリの設計容量とログ内の値を比較（閾値はパーセント差）
    if enableValidation, let libraryCap = result.designCapacity, libraryCap > 0 {
      let logCapToCheck = msg.last_value_DesignCapacity ?? nominal
      if logCapToCheck > 0 {
        let diffPercent =
          abs(Double(logCapToCheck) - Double(libraryCap)) / Double(libraryCap) * 100.0
        if diffPercent > validationThreshold {
          result.isCapacityMismatch = true
        }
      }
    }

    result.cycleCount = msg.last_value_CycleCount
    result.nominalCapacity = nominal
    result.rawCapacity = raw
    result.lowRateCapacity = lowRate
    result.settingsDisplayPercent = msg.last_value_MaximumCapacityPercent

    // --- 計算処理 ---

    if let designCap = result.designCapacity, designCap > 0 {
      // 割合計算: (値 / 設計) * 100
      result.nominalRatio = (Double(nominal) / Double(designCap)) * 100
      result.rawRatio = (Double(raw) / Double(designCap)) * 100
      result.lowRateRatio = (Double(lowRate) / Double(designCap)) * 100
    }

    // デフレーター: 公称 / 実測
    if raw > 0 {
      result.deflator = (Double(nominal) / Double(raw)) * 100
    }

    // 温度 (maxとminは10で割る、avgは生値を使用)
    if let avgT = msg.last_value_AverageTemperature { result.avgTemp = avgT }
    if let maxT = msg.last_value_MaximumTemperature { result.maxTemp = maxT / 10.0 }
    if let minT = msg.last_value_MinimumTemperature { result.minTemp = minT / 10.0 }

    // 電圧
    result.maxVoltage = msg.last_value_MaximumPackVoltage
    result.minVoltage = msg.last_value_MinimumPackVoltage

    // SoC
    result.dailyMaxSoC = msg.last_value_DailyMaxSoc
    result.dailyMinSoC = msg.last_value_DailyMinSoc

    // 初使用日 (DOFU)
    if let dofu = msg.last_value_DOFU, dofu > 0 {
      let dofuDate = Date(timeIntervalSince1970: dofu)
      // 1970/1/1の場合は無視
      if dofuDate.timeIntervalSince1970 > 86400 {
        result.firstUseDate = dofuDate
      }
    }

    // 診断結果 (簡易ロジック) - ローカライズキーを使用
    if let health = result.rawRatio {
      if health < 80.0 {
        result.diagnosticResult = L10n.string("diag_replace_recommended", table: "Records")
      } else if health < 90.0 {
        result.diagnosticResult = L10n.string("diag_slightly_degraded", table: "Records")
      } else {
        result.diagnosticResult = L10n.string("diag_normal", table: "Records")
      }
    }

    // デバッグ: 重要フィールドが欠けている場合はログを保存
    var missingFields: [String] = []
    if result.logDate == nil { missingFields.append("logDate") }
    if result.cycleCount == nil { missingFields.append("cycleCount") }
    if result.nominalCapacity == nil || result.nominalCapacity == 0 {
      missingFields.append("nominalCapacity")
    }
    if result.rawCapacity == nil || result.rawCapacity == 0 { missingFields.append("rawCapacity") }
    if !missingFields.isEmpty {
      let format = L10n.string("log_parse_error_missing_fields", table: "Support")
      let message = String(format: format, missingFields.joined(separator: ", "))
      ErrorLogStore.shared.saveLog(message: message, rawText: text)
      NotificationCenter.default.post(name: NSNotification.Name("ParseErrorSaved"), object: nil)
      result.hasErrorSaved = true
    }

    return result
  }

  // --- ヘルパー関数: 行内のJSONブロック抽出 ---
  private static func extractJSON(from line: String) -> String? {
    guard let start = line.firstIndex(of: "{"),
      let end = line.lastIndex(of: "}")
    else {
      return nil
    }
    return String(line[start...end])
  }

  // 日付パース用
  private static func parseDate(_ str: String) -> Date? {
    LogDateParser.parse(str)
  }
}
