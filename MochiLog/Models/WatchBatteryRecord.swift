import Foundation

/// iPhoneとApple Watch間で共有するバッテリーレコードの軽量データモデル
/// Codableに準拠してWatch Connectivity経由でシリアライズ可能
struct WatchBatteryRecord: Codable, Identifiable, Hashable {
  // MARK: - 識別子

  /// 一意の識別子（デバイス名と日付から生成）
  var id: String {
    "\(deviceName)_\(logDateString)"
  }

  // MARK: - プロパティ

  /// デバイス名（例: iPhone 15 Pro）
  let deviceName: String

  /// ログ日付
  let logDate: Date

  /// ログ日付の文字列表現（ID生成用）
  private var logDateString: String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: logDate)
  }

  /// 充放電サイクル回数
  let cycleCount: Int

  /// 公称容量ベースのヘルス（%）
  let nominalHealthPercent: Double

  /// 実測容量ベースのヘルス（%）
  let healthPercent: Double

  /// 診断結果テキスト
  let diagnosticResult: String
  let diagnosticCode: String?

  // MARK: - BatteryRecordからの変換

  /// BatteryRecordから軽量なWatchBatteryRecordを生成
  /// - Parameter record: 変換元のBatteryRecord
  /// - Returns: Watch用の軽量レコード
  init(from record: BatteryRecord) {
    self.deviceName = record.deviceName
    self.logDate = record.logDate
    self.cycleCount = record.cycleCount
    self.nominalHealthPercent = record.nominalHealthPercent
    self.healthPercent = record.healthPercent
    self.diagnosticResult = record.dynamicDiagnosticResult
    let health =
      AppSettings.shared.analysisDataSource == .nominal
      ? record.nominalHealthPercent : record.healthPercent
    self.diagnosticCode =
      health < 80
      ? "diag_replace_recommended" : (health < 90 ? "diag_slightly_degraded" : "diag_normal")
  }

  // MARK: - Codable用イニシャライザ

  init(
    deviceName: String,
    logDate: Date,
    cycleCount: Int,
    nominalHealthPercent: Double,
    healthPercent: Double,
    diagnosticResult: String,
    diagnosticCode: String? = nil
  ) {
    self.deviceName = deviceName
    self.logDate = logDate
    self.cycleCount = cycleCount
    self.nominalHealthPercent = nominalHealthPercent
    self.healthPercent = healthPercent
    self.diagnosticResult = diagnosticResult
    self.diagnosticCode = diagnosticCode
  }
}
