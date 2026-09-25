// HomeView+LogProcessing.swift
// ログ処理関連のメソッドをHomeViewから分離
import SwiftUI

// MARK: - 共通処理メソッド
extension HomeView {
  /// デバイス名とモデルコードを解決する
  private func resolveDeviceName(from result: LogParser.ParseResult) -> (
    deviceName: String, modelCode: String?
  ) {
    var deviceName = "Unknown"
    var deviceModelCodeToUse: String? = result.detectedIdentifier ?? result.deviceModelCode

    if let id = deviceModelCodeToUse,
      let resolved = DeviceLibrary.getDeviceName(for: id)
    {
      deviceName = resolved
    }

    if deviceName == "Unknown" {
      if let localId = DeviceLibrary.localModelIdentifier(),
        let resolved = DeviceLibrary.getDeviceName(for: localId)
      {
        deviceName = resolved
        deviceModelCodeToUse = localId
      }
    }

    return (deviceName, deviceModelCodeToUse)
  }

  /// MagSafeバッテリーの条件に合致するか判定し、必要に応じてデバイス名とモデルコードを更新する
  private func checkAndApplyMagSafeBattery(
    from result: LogParser.ParseResult,
    deviceName: String,
    modelCode: String?,
    silent: Bool = false
  ) -> (deviceName: String, modelCode: String?, needsManualSelection: Bool) {
    var updatedDeviceName = deviceName
    var updatedModelCode = modelCode
    var needsManualSelection = false

    if deviceName == "iPhone Air" {
      let isMagSafe = result.firstUseDate == nil
        && result.deflator == nil
        && result.lowRateCapacity == 0
        && result.rawCapacity == 0

      if isMagSafe {
        if AppSettings.shared.autoSelectMagSafeBattery {
          updatedDeviceName = "iPhone Air MagSafeバッテリー"
          updatedModelCode = "A3385"
        } else {
          if !silent {
            needsManualSelection = true
          }
        }
      }
    }

    return (updatedDeviceName, updatedModelCode, needsManualSelection)
  }

  /// レコードを保存する（キャッシュ追加 + データベース挿入）
  private func saveRecord(_ record: BatteryRecord, deviceName: String) {
    // キャッシュに追加（save前に行う）
    let key = "\(record.logDate.timeIntervalSince1970)_\(deviceName)"
    HomeView.recentlyAddedLogs[key] = Date()

    // UIアニメーションとデータ挿入
    withAnimation(.snappy) {
      dataStore.insert(record)
    }

    // 保存はアニメーション外で行う
    Task.detached(priority: .userInitiated) {
      await MainActor.run {
        self.dataStore.save()
      }
    }
  }

  /// WatchOSデバイスかどうかを判定する
  private func isWatchDevice(parseResult: LogParser.ParseResult, deviceName: String) -> Bool {
    let isWatchOS = parseResult.osVersion?.lowercased().contains("watch") ?? false
    let looksLikeWatch = deviceName.contains("Apple Watch")
    return isWatchOS || looksLikeWatch
  }

  /// Watch処理を行う
  /// - Returns: (作成されたレコード, 処理を終了すべきか)
  private func handleWatchRecord(
    from result: LogParser.ParseResult,
    deviceName: String,
    modelCode: String?,
    logDate: Date,
    silent: Bool
  ) -> (record: BatteryRecord?, shouldReturn: Bool) {
    let registeredWatches = AppSettings.shared.registeredWatches

    // 複数のWatchが登録されている場合 → ユーザーに選択させる
    if registeredWatches.count > 1 {
      if silent {
        // サイレントモードでは処理できない（どのWatchか選べないため）
        return (nil, true)
      } else {
        // 対話モードではWatch選択画面を表示
        pendingParseResult = result
        showingWatchSelection = true
        return (nil, true)
      }
    }

    // 1つのWatchが登録されている場合 → そのWatchを使用
    if let registeredWatch = registeredWatches.first {
      // 重複チェック（設定に応じて）
      if !AppSettings.shared.allowDuplicateRecords,
        hasDuplicateRecord(on: logDate, deviceName: registeredWatch,
          physicalDeviceID: pendingSourcePhysicalDeviceID)
      {
        if silent {
          return (nil, true)
        } else {
          // すべてのHomeViewインスタンスにエラーを通知
          DispatchQueue.main.async {
            NotificationCenter.default.post(
              name: NSNotification.Name("ShowImportError"),
              object: nil,
              userInfo: ["errorMessage": L10n.string("duplicate_record", table: "Home")]
            )
          }
          return (nil, true)
        }
      }

      // レコード作成
      let registeredModelCode =
        DeviceLibrary.getIdentifierForDeviceName(registeredWatch) ?? modelCode
      let registeredDesignCap = DeviceLibrary.getCapacity(for: registeredWatch)
      let newRecord = createRecord(
        from: result,
        deviceName: registeredWatch,
        deviceModelCodeOverride: registeredModelCode,
        designCapacityOverride: registeredDesignCap
      )
      newRecord.physicalDeviceID = pendingSourcePhysicalDeviceID

      // レコード保存
      saveRecord(newRecord, deviceName: registeredWatch)
      pendingSourcePhysicalDeviceID = nil

      return (newRecord, silent)
    }

    // 登録済みWatchモデルがない場合
    if silent {
      return (nil, true)
    } else {
      // 対話モードではWatch選択画面を表示
      pendingParseResult = result
      showingWatchSelection = true
      return (nil, true)
    }
  }

  /// 通常デバイス（iPhone/iPad）の処理を行う
  private func handleNormalDeviceRecord(
    from result: LogParser.ParseResult,
    deviceName: String,
    modelCode: String?,
    logDate: Date,
    silent: Bool
  ) -> BatteryRecord? {
    let selectionMode = AppSettings.shared.deviceSelectionMode

    // iPhone Air関連は専用の判定（自動/手動）を優先するため、一般的な端末の手動選択をバイパスする
    let isAirOrMagSafe = deviceName == "iPhone Air" || deviceName == "iPhone Air MagSafeバッテリー"

    // 手動モードの場合: ユーザーにデバイス選択を促す
    if selectionMode != .automatic && !silent && !isAirOrMagSafe {
      pendingParseResult = result
      if selectionMode == .preRegistered {
        // 登録済みデバイスがある場合はそこから選択、なければフルリストから選択
        if AppSettings.shared.registeredDevices.isEmpty {
          showingDeviceSelectionFullList = true
        } else {
          showingDeviceSelectionFromRegistered = true
        }
      } else {
        // fullManual: 全端末リストから選択
        showingDeviceSelectionFullList = true
      }
      return nil
    }

    // 自動モード or サイレントモード: 従来の処理
    // 重複チェック（設定に応じて）
    if !AppSettings.shared.allowDuplicateRecords,
      hasDuplicateRecord(on: logDate, deviceName: deviceName,
        physicalDeviceID: pendingSourcePhysicalDeviceID)
    {
      if silent {
        return nil
      } else {
        // すべてのHomeViewインスタンスにエラーを通知
        DispatchQueue.main.async {
          NotificationCenter.default.post(
            name: NSNotification.Name("ShowImportError"),
            object: nil,
            userInfo: ["errorMessage": L10n.string("duplicate_record", table: "Home")]
          )
        }
        return nil
      }
    }

    // レコード作成
    let designCap = DeviceLibrary.getCapacity(for: deviceName)
    let newRecord = createRecord(
      from: result,
      deviceName: deviceName,
      deviceModelCodeOverride: modelCode,
      designCapacityOverride: designCap
    )
    newRecord.physicalDeviceID = pendingSourcePhysicalDeviceID

    // レコード保存
    saveRecord(newRecord, deviceName: deviceName)
    pendingSourcePhysicalDeviceID = nil

    return newRecord
  }

  /// デバイス選択後にレコードを作成・保存する共通処理
  func completeRecordWithSelectedDevice(name: String, identifier: String?) {
    guard let result = pendingParseResult else { return }
    let logDate = result.logDate ?? Date()

    // 重複チェック
    if !AppSettings.shared.allowDuplicateRecords,
      hasDuplicateRecord(on: logDate, deviceName: name,
        physicalDeviceID: pendingSourcePhysicalDeviceID)
    {
      DispatchQueue.main.async {
        NotificationCenter.default.post(
          name: NSNotification.Name("ShowImportError"),
          object: nil,
          userInfo: ["errorMessage": L10n.string("duplicate_record", table: "Home")]
        )
      }
      pendingParseResult = nil
      return
    }

    let modelCode = identifier ?? DeviceLibrary.getIdentifierForDeviceName(name)
    let record = createRecord(
      from: result,
      deviceName: name,
      deviceModelCodeOverride: modelCode,
      designCapacityOverride: DeviceLibrary.getCapacity(for: name)
    )
    record.physicalDeviceID = pendingSourcePhysicalDeviceID

    withAnimation(.snappy) {
      dataStore.insert(record)
    }
    Task.detached(priority: .userInitiated) {
      await MainActor.run {
        self.dataStore.save()
      }
    }

    // 詳細画面を表示
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      NotificationCenter.default.post(
        name: NSNotification.Name("ShowRecordDetail"),
        object: nil,
        userInfo: [
          "logDate": record.logDate,
          "deviceName": record.deviceName,
        ]
      )
    }

    pendingParseResult = nil
    pendingSourcePhysicalDeviceID = nil
  }
}

// MARK: - ログ処理
extension HomeView {
  /// ログテキストを非同期で解析・処理する
  func processLogTextAsync(_ text: String, silent: Bool = false, contentHash: Int? = nil,
    physicalDeviceID: UUID? = nil) {
    isProcessing = true

    let enableValidation = AppSettings.shared.enableCapacityValidation
    let threshold = AppSettings.shared.capacityValidationThreshold

    DispatchQueue.global(qos: .userInitiated).async {
      let parseResult = LogParser.parse(
        text: text,
        enableValidation: enableValidation,
        validationThreshold: threshold
      )

      DispatchQueue.main.async {
        isProcessing = false

        // 処理完了を通知（MochiLogAppのフラグをリセットするため）
        if let hash = contentHash {
          NotificationCenter.default.post(
            name: NSNotification.Name("SharedLogProcessingCompleted"),
            object: nil,
            userInfo: ["contentHash": hash]
          )

          // HomeViewのprocessingContentHashesからも削除
          HomeView.processingLock.lock()
          HomeView.processingContentHashes.remove(hash)
          HomeView.processingLock.unlock()
        }

        // UI更新（アラート表示や画面遷移）のために少し遅延させる
        // iPadではOverlayが消えるのと遷移が競合すると詳細画面が開かないことがあるため
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          if !silent {
            self.pendingSourcePhysicalDeviceID = physicalDeviceID
            // Normal interactive flow: existing behavior
            if let newRecord = self.addRecordFromParseResult(parseResult) {
              // 0.5秒遅延してから通知を送信（SwiftDataの更新を待つ）
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(
                  name: NSNotification.Name("ShowRecordDetail"),
                  object: nil,
                  userInfo: [
                    "logDate": newRecord.logDate,
                    "deviceName": newRecord.deviceName,
                  ]
                )
              }
            }
            return
          }

          // Silent mode flow
          self.handleSilentImport(parseResult)
        }
      }
    }
  }

  /// サイレントインポート処理（共有シートからのバックグラウンド処理）
  func handleSilentImport(_ parseResult: LogParser.ParseResult) {
    // 基本的なバリデーション
    let canCreate =
      (parseResult.logDate != nil) && (parseResult.cycleCount != nil)
      && (parseResult.nominalCapacity != nil) && (parseResult.rawCapacity != nil)

    if !canCreate {
      SettingsRedirectHelper.redirectToPrivacyAnalytics()
      return
    }

    // 容量不一致チェック
    if parseResult.isCapacityMismatch && AppSettings.shared.mismatchBehavior == .error {
      SettingsRedirectHelper.redirectToPrivacyAnalytics()
      return
    }

    // デバイス名解決
    let (baseDeviceName, baseModelCode) = resolveDeviceName(from: parseResult)
    let (deviceName, modelCode, _) = checkAndApplyMagSafeBattery(
      from: parseResult,
      deviceName: baseDeviceName,
      modelCode: baseModelCode,
      silent: true
    )
    guard let logDate = parseResult.logDate else { return }

    // Watch判定と処理
    if isWatchDevice(parseResult: parseResult, deviceName: deviceName) {
      let (_, shouldReturn) = handleWatchRecord(
        from: parseResult,
        deviceName: deviceName,
        modelCode: modelCode,
        logDate: logDate,
        silent: true
      )
      if shouldReturn {
        SettingsRedirectHelper.redirectToPrivacyAnalytics()
      }
      return
    }

    // 通常デバイス処理
    _ = handleNormalDeviceRecord(
      from: parseResult,
      deviceName: deviceName,
      modelCode: modelCode,
      logDate: logDate,
      silent: true
    )
    SettingsRedirectHelper.redirectToPrivacyAnalytics()
  }

  /// 解析結果からレコードを追加する（対話的なフロー用）
  func addRecordFromParseResult(_ result: LogParser.ParseResult) -> BatteryRecord? {
    // エラーログが保存され、かつデバッグポップアップ設定がONの場合は、
    // 既に「ログを保存しました」アラートが出ているため、解析エラーのアラートは出さない
    if result.hasErrorSaved && AppSettings.shared.showPopupOnLoad {
      return nil
    }

    // バリデーション
    guard let logDate = result.logDate,
      result.cycleCount != nil,
      result.nominalCapacity != nil,
      result.rawCapacity != nil
    else {
      DispatchQueue.main.async {
        NotificationCenter.default.post(
          name: NSNotification.Name("ShowImportError"),
          object: nil,
          userInfo: ["errorMessage": L10n.string("parse_error", table: "Home")]
        )
      }
      return nil
    }

    // 容量不一致チェック
    if result.isCapacityMismatch {
      if AppSettings.shared.mismatchBehavior == .error {
        DispatchQueue.main.async {
          NotificationCenter.default.post(
            name: NSNotification.Name("ShowImportError"),
            object: nil,
            userInfo: ["errorMessage": L10n.string("capacity_mismatch_error", table: "Home")]
          )
        }
        return nil
      } else {
        pendingParseResult = result
        showingMismatchAlert = true
        return nil
      }
    }

    // デバイス名解決
    let (baseDeviceName, baseModelCode) = resolveDeviceName(from: result)
    let (deviceName, modelCode, needsMagSafeSelection) = checkAndApplyMagSafeBattery(
      from: result,
      deviceName: baseDeviceName,
      modelCode: baseModelCode,
      silent: false
    )

    if needsMagSafeSelection {
      pendingParseResult = result
      showingMagSafeSelection = true
      return nil
    }

    // Watch判定と処理
    if isWatchDevice(parseResult: result, deviceName: deviceName) {
      let (record, _) = handleWatchRecord(
        from: result,
        deviceName: deviceName,
        modelCode: modelCode,
        logDate: logDate,
        silent: false
      )
      return record
    }

    // 通常デバイス処理
    return handleNormalDeviceRecord(
      from: result,
      deviceName: deviceName,
      modelCode: modelCode,
      logDate: logDate,
      silent: false
    )
  }
}

// MARK: - 共有メニューバッチ処理（並列）
extension HomeView {

  /// One consumer owns all batches, including files arriving while parsing is in flight.
  @MainActor
  func consumeSharedImports() async {
    let queue = SharedImportQueue.shared
    guard queue.begin() else {
      if queue.isConsuming && queue.shouldPresentResults { showingBatchResults = true }
      return
    }
    defer { queue.finish() }
    isProcessing = true
    defer { isProcessing = false }
    batchImportResults = []
    showingBatchResults = queue.shouldPresentResults
    let validation = AppSettings.shared.enableCapacityValidation
    let threshold = AppSettings.shared.capacityValidationThreshold
    while true {
      let urls = queue.takeNext()
      if urls.isEmpty { break }
      if queue.shouldPresentResults { showingBatchResults = true }
      let offset = batchImportResults.count
      batchImportResults += urls.enumerated().map { index, url in
        FileImportResult(id: offset + index, filename: url.lastPathComponent,
          parsedDate: nil, deviceName: nil, rawText: nil, status: .processing, errorMessage: nil)
      }
      // A bounded window avoids holding dozens of large analytics logs in memory.
      for start in stride(from: 0, to: urls.count, by: 2) {
        let end = min(start + 2, urls.count)
        let parsed = await withTaskGroup(of: (Int, String?, LogParser.ParseResult?).self) { group in
          for index in start..<end {
            let url = urls[index]
            group.addTask {
              await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                  let text = try? LogTextReader.read(url)
                  let result = text.map {
                    LogParser.parse(text: $0, enableValidation: validation, validationThreshold: threshold)
                  }
                  continuation.resume(returning: (index, text, result))
                }
              }
            }
          }
          var values: [(Int, String?, LogParser.ParseResult?)] = []
          for await value in group { values.append(value) }
          return values.sorted { $0.0 < $1.0 }
        }
        // Deterministic insertion makes duplicate handling independent of parse completion order.
        for (index, text, parsedResult) in parsed {
          let id = offset + index
          let url = urls[index]
          if let text, let parsedResult {
            batchImportResults[id] = processBatchItem(id: id, parseResult: parsedResult,
              filename: url.lastPathComponent, rawText: text,
              physicalDeviceID: queue.physicalDeviceID(for: url))
          } else {
            batchImportResults[id] = FileImportResult(id: id, filename: url.lastPathComponent,
              parsedDate: nil, deviceName: nil, rawText: nil, status: .error,
              errorMessage: L10n.string("file_read_error", table: "Home"))
          }
          let status = batchImportResults[id].status
          queue.acknowledge(url, saved: status == .success || status == .duplicate)
        }
      }
    }
    if !queue.shouldPresentResults {
      if batchImportResults.contains(where: { $0.status == .needsReview || $0.status == .error }) {
        showingBatchResults = true
      } else if queue.shouldOpenDetail {
        if batchImportResults.count == 1,
          let result = batchImportResults.first,
          let date = result.parsedDate, let name = result.deviceName,
          let record = records.first(where: {
            $0.deviceName == name && abs($0.logDate.timeIntervalSince(date)) < 1.0
          }) {
          isProcessing = false
          showRecordDetail(record)
        } else {
          showingBatchResults = true
        }
      } else {
        SettingsRedirectHelper.redirectToPrivacyAnalytics()
      }
    }
  }

  /// バッチ処理の1件を判定・保存して FileImportResult を返す
  /// UIモーダル（アラート・シート）は一切出さない
  @MainActor
  private func processBatchItem(
    id: Int,
    parseResult: LogParser.ParseResult,
    filename: String,
    rawText: String,
    physicalDeviceID: UUID? = nil
  ) -> FileImportResult {

    // 基本バリデーション（必須フィールドの確認）
    guard let logDate = parseResult.logDate,
      parseResult.cycleCount != nil,
      parseResult.nominalCapacity != nil,
      parseResult.rawCapacity != nil
    else {
      return FileImportResult(
        id: id,
        filename: filename,
        parsedDate: parseResult.logDate,
        deviceName: nil,
        rawText: rawText,
        status: .error,
        errorMessage: parseResult.failureDescription ?? L10n.string("parse_error", table: "Home")
      )
    }

    // 容量不一致チェック（エラーモード時のみブロック）
    if parseResult.isCapacityMismatch && AppSettings.shared.mismatchBehavior == .error {
      return FileImportResult(
        id: id,
        filename: filename,
        parsedDate: logDate,
        deviceName: nil,
        rawText: rawText,
        status: .error,
        errorMessage: L10n.string("capacity_mismatch_error", table: "Home")
      )
    }

    if parseResult.isCapacityMismatch {
      return FileImportResult(id: id, filename: filename, parsedDate: logDate,
        deviceName: nil, rawText: rawText, status: .needsReview,
        errorMessage: L10n.string("capacity_mismatch_error", table: "Home"),
        physicalDeviceID: physicalDeviceID)
    }

    // デバイス名解決
    let (baseDeviceName, baseModelCode) = resolveDeviceName(from: parseResult)
    let (resolvedName, resolvedModelCode, needsMagSafeSelection) = checkAndApplyMagSafeBattery(
      from: parseResult,
      deviceName: baseDeviceName,
      modelCode: baseModelCode,
      silent: false // バッチ処理でもユーザーへの確認（needsReview）を行うためにfalseを指定
    )

    if needsMagSafeSelection {
      return FileImportResult(
        id: id,
        filename: filename,
        parsedDate: logDate,
        deviceName: baseDeviceName,
        rawText: rawText,
        status: .needsReview,
        errorMessage: nil,
        physicalDeviceID: physicalDeviceID
      )
    }

    var actualDeviceName = resolvedName
    var actualModelCode = resolvedModelCode

    // Apple Watch の処理
    if isWatchDevice(parseResult: parseResult, deviceName: actualDeviceName) {
      let registeredWatches = AppSettings.shared.registeredWatches
      if registeredWatches.count > 1 {
        // Watchが複数登録されている場合はユーザーに選ばせるため手動インポートへ
        return FileImportResult(
          id: id,
          filename: filename,
          parsedDate: logDate,
          deviceName: actualDeviceName,
          rawText: rawText,
          status: .needsReview,
          errorMessage: nil,
          physicalDeviceID: physicalDeviceID
        )
      } else if let firstWatch = registeredWatches.first {
        actualDeviceName = firstWatch
        actualModelCode = DeviceLibrary.getIdentifierForDeviceName(firstWatch) ?? actualModelCode
      } else {
        return FileImportResult(
          id: id,
          filename: filename,
          parsedDate: logDate,
          deviceName: actualDeviceName,
          rawText: rawText,
          status: .needsReview,
          errorMessage: nil,
          physicalDeviceID: physicalDeviceID
        )
      }
    } else {
      // iPhone/iPad など通常デバイスの処理
      let selectionMode = AppSettings.shared.deviceSelectionMode
      if selectionMode != .automatic {
        // 手動選択モードの場合はユーザーに選ばせるため手動インポートへ
        return FileImportResult(
          id: id,
          filename: filename,
          parsedDate: logDate,
          deviceName: actualDeviceName,
          rawText: rawText,
          status: .needsReview,
          errorMessage: nil,
          physicalDeviceID: physicalDeviceID
        )
      }
    }

    // Mac transfer assigns the host iPhone and each proxied Watch distinct IDs.
    let sourcePhysicalID = physicalDeviceID

    // A same-model legacy entry cannot be assigned to this physical device
    // automatically. Leave the incoming log for user review.
    if sourcePhysicalID != nil,
      hasMatchingLegacyRecord(parseResult, deviceName: actualDeviceName) {
      return FileImportResult(id: id, filename: filename, parsedDate: logDate,
        deviceName: actualDeviceName, rawText: nil, status: .duplicate,
        errorMessage: nil)
    }
    if sourcePhysicalID != nil,
      hasAmbiguousLegacyRecord(on: logDate, deviceName: actualDeviceName) {
      return FileImportResult(id: id, filename: filename, parsedDate: logDate,
        deviceName: actualDeviceName, rawText: rawText, status: .needsReview,
        errorMessage: nil, physicalDeviceID: physicalDeviceID)
    }

    // 重複チェック
    if !AppSettings.shared.allowDuplicateRecords,
      hasDuplicateRecord(on: logDate, deviceName: actualDeviceName,
        physicalDeviceID: sourcePhysicalID)
    {
      return FileImportResult(
        id: id,
        filename: filename,
        parsedDate: logDate,
        deviceName: actualDeviceName,
        rawText: nil,
        status: .duplicate,
        errorMessage: nil
      )
    }

    // レコード作成・保存
    let designCap = DeviceLibrary.getCapacity(for: actualDeviceName)
    let record = createRecord(
      from: parseResult,
      deviceName: actualDeviceName,
      deviceModelCodeOverride: actualModelCode,
      designCapacityOverride: designCap
    )
    record.physicalDeviceID = sourcePhysicalID
    dataStore.insert(record)
    do {
      try dataStore.saveChanges()
      let key = "\(record.logDate.timeIntervalSince1970)_\(actualDeviceName)"
      HomeView.recentlyAddedLogs[key] = Date()
    } catch {
      return FileImportResult(id: id, filename: filename, parsedDate: logDate,
        deviceName: actualDeviceName, rawText: rawText, status: .error,
        errorMessage: error.localizedDescription)
    }

    return FileImportResult(
      id: id,
      filename: filename,
      parsedDate: logDate,
      deviceName: actualDeviceName,
      rawText: nil,
      status: .success,
      errorMessage: nil
    )
  }
}
