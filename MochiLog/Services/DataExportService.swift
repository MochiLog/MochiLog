import Foundation
import Yams

/// バッテリーレコードをYAML形式でエクスポートするサービス
struct DataExportService {

  /// エクスポートエラー
  enum ExportError: LocalizedError {
    case encodeError
    case writeError

    var errorDescription: String? {
      switch self {
      case .encodeError:
        return L10n.string("export_encode_error", table: "Settings")
      case .writeError:
        return L10n.string("export_write_error", table: "Settings")
      }
    }
  }

  /// エクスポートデータの構造体
  struct ExportData: Codable {
    let exportFormatVersion: String  // ファイル形式のバージョン（例: "1.0"）
    let exportDate: String
    let appVersion: String
    let recordCount: Int
    let records: [ExportRecord]
  }

  /// エクスポート用のレコード構造体
  struct ExportRecord: Codable {
    // 基本情報
    let logDate: String
    let deviceName: String
    let deviceModelCode: String?
    let osVersion: String?
    let productSku: String?
    let physicalDeviceID: UUID?

    // ハードウェア/製造情報
    let storage: String?
    let ram: String?
    let manufactureDate: String?
    let firstUseDate: String?

    // カウント/容量 (mAh)
    let cycleCount: Int
    let designCapacity: Int
    let nominalCapacity: Int
    let rawCapacity: Int
    let lowRateCapacity: Int?

    // 補正/計算値
    let deflator: Double?
    let settingsDisplayPercent: Int?
    let diagnosticResult: String?

    // 環境データ (日次)
    let avgTemp: Double?
    let maxTemp: Double?
    let minTemp: Double?
    let maxVoltage: Double?
    let minVoltage: Double?
    let minSoC: Int?
    let maxSoC: Int?

    let createdAt: String

    /// BatteryRecordから変換
    init(from record: BatteryRecord) {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

      self.logDate = formatter.string(from: record.logDate)
      self.deviceName = record.deviceName
      self.deviceModelCode = record.deviceModelCode
      self.osVersion = record.osVersion
      self.productSku = record.productSku
      self.physicalDeviceID = record.physicalDeviceID

      self.storage = record.storage
      self.ram = record.ram
      self.manufactureDate = record.manufactureDate
      self.firstUseDate = record.firstUseDate.map { formatter.string(from: $0) }

      self.cycleCount = record.cycleCount
      self.designCapacity = record.designCapacity
      self.nominalCapacity = record.nominalCapacity
      self.rawCapacity = record.rawCapacity
      self.lowRateCapacity = record.lowRateCapacity

      self.deflator = record.deflator
      self.settingsDisplayPercent = record.settingsDisplayPercent
      self.diagnosticResult = record.diagnosticResult

      self.avgTemp = record.avgTemp
      self.maxTemp = record.maxTemp
      self.minTemp = record.minTemp
      self.maxVoltage = record.maxVoltage
      self.minVoltage = record.minVoltage
      self.minSoC = record.minSoC
      self.maxSoC = record.maxSoC

      self.createdAt = formatter.string(from: record.createdAt)
    }
  }

  /// バッテリーレコードをYAML形式でエクスポート
  /// - Parameter records: エクスポートするレコードの配列
  /// - Returns: YAML形式の文字列
  /// - Throws: ExportError
  static func exportToYAML(records: [BatteryRecord]) throws -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let appVersion =
      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    let exportDate = formatter.string(from: Date())

    let exportRecords = records.map { ExportRecord(from: $0) }

    let exportData = ExportData(
      exportFormatVersion: "1.1",
      exportDate: exportDate,
      appVersion: appVersion,
      recordCount: records.count,
      records: exportRecords
    )

    // YAMLにエンコード
    let encoder = YAMLEncoder()
    encoder.options.sortKeys = false

    guard let yamlString = try? encoder.encode(exportData) else {
      throw ExportError.encodeError
    }

    // コメントヘッダーを追加
    let header = """
      # MochiLog バッテリーレコードエクスポート
      # ファイル形式バージョン: 1.1
      # エクスポート日時: \(exportDate)
      # アプリバージョン: \(appVersion)
      # レコード数: \(records.count)
      #
      # ==================== ファイル形式仕様 (v1.1) ====================
      #
      # トップレベルフィールド:
      #   exportFormatVersion: String (必須) - ファイル形式のバージョン
      #   exportDate: String (必須) - エクスポート日時 (ISO8601形式)
      #   appVersion: String (必須) - アプリのバージョン
      #   recordCount: Int (必須) - レコード数
      #   records: [ExportRecord] (必須) - バッテリーレコードの配列
      #
      # ExportRecordフィールド:
      #   【基本情報】
      #   logDate: String (必須) - ログ日付 (ISO8601形式)
      #   deviceName: String (必須) - デバイス名 (例: iPhone 15 Pro)
      #   deviceModelCode: String? (任意) - 内部モデル名 (例: iPhone16,1)
      #   osVersion: String? (任意) - OSバージョン (例: iOS 18.0)
      #   physicalDeviceID: UUID? (任意) - MochiLogの個体ID。旧記録はnull
      #   createdAt: String (必須) - レコード作成日時 (ISO8601形式)
      #
      #   【ハードウェア/製造情報】
      #   storage: String? (任意) - ストレージ容量 (例: 256GB)
      #   ram: String? (任意) - RAM容量 (例: 8GB)
      #   manufactureDate: String? (任意) - 製造日 (例: 2023-09)
      #   firstUseDate: String? (任意) - 初回使用日 (ISO8601形式)
      #
      #   【カウント/容量 (単位: mAh)】
      #   cycleCount: Int (必須) - 充放電回数
      #   designCapacity: Int (必須) - 設計容量
      #   nominalCapacity: Int (必須) - 公称容量
      #   rawCapacity: Int (必須) - 実測容量
      #   lowRateCapacity: Int? (任意) - 低レート容量
      #
      #   【補正/計算値】
      #   deflator: Double? (任意) - デフレーター係数
      #   settingsDisplayPercent: Int? (任意) - 設定表示パーセント
      #   diagnosticResult: String? (任意) - 診断結果
      #
      #   【環境データ (日次統計)】
      #   avgTemp: Double? (任意) - 平均温度 (℃)
      #   maxTemp: Double? (任意) - 最高温度 (℃)
      #   minTemp: Double? (任意) - 最低温度 (℃)
      #   maxVoltage: Double? (任意) - 最高電圧 (V)
      #   minVoltage: Double? (任意) - 最低電圧 (V)
      #   minSoC: Int? (任意) - 最低充電率 (%)
      #   maxSoC: Int? (任意) - 最高充電率 (%)
      #
      # 注意事項:
      #   - 日付はすべてISO8601形式 (例: 2026-02-15T00:00:00.000Z)
      #   - "?" が付いているフィールドは任意 (null可)
      #   - 容量の単位はすべて mAh
      #   - 温度の単位は℃、電圧の単位はV
      #
      # ================================================================

      """

    return header + yamlString
  }

  /// YAMLデータをファイルに保存
  /// - Parameters:
  ///   - yamlString: YAML形式の文字列
  ///   - url: 保存先URL
  /// - Throws: ExportError
  static func saveToFile(yamlString: String, url: URL) throws {
    do {
      try yamlString.write(to: url, atomically: true, encoding: .utf8)
    } catch {
      throw ExportError.writeError
    }
  }

  /// デフォルトのファイル名を生成
  /// - Returns: ファイル名（例: MochiLog_Export_2026-02-15.yaml）
  static func generateFileName() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let dateString = formatter.string(from: Date())
    return "MochiLog_Export_\(dateString).yaml"
  }
}
