import Foundation
import Yams

/// YAMLファイルからバッテリーレコードをインポートするサービス
struct DataImportService {

  /// インポートエラー
  enum ImportError: LocalizedError {
    case fileReadError
    case decodeError
    case invalidData
    case noRecords
    case unsupportedFormatVersion(String)

    var errorDescription: String? {
      switch self {
      case .fileReadError:
        return L10n.string("import_file_read_error", table: "Settings")
      case .decodeError:
        return L10n.string("import_decode_error", table: "Settings")
      case .invalidData:
        return L10n.string("import_invalid_data", table: "Settings")
      case .noRecords:
        return L10n.string("import_no_records", table: "Settings")
      case .unsupportedFormatVersion(let version):
        return L10n.string("import_unsupported_version", table: "Settings")
          .replacingOccurrences(of: "{version}", with: version)
      }
    }
  }

  /// インポート結果
  struct ImportResult {
    let totalRecords: Int
    let importedRecords: Int
    let skippedDuplicates: Int
    let errors: [String]

    var hasErrors: Bool {
      !errors.isEmpty
    }

    var successCount: Int {
      importedRecords
    }
  }

  // MARK: - バックグラウンド処理用の中間値型（Sendable）

  /// バックグラウンドで変換されたレコードの中間データ（@MainActor に依存しない値型）
  private struct ConvertedRecord: Sendable {
    let logDate: Date
    var deviceName: String
    var deviceModelCode: String?
    let osVersion: String?
    let productSku: String?
    let physicalDeviceID: UUID?
    let storage: String?
    let ram: String?
    let manufactureDate: String?
    let firstUseDate: Date?
    let cycleCount: Int
    let designCapacity: Int
    let nominalCapacity: Int
    let rawCapacity: Int
    let lowRateCapacity: Int?
    let deflator: Double?
    let settingsDisplayPercent: Int?
    let diagnosticResult: String?
    let avgTemp: Double?
    let maxTemp: Double?
    let minTemp: Double?
    let maxVoltage: Double?
    let minVoltage: Double?
    let minSoC: Int?
    let maxSoC: Int?
  }

  /// YAMLファイルからデータをインポート（マルチスレッド対応）
  /// - Parameters:
  ///   - url: YAMLファイルのURL
  ///   - dataStore: データストア
  ///   - existingRecords: 既存のレコード（重複チェック用）
  ///   - allowDuplicates: 重複を許可するかどうか
  ///   - progressHandler: 進捗を通知するハンドラー（0.0〜1.0、MainActorから呼ばれる）
  /// - Returns: インポート結果
  /// - Throws: ImportError
  static func importFromYAML(
    url: URL,
    dataStore: DataStore,
    existingRecords: [BatteryRecord],
    allowDuplicates: Bool,
    progressHandler: (@MainActor (Double) -> Void)? = nil
  ) async throws -> ImportResult {

    // フェーズ1: ファイル読み込み（バックグラウンド）
    // String(contentsOf:) はスレッドセーフなので Task.detached で実行可能
    let yamlString: String = try await Task.detached(priority: .userInitiated) {
      guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        throw ImportError.fileReadError
      }
      return content
    }.value

    // 進捗: 10%（ファイル読み込み完了）
    await MainActor.run { progressHandler?(0.10) }

    // フェーズ2: YAMLデコード（メインスレッド）
    // ExportData.Decodable が @MainActor に隔離されているため MainActor.run でラップして呼び出す
    let (exportFormatVersion, appVersion, exportRecords): (String, String, [DataExportService.ExportRecord]) =
      try await MainActor.run { try decodeYAML(yamlString) }

    // レコードが空でないか確認
    guard !exportRecords.isEmpty else {
      throw ImportError.noRecords
    }

    // バージョンチェック
    try validateFormatVersion(exportFormatVersion)

    // 進捗: 20%（YAMLデコード完了）
    await MainActor.run { progressHandler?(0.20) }

    let totalCount = exportRecords.count
    let needsMagSafeMigration = compareVersion(appVersion, lessThan: "3.0.0")

    // フェーズ3: 既存レコードのインデックスをバックグラウンドで構築（重複チェック高速化）
    // BatteryRecord のプロパティ（logDate, deviceName）が @MainActor 隔離のため
    // 既存レコードのインデックス構築はメインスレッドから値を取り出してバックグラウンドへ渡す

    // メインスレッドで既存レコードの (deviceName, date) ペアを値型として抽出
    typealias RecordKey = String
    let existingKeys: Set<RecordKey> = await MainActor.run {
      if allowDuplicates { return Set<RecordKey>() }
      let calendar = Calendar.current
      var index = Set<RecordKey>()
      for record in existingRecords {
        let components = calendar.dateComponents([.year, .month, .day], from: record.logDate)
        let identity = record.physicalDeviceID.map { "id:\($0.uuidString)" }
          ?? "legacy:\(record.deviceName)"
        let key = "\(identity)|\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        index.insert(key)
      }
      return index
    }

    // 進捗: 30%（インデックス作成完了）
    await MainActor.run { progressHandler?(0.30) }

    // フェーズ4: ExportRecord → ConvertedRecord（値型・Sendable）へのバックグラウンド並列変換
    // ConvertedRecord は @MainActor に依存しないため Task.detached / TaskGroup で安全に使える
    let calendar = Calendar.current

    typealias BatchResult = (index: Int, records: [ConvertedRecord], skips: Int, errors: [String])

    let batchSize = max(1, totalCount / 8)
    let batches = stride(from: 0, to: totalCount, by: batchSize).enumerated().map {
      ($0.offset, Array(exportRecords[$0.element..<min($0.element + batchSize, totalCount)]))
    }

    let convertedBatches: [BatchResult] = try await withThrowingTaskGroup(of: BatchResult.self) { group in
      for (batchIndex, batch) in batches {
        group.addTask {
          var converted: [ConvertedRecord] = []
          var skipCount = 0
          var errors: [String] = []

          let formatter = ISO8601DateFormatter()
          formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

          for exportRecord in batch {
            // ExportRecord → ConvertedRecord（値型のみ、@MainActor 不要）
            guard let logDate = formatter.date(from: exportRecord.logDate) else {
              errors.append("Invalid date: \(exportRecord.logDate)")
              continue
            }

            let firstUseDate = exportRecord.firstUseDate.flatMap { formatter.date(from: $0) }

            var record = ConvertedRecord(
              logDate: logDate,
              deviceName: exportRecord.deviceName,
              deviceModelCode: exportRecord.deviceModelCode,
              osVersion: exportRecord.osVersion,
              productSku: exportRecord.productSku,
              physicalDeviceID: exportRecord.physicalDeviceID,
              storage: exportRecord.storage,
              ram: exportRecord.ram,
              manufactureDate: exportRecord.manufactureDate,
              firstUseDate: firstUseDate,
              cycleCount: exportRecord.cycleCount,
              designCapacity: exportRecord.designCapacity,
              nominalCapacity: exportRecord.nominalCapacity,
              rawCapacity: exportRecord.rawCapacity,
              lowRateCapacity: exportRecord.lowRateCapacity,
              deflator: exportRecord.deflator,
              settingsDisplayPercent: exportRecord.settingsDisplayPercent,
              diagnosticResult: exportRecord.diagnosticResult,
              avgTemp: exportRecord.avgTemp,
              maxTemp: exportRecord.maxTemp,
              minTemp: exportRecord.minTemp,
              maxVoltage: exportRecord.maxVoltage,
              minVoltage: exportRecord.minVoltage,
              minSoC: exportRecord.minSoC,
              maxSoC: exportRecord.maxSoC
            )

            // 3.0.0より古いデータ: iPhone Air MagSafe マイグレーション
            if needsMagSafeMigration && record.deviceName == "iPhone Air" {
              let isMagSafe = record.firstUseDate == nil
                && record.deflator == nil
                && (record.lowRateCapacity == nil || record.lowRateCapacity == 0)
                && record.rawCapacity == 0
              if isMagSafe {
                record.deviceName = "iPhone Air MagSafeバッテリー"
                record.deviceModelCode = "A3385"
              }
            }

            // 重複チェック（Set<String> インデックスを参照）
            if !allowDuplicates {
              let components = calendar.dateComponents([.year, .month, .day], from: record.logDate)
              let identity = record.physicalDeviceID.map { "id:\($0.uuidString)" }
                ?? "legacy:\(record.deviceName)"
              let key = "\(identity)|\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
              if existingKeys.contains(key) {
                skipCount += 1
                continue
              }
            }

            converted.append(record)
          }

          return (batchIndex, converted, skipCount, errors)
        }
      }

      var results: [BatchResult] = []
      for try await result in group {
        results.append(result)
      }
      return results.sorted { $0.index < $1.index }
    }

    // 進捗: 70%（変換完了）
    await MainActor.run { progressHandler?(0.70) }

    // フェーズ5: メインスレッドで DataStore に一括 insert + save
    // BatteryRecord 生成・insert・save はすべてメインスレッドで実行
    let insertResult: (Int, Int, [String]) = await MainActor.run {
      var importedCount = 0
      var skippedCount = 0
      var errors: [String] = []

      for batch in convertedBatches {
        skippedCount += batch.skips
        errors.append(contentsOf: batch.errors)

        for converted in batch.records {
          // ConvertedRecord → BatteryRecord（メインスレッド上で生成）
          let record = BatteryRecord(
            logDate: converted.logDate,
            deviceName: converted.deviceName,
            deviceModelCode: converted.deviceModelCode,
            osVersion: converted.osVersion,
            productSku: converted.productSku,
            physicalDeviceID: converted.physicalDeviceID,
            storage: converted.storage,
            ram: converted.ram,
            manufactureDate: converted.manufactureDate,
            firstUseDate: converted.firstUseDate,
            cycleCount: converted.cycleCount,
            designCapacity: converted.designCapacity,
            nominalCapacity: converted.nominalCapacity,
            rawCapacity: converted.rawCapacity,
            lowRateCapacity: converted.lowRateCapacity,
            deflator: converted.deflator,
            settingsDisplayPercent: converted.settingsDisplayPercent,
            diagnosticResult: converted.diagnosticResult,
            avgTemp: converted.avgTemp,
            maxTemp: converted.maxTemp,
            minTemp: converted.minTemp,
            maxVoltage: converted.maxVoltage,
            minVoltage: converted.minVoltage,
            minSoC: converted.minSoC,
            maxSoC: converted.maxSoC
          )
          dataStore.insert(record)
          importedCount += 1
        }
      }

      // 全レコード insert 後に1回だけ save（パフォーマンス最適化）
      if importedCount > 0 {
        dataStore.save()
      }

      return (importedCount, skippedCount, errors)
    }

    // 進捗: 100%（完了）
    await MainActor.run { progressHandler?(1.0) }

    return ImportResult(
      totalRecords: totalCount,
      importedRecords: insertResult.0,
      skippedDuplicates: insertResult.1,
      errors: insertResult.2
    )
  }

  // MARK: - ヘルパー

  /// YAMLをデコードして ExportData の各フィールドを返す
  /// ExportData.Decodable が @MainActor に隔離されているため MainActor.run で実行する
  /// YAMLデコード自体は高速なのでメインスレッドでも実用上問題ない
  @MainActor
  private static func decodeYAML(
    _ yamlString: String
  ) throws -> (String, String, [DataExportService.ExportRecord]) {
    let decoder = YAMLDecoder()
    do {
      let data = try decoder.decode(DataExportService.ExportData.self, from: yamlString)
      return (data.exportFormatVersion, data.appVersion, data.records)
    } catch {
      print("[DataImportService] YAML decode error: \(error)")
      throw ImportError.decodeError
    }
  }

  /// ファイル形式のバージョンを検証
  /// - Parameter version: ファイルのバージョン文字列
  /// - Throws: ImportError.unsupportedFormatVersion
  private static func validateFormatVersion(_ version: String) throws {
    // サポートされているバージョンのリスト
    let supportedVersions = ["1.0", "1.1"]

    guard supportedVersions.contains(version) else {
      throw ImportError.unsupportedFormatVersion(version)
    }

    // 将来的に、バージョンごとのマイグレーション処理をここに追加できます
    // 例:
    // if version == "1.0" {
    //   // バージョン1.0からのマイグレーション処理
    // else if version == "2.0" {
    //   // バージョン2.0からのマイグレーション処理
    // }
  }

  /// バージョン文字列を比較する（v1 < v2 なら true）
  private static func compareVersion(_ version: String, lessThan target: String) -> Bool {
    // "unknown" 等の場合は古いとみなす
    if version == "unknown" { return true }

    let v1 = version.split(separator: ".").compactMap { Int($0) }
    let v2 = target.split(separator: ".").compactMap { Int($0) }
    let maxCount = max(v1.count, v2.count)
    for i in 0..<maxCount {
      let a = i < v1.count ? v1[i] : 0
      let b = i < v2.count ? v2[i] : 0
      if a < b { return true }
      if a > b { return false }
    }
    return false // 同じバージョンの場合は false
  }
}
