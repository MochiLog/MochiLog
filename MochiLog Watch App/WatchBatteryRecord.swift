import Foundation

/// iPhoneとApple Watch間で共有するバッテリーレコードの軽量データモデル
/// Watch側用（BatteryRecordへの依存なし）
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

  // MARK: - 計算プロパティ

  /// ローカライズされた診断結果
  /// iPhone側から送信された日本語テキストを、Watch側の言語設定に応じて翻訳する
  var localizedDiagnosticResult: String {
    if let diagnosticCode,
      ["diag_normal", "diag_slightly_degraded", "diag_replace_recommended"].contains(diagnosticCode)
    {
      return L10n.text(diagnosticCode)
    }
    // 日本語テキストを対応する翻訳キーにマッピング
    let key: String
    if diagnosticResult.contains("正常") || diagnosticResult.contains("Normal") {
      key = "diag_normal"
    } else if diagnosticResult.contains("やや劣化") || diagnosticResult.contains("Slightly Degraded") {
      key = "diag_slightly_degraded"
    } else if diagnosticResult.contains("交換推奨") || diagnosticResult.contains("Replace Recommended")
    {
      key = "diag_replace_recommended"
    } else {
      // マッピングできない場合は元のテキストをそのまま返す
      return diagnosticResult
    }
    return L10n.text(key)
  }

  // MARK: - イニシャライザ

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
