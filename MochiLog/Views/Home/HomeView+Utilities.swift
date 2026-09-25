// HomeView+Utilities.swift
// ユーティリティメソッドをHomeViewから分離
import SwiftUI
import UIKit  // for UIImage in Bundle extension

// MARK: - Bundle Extension
extension Bundle {
  var icon: UIImage? {
    if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
      let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
      let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
      let lastIcon = iconFiles.last
    {
      return UIImage(named: lastIcon)
    }
    return nil
  }
}

// MARK: - ユーティリティ関数
extension HomeView {
  /// BatteryRecordを作成する
  func createRecord(
    from result: LogParser.ParseResult,
    deviceName: String,
    deviceModelCodeOverride: String? = nil,
    designCapacityOverride: Int? = nil
  ) -> BatteryRecord {
    let logDate = result.logDate ?? Date()
    let modelCodeUsed = deviceModelCodeOverride ?? result.deviceModelCode
    let designCapacityUsed = DeviceProfileStore.shared.capacityVariant(for: deviceName, productSku: result.productSku)?.capacity
      ?? designCapacityOverride ?? result.designCapacity ?? 0
    let record = BatteryRecord(
      logDate: logDate,
      deviceName: deviceName,
      deviceModelCode: modelCodeUsed,
      osVersion: result.osVersion,
      productSku: result.productSku,
      physicalDeviceID: PhysicalDeviceIdentityStore.identityForLocallyRecognizedLog(modelCode: modelCodeUsed),
      storage: result.storage,
      ram: result.ram,
      manufactureDate: nil,
      firstUseDate: result.firstUseDate,
      cycleCount: result.cycleCount ?? 0,
      designCapacity: designCapacityUsed,
      nominalCapacity: result.nominalCapacity ?? 0,
      rawCapacity: result.rawCapacity ?? 0,
      lowRateCapacity: result.lowRateCapacity,
      deflator: result.deflator,
      settingsDisplayPercent: result.settingsDisplayPercent,
      diagnosticResult: result.diagnosticResult,
      avgTemp: result.avgTemp,
      maxTemp: result.maxTemp,
      minTemp: result.minTemp,
      maxVoltage: result.maxVoltage,
      minVoltage: result.minVoltage,
      minSoC: result.dailyMinSoC,
      maxSoC: result.dailyMaxSoC
    )

    // If diagnostic result is missing but we have a design capacity, compute it from raw
    if record.diagnosticResult == nil && designCapacityUsed > 0 && record.rawCapacity > 0 {
      let rawRatio = (Double(record.rawCapacity) / Double(designCapacityUsed)) * 100.0
      if rawRatio < 80.0 {
        record.diagnosticResult = L10n.string("diag_replace_recommended", table: "Records")
      } else if rawRatio < 90.0 {
        record.diagnosticResult = L10n.string("diag_slightly_degraded", table: "Records")
      } else {
        record.diagnosticResult = L10n.string("diag_normal", table: "Records")
      }
    }

    return record
  }

  /// レコードを削除する
  func deleteRecords(_ items: [BatteryRecord]) {
    withAnimation(.snappy) {
      for item in items {
        // 選択中のレコードが削除対象なら先に選択を解除
        if let selected = selectedRecord, selected.id == item.id {
          selectedRecord = nil
        }
        dataStore.delete(item)
      }
    }
    // 保存はアニメーション外で行う
    Task.detached(priority: .userInitiated) {
      await MainActor.run {
        self.dataStore.save()
      }
    }
  }

  /// 詳細画面を表示する（iPadではナビゲーション、iPhoneではシート）
  func showRecordDetail(_ record: BatteryRecord) {
    print(
      "[HomeView] showRecordDetail called, horizontalSizeClass: \(String(describing: horizontalSizeClass))"
    )
    if horizontalSizeClass == .regular {
      print("[HomeView] Setting navigatingRecord (iPad)")
      navigatingRecord = record
    } else {
      print("[HomeView] Setting selectedRecord (iPhone)")
      selectedRecord = record
    }
  }

  /// Apple Watchにレコードを同期する（バックグラウンドで実行）
  func syncRecordsToWatch() {
    let startTime = CFAbsoluteTimeGetCurrent()
    print("[Performance] syncRecordsToWatch開始")

    Task { @MainActor in
      // サンプルデータ表示中はサンプルデータを送信
      let isSampleMode = AppSettings.shared.showingSampleData
      if isSampleMode {
        let sampleRecords = SampleDataProvider.generateSampleRecords()
        let watchRecords = sampleRecords.map { WatchBatteryRecord(from: $0) }
        Task.detached(priority: .utility) {
          await WatchConnectivityManager.shared.sendWatchRecordsToWatch(watchRecords, isSampleMode: true)
          let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
          print("[Performance] syncRecordsToWatch完了（サンプルモード）: \(String(format: "%.2f", elapsed))ms")
        }
        return
      }

      // レコードを取得
      let currentRecords = self.records

      // レコードがある場合のみ同期
      guard !currentRecords.isEmpty else {
        // レコードがない場合はサンプルモードをオフにして空で送信
        Task.detached(priority: .utility) {
          await WatchConnectivityManager.shared.sendWatchRecordsToWatch([], isSampleMode: false)
          let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
          print("[Performance] syncRecordsToWatch完了（空）: \(String(format: "%.2f", elapsed))ms")
        }
        return
      }

      let watchRecords = currentRecords.map { WatchBatteryRecord(from: $0) }
      Task.detached(priority: .utility) {
        // 通常モードでデータを送信
        await WatchConnectivityManager.shared.sendWatchRecordsToWatch(watchRecords, isSampleMode: false)
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print(
          "[Performance] syncRecordsToWatch完了（\(watchRecords.count)件）: \(String(format: "%.2f", elapsed))ms"
        )
      }
    }
  }
}

// MARK: - 重複チェック
extension HomeView {
  /// 日付とデバイス名で重複レコードを検索する（日単位）
  func hasDuplicateRecord(on date: Date, deviceName: String, physicalDeviceID: UUID? = nil) -> Bool {
    let localID = physicalDeviceID == nil
      ? PhysicalDeviceIdentityStore.identityForLocallyRecognizedLog(
        modelCode: DeviceLibrary.getIdentifierForDeviceName(deviceName)) : nil
    return records.contains { existing in
      // 日付を「日単位」で比較（時刻は無視）
      let sameDate = Calendar.current.isDate(existing.logDate, inSameDayAs: date)
      guard sameDate else { return false }

      if let physicalDeviceID {
        return existing.physicalDeviceID == physicalDeviceID
      }
      if let localID {
        if existing.physicalDeviceID == localID { return true }
      }
      // IDのない手動ログは機種名で保守的に照合する。
      guard existing.deviceName == deviceName else { return false }
      if localID != nil { return existing.physicalDeviceID == nil }
      // Manual legacy imports have no reliable device identity. Preserve the
      // conservative date/model check until the user explicitly links them.
      return true
    }
  }

  func hasAmbiguousLegacyRecord(on date: Date, deviceName: String) -> Bool {
    records.contains {
      $0.physicalDeviceID == nil && $0.deviceName == deviceName
        && Calendar.current.isDate($0.logDate, inSameDayAs: date)
    }
  }

  /// Exact parsed values identify an already imported log even if the older
  /// record predates physical device IDs. A same-model/day match alone does not.
  func hasMatchingLegacyRecord(_ result: LogParser.ParseResult, deviceName: String) -> Bool {
    guard let date = result.logDate,
      let cycles = result.cycleCount,
      let nominal = result.nominalCapacity,
      let raw = result.rawCapacity else { return false }
    return records.contains {
      $0.physicalDeviceID == nil && $0.deviceName == deviceName
        && abs($0.logDate.timeIntervalSince(date)) < 1
        && $0.cycleCount == cycles
        && $0.nominalCapacity == nominal
        && $0.rawCapacity == raw
        && ($0.productSku == nil || $0.productSku == result.productSku)
    }
  }

  /// 既存のレコードを検索する
  func findExistingRecord(on date: Date, deviceName: String) -> BatteryRecord? {
    records.first { existing in
      let sameDevice = existing.deviceName == deviceName
      guard sameDevice else { return false }
      return abs(existing.logDate.timeIntervalSince(date)) < 1.0
    }
  }
}

// MARK: - データ整合性
extension HomeView {
  /// 起動時に「Unknown」デバイス名を解決する
  func reconcileUnknownDeviceNames() {
    var needsSave = false
    for record in records {
      guard record.deviceName == "Unknown",
        let code = record.deviceModelCode,
        let resolved = DeviceLibrary.getDeviceName(for: code)
      else {
        continue
      }
      record.deviceName = resolved
      needsSave = true
    }
    if needsSave {
      dataStore.save()
    }
  }

  /// 起動時にライブラリに設計容量が登録されていない既存レコードを補完する
  func reconcileMissingDesignCapacities() {
    var needsSave = false
    for record in records {
      // 0 は「未登録・情報なし」を表す (既存のコードとの互換性維持)
      guard record.designCapacity == 0 else { continue }

      // まずは model code から解決を試みる
      if let code = record.deviceModelCode,
        let resolvedName = DeviceLibrary.getDeviceName(for: code),
        let cap = DeviceLibrary.getCapacity(for: resolvedName),
        cap > 0
      {
        record.designCapacity = cap
        // 設計容量が埋まったら診断結果を再計算する
        if record.rawCapacity > 0 {
          let rawRatio = (Double(record.rawCapacity) / Double(cap)) * 100.0
          if rawRatio < 80.0 {
            record.diagnosticResult = L10n.string("diag_replace_recommended", table: "Records")
          } else if rawRatio < 90.0 {
            record.diagnosticResult = L10n.string("diag_slightly_degraded", table: "Records")
          } else {
            record.diagnosticResult = L10n.string("diag_normal", table: "Records")
          }
        }
        needsSave = true
        continue
      }

      // 次に deviceName から解決できるか試す
      if let cap = DeviceLibrary.getCapacity(for: record.deviceName), cap > 0 {
        record.designCapacity = cap
        if record.rawCapacity > 0 {
          let rawRatio = (Double(record.rawCapacity) / Double(cap)) * 100.0
          if rawRatio < 80.0 {
            record.diagnosticResult = L10n.string("diag_replace_recommended", table: "Records")
          } else if rawRatio < 90.0 {
            record.diagnosticResult = L10n.string("diag_slightly_degraded", table: "Records")
          } else {
            record.diagnosticResult = L10n.string("diag_normal", table: "Records")
          }
        }
        needsSave = true
      }
    }
    if needsSave { dataStore.save() }
  }
}
