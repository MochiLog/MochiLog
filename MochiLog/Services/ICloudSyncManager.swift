import CloudKit
import CoreData
import Foundation
import Combine
import OSLog

/// 競合（コンフリクト）した個々のレコード情報を保持するモデル
struct SyncConflictItem: Identifiable {
  let id = UUID()
  let recordID: UUID
  let localSnapshot: [String: Any]
  let serverSnapshot: [String: Any]

  // UI表示用のヘルパープロパティ
  var localDate: Date? { localSnapshot["logDate"] as? Date }
  var serverDate: Date? { serverSnapshot["logDate"] as? Date }
  var localDevice: String { (localSnapshot["deviceName"] as? String) ?? "Unknown" }
  var serverDevice: String { (serverSnapshot["deviceName"] as? String) ?? "Unknown" }

  var localCycleCount: Int? { localSnapshot["cycleCount"] as? Int }
  var serverCycleCount: Int? { serverSnapshot["cycleCount"] as? Int }

  var localDesignCapacity: Int? { localSnapshot["designCapacity"] as? Int }
  var serverDesignCapacity: Int? { serverSnapshot["designCapacity"] as? Int }

  var localNominalCapacity: Int? { localSnapshot["nominalCapacity"] as? Int }
  var serverNominalCapacity: Int? { serverSnapshot["nominalCapacity"] as? Int }

  var localSettingsDisplayPercent: Int? { localSnapshot["settingsDisplayPercent"] as? Int }
  var serverSettingsDisplayPercent: Int? { serverSnapshot["settingsDisplayPercent"] as? Int }
}

/// コンフリクト解決の選択肢
enum SyncConflictResolution {
  case server
  case local
  case all
}

/// 同期ステータス
enum SyncStatus: Equatable {
  case idle
  case syncing
  case success
  case error(String)
  case notAuthenticated  // CKError.notAuthenticated (code 9)
}

/// iCloud同期のコンフリクト（競合）をメモリ上で管理し、手動解決をサポートするマネージャー
final class ICloudSyncManager: ObservableObject {
  static let shared = ICloudSyncManager()

  @Published private(set) var isRunningDiagnostics = false

  /// Local validation is informational; it does not establish upload success or failure.
  @Published private(set) var lastDiagnosticReport: String?

  /// 現在未解決のコンフリクト一覧
  @Published var unresolvedConflicts: [SyncConflictItem] = []

  /// 最近の同期ステータス
  @Published var lastSyncStatus: SyncStatus = .idle

  /// 最後に発生したエラーの詳細ログ（UI表示・コピー用）
  @Published var lastErrorLog: String? = nil

  /// インポート完了時にrefreshを呼ぶDataStore（弱参照）
  private weak var dataStore: DataStore?

  /// DataStoreを登録する（AppDelegate/初期化時に呼ぶ）
  func register(dataStore: DataStore) {
    self.dataStore = dataStore
  }

  private init() {
    // NSPersistentCloudKitContainerの同期イベントを監視する
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleCloudKitEventChanged(_:)),
      name: NSPersistentCloudKitContainer.eventChangedNotification,
      object: nil
    )
  }

  @objc
  private func handleCloudKitEventChanged(_ notification: Notification) {
    guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
      return
    }

    if let error = event.error {
      let logText = logCloudKitError(error, eventType: event.type)

      Task { @MainActor in
        if let ckError = self.extractCKError(error), ckError.code == .notAuthenticated {
          self.lastSyncStatus = .notAuthenticated
          Task { await self.logAccountStatus() }
        } else {
          self.lastSyncStatus = .error(self.friendlyErrorMessage(error))
        }
        let details = await Task.detached(priority: .utility) {
          Self.coreDataLogDetails()
        }.value
        let finalLog = "[\(Date().formatted())]\n" + logText + details

        self.lastErrorLog = finalLog

      }
      return
    }

    DispatchQueue.main.async {
      if event.endDate == nil {
        self.lastSyncStatus = .syncing
      } else {
        self.lastSyncStatus = .success
        AppSettings.shared.lastICloudSyncDate = Date().timeIntervalSince1970

        // インポートイベント完了時（他デバイスからデータを受信した場合）は
        // ローカルコンテキストを最新状態に更新してUIに反映する
        if event.type == .import {
          self.dataStore?.refreshRecords()
        }
      }
    }
  }

  private nonisolated static func coreDataLogDetails() -> String {
    do {
      let store = try OSLogStore(scope: .currentProcessIdentifier)
      let position = store.position(timeIntervalSinceEnd: -60)
      let predicate = NSPredicate(format: "subsystem == %@", "com.apple.coredata")
      let entries = try store.getEntries(at: position, matching: predicate)
      var lines: [String] = []
      for entry in entries.prefix(500) {
        guard let log = entry as? OSLogEntryLog else { continue }
        let message = log.composedMessage
        if log.level == .error || log.level == .fault || message.contains("fail") || message.contains("CloudKit") {
          lines.append("[\(log.date.formatted(date: .omitted, time: .standard))] \(message)")
        }
      }
      return lines.isEmpty ? "" : "\n\n=== Core Data diagnostics ===\n" + lines.suffix(100).joined(separator: "\n")
    } catch {
      return "\n(Core Data log collection failed: \(error.localizedDescription))"
    }
  }

  // MARK: - エラー解析ヘルパー

  /// NSErrorの中からCKErrorを掘り起こす（全階層を再帰探索）
  private func extractCKError(_ error: Error) -> CKError? {
    CloudKitErrorInspector.cloudKitError(in: error)
  }

  /// CloudKit/CoreDataエラーの全情報をログ出力し、UI表示用の文字列として返す
  @discardableResult
  private func logCloudKitError(_ error: Error, eventType: NSPersistentCloudKitContainer.EventType) -> String {
    let typeLabel: String
    switch eventType {
    case .setup:  typeLabel = "setup"
    case .import: typeLabel = "import"
    case .export: typeLabel = "export"
    @unknown default: typeLabel = "unknown"
    }

    var lines: [String] = []
    lines.append("❌ CloudKitエラー (eventType=\(typeLabel))")
    dumpError(error, into: &lines, indent: "")

    let logText = lines.joined(separator: "\n")

    // Xcodeコンソールへも出力
    for line in lines {
      print("[ICloudSync] \(line)")
    }

    return logText
  }

  /// NSErrorを再帰的にダンプする（partialFailureのサブエラーも完全展開）
  private func dumpError(_ error: Error, into lines: inout [String], indent: String) {
    guard indent.count < 40, lines.count < 1000 else { return }
    let ns = error as NSError
    lines.append("\(indent)domain=\(ns.domain), code=\(ns.code)")
    lines.append("\(indent)desc=\(ns.localizedDescription)")

    // CKErrorDomainならコード名も表示
    if ns.domain == CKErrorDomain {
      lines.append("\(indent)CKError: \(ckErrorCodeName(ns.code)) (rawValue=\(ns.code))")
    }

    // userInfoを全て展開
    for (key, value) in ns.userInfo {
      let keyStr = "\(key)"
      switch keyStr {
      case NSUnderlyingErrorKey:
        if let sub = value as? Error {
          lines.append("\(indent)NSUnderlyingError:")
          dumpError(sub, into: &lines, indent: indent + "  ")
        }
      case CKPartialErrorsByItemIDKey:
        if let partial = value as? [AnyHashable: Error] {
          lines.append("\(indent)partialErrors(\(partial.count)件):")
          for (itemID, subErr) in partial {
            lines.append("\(indent)  [itemID=\(itemID)]")
            dumpError(subErr, into: &lines, indent: indent + "    ")
          }
        }
      case "NSUnderlyingErrorsKey":
        if let subs = value as? [Error] {
          lines.append("\(indent)NSUnderlyingErrors(\(subs.count)件):")
          for (i, sub) in subs.enumerated() {
            lines.append("\(indent)  [\(i)]")
            dumpError(sub, into: &lines, indent: indent + "    ")
          }
        }
      case NSLocalizedDescriptionKey, "NSLocalizedFailureReason":
        break // desc と重複するためスキップ
      default:
        lines.append("\(indent)[\(keyStr)]: \(value)")
      }
    }
  }

  /// CKErrorコード番号から名前文字列を返す
  private func ckErrorCodeName(_ code: Int) -> String {
    switch code {
    case 1:  return "internalError"
    case 2:  return "partialFailure"
    case 3:  return "networkUnavailable"
    case 4:  return "networkFailure"
    case 5:  return "badContainer"
    case 6:  return "serviceUnavailable"
    case 7:  return "requestRateLimited"
    case 9:  return "notAuthenticated"
    case 10: return "permissionFailure"
    case 11: return "unknownItem"
    case 12: return "invalidArguments"
    case 14: return "resultsTruncated"
    case 15: return "serverRecordChanged"
    case 16: return "serverRejectedRequest"
    case 17: return "assetFileNotFound"
    case 18: return "assetFileModified"
    case 19: return "incompatibleVersion"
    case 20: return "constraintViolation"
    case 21: return "operationCancelled"
    case 22: return "changeTokenExpired"
    case 23: return "batchRequestFailed"
    case 24: return "zoneBusy"
    case 25: return "badDatabase"
    case 26: return "quotaExceeded"
    case 27: return "zoneNotFound"
    case 28: return "limitExceeded"
    case 29: return "userDeletedZone"
    case 30: return "tooManyParticipants"
    case 31: return "alreadyShared"
    case 32: return "referenceViolation"
    case 33: return "managedAccountRestricted"
    case 34: return "participantMayNeedVerification"
    case 36: return "serverResponseLost"
    case 37: return "assetNotAvailable"
    case 38: return "accountTemporarilyUnavailable"
    default: return "unknown(\(code))"
    }
  }


  /// CKErrorコードに応じた日本語エラーメッセージを返す
  private func friendlyErrorMessage(_ error: Error) -> String {
    guard let cloudError = extractCKError(error) else {
      let ns = error as NSError
      return "\(ns.localizedDescription) (\(ns.domain) \(ns.code))"
    }
    let message: String
    switch cloudError.code {
    case .partialFailure:
      let count = (cloudError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error])?.count ?? 0
      message = String(format: L10n.string("cloud_partial", table: "Language"), count)
    case .networkUnavailable, .networkFailure:
      message = L10n.string("cloud_network", table: "Language")
    case .serviceUnavailable:
      message = L10n.string("cloud_unavailable", table: "Language")
    case .requestRateLimited:
      message = L10n.string("cloud_rate_limit", table: "Language")
    case .quotaExceeded:
      message = L10n.string("cloud_quota", table: "Language")
    case .zoneNotFound, .unknownItem:
      message = L10n.string("cloud_zone", table: "Language")
    case .serverRecordChanged:
      message = L10n.string("cloud_conflict", table: "Language")
    case .notAuthenticated:
      message = L10n.string("cloud_auth", table: "Language")
    default:
      message = cloudError.localizedDescription
    }
    return "\(message) (CKError \(cloudError.code.rawValue))"
  }

  /// CKContainerのアカウント状態を非同期で取得してログ出力
  private func logAccountStatus() async {
    do {
      let status = try await CKContainer.default().accountStatus()
      let label: String
      switch status {
      case .available:        label = "available（正常）"
      case .noAccount:        label = "noAccount（アカウントなし）"
      case .restricted:       label = "restricted（制限あり）"
      case .couldNotDetermine: label = "couldNotDetermine（不明）"
      case .temporarilyUnavailable: label = "temporarilyUnavailable（一時的に利用不可）"
      @unknown default:       label = "unknown"
      }
      print("[ICloudSync] ℹ️ CKContainer.accountStatus = \(label)")
    } catch {
      print("[ICloudSync] ⚠️ accountStatus取得失敗: \(error)")
    }
  }

  /// Validate local values and account availability without touching Core Data's managed zone.
  /// Direct CKRecord writes in that zone can create duplicate or malformed mirrored records.
  @MainActor
  func runDiagnosticSyncTest() async {
    guard !isRunningDiagnostics else { return }
    isRunningDiagnostics = true
    defer { isRunningDiagnostics = false }
    let report: String
    var hasDiagnosticError = false
    if let store = dataStore {
      let records = store.recordsDescending
      let invalid = records.filter { record in
        let numbers = [record.deflator, record.avgTemp, record.maxTemp, record.minTemp,
                       record.maxVoltage, record.minVoltage].compactMap { $0 }
        let dates = [record.logDate, record.createdAt] + [record.firstUseDate].compactMap { $0 }
        return numbers.contains { !$0.isFinite } || dates.contains { !$0.timeIntervalSince1970.isFinite }
      }
      if records.isEmpty {
        report = L10n.string("cloud_diagnostic_no_data", table: "Language")
      } else if !invalid.isEmpty {
        hasDiagnosticError = true
        report = String(format: L10n.string("cloud_diagnostic_invalid", table: "Language"),
          invalid.prefix(20).map { $0.id.uuidString }.joined(separator: ", "))
      } else {
        let localReport = String(format: L10n.string("cloud_diagnostic_pass", table: "Language"), records.count)
        do {
          let status = try await CKContainer.default().accountStatus()
          hasDiagnosticError = status != .available
          let accountReport = status == .available
            ? L10n.string("cloud_account_ready", table: "Language")
            : L10n.string("cloud_auth", table: "Language")
          if status == .available {
            do {
              let serverCount = try await readOnlyCloudRecordCount()
              report = localReport + "\n\n" + accountReport + "\n\n"
                + String(format: L10n.string("cloud_diagnostic_server_count",
                  defaultValue: "iCloud上の記録: %d件（読み取り専用）", table: "Settings"), serverCount)
            } catch {
              hasDiagnosticError = true
              report = localReport + "\n\n" + accountReport + "\n\n"
                + L10n.string("cloud_diagnostic_server_unavailable",
                  defaultValue: "iCloud上の件数を取得できませんでした。", table: "Settings")
                + "\n" + friendlyErrorMessage(error)
            }
          } else {
            report = localReport + "\n\n" + accountReport
          }
        } catch {
          hasDiagnosticError = true
          report = localReport + "\n\n" + friendlyErrorMessage(error)
        }
      }
    } else {
      hasDiagnosticError = true
      report = L10n.string("cloud_diagnostic_no_store", table: "Language")
    }
    lastDiagnosticReport = report
    if hasDiagnosticError {
      ErrorLogStore.shared.saveLog(message: L10n.string("cloud_diagnostic_title", table: "Language"), rawText: report)
    }
  }

  /// Count the Core Data mirror's live CloudKit records without changing its zone or sync cursor.
  /// An import/export completion event alone does not prove that every remote record reached this device.
  private func readOnlyCloudRecordCount() async throws -> Int {
    let database = CKContainer.default().privateCloudDatabase
    let zones = try await database.allRecordZones()
    guard let zone = zones.first(where: { $0.zoneID.zoneName == "com.apple.coredata.cloudkit.zone" }) else {
      return 0
    }

    var token: CKServerChangeToken?
    var recordIDs = Set<CKRecord.ID>()
    repeat {
      let changes = try await database.recordZoneChanges(
        inZoneWith: zone.zoneID, since: token, desiredKeys: [], resultsLimit: 200)
      for (id, result) in changes.modificationResultsByID {
        let record = try result.get().record
        if record.recordType == "CD_BatteryRecord" { recordIDs.insert(id) }
      }
      for deletion in changes.deletions where deletion.recordType == "CD_BatteryRecord" {
        recordIDs.remove(deletion.recordID)
      }
      token = changes.changeToken
      if !changes.moreComing { break }
    } while true
    return recordIDs.count
  }

  /// SwiftData/CoreDataの保存エラーから競合を抽出し、管理リストに追加する
  @MainActor
  func handleSaveError(_ error: Error) {
    let nsError = error as NSError
    // NSManagedObjectMergeError
    if nsError.domain == NSCocoaErrorDomain, nsError.code == NSManagedObjectMergeError {
      if let mergeConflicts = nsError.userInfo["conflictList"] as? [NSMergeConflict] {
        for conflict in mergeConflicts {
          // コンフリクトしたオブジェクトから必要なデータを抽出
          let sourceObject = conflict.sourceObject
          guard let recordID = sourceObject.value(forKey: "recordID") as? UUID else { continue }

          let localSnap = conflict.objectSnapshot ?? [:]
          let serverSnap = conflict.cachedSnapshot ?? [:]

          let item = SyncConflictItem(
            recordID: recordID,
            localSnapshot: localSnap,
            serverSnapshot: serverSnap
          )

          // 既に同じrecordIDのコンフリクトがあれば追加しない
          if !unresolvedConflicts.contains(where: { $0.recordID == recordID }) {
            unresolvedConflicts.append(item)
          }
        }
      }
    }
  }

  /// 指定したコンフリクトをリストから削除する
  @MainActor
  func removeConflict(id: UUID) {
    unresolvedConflicts.removeAll { $0.id == id }
  }

  /// 全てのコンフリクトをクリアする
  @MainActor
  func clearConflicts() {
    unresolvedConflicts.removeAll()
  }

  /// コンフリクトを解決する
  @MainActor
  func resolveConflict(_ conflict: SyncConflictItem, resolution: SyncConflictResolution, dataStore: DataStore) {
    switch resolution {
    case .server:
      // サーバーを優先する場合、ローカルの変更はすでにrollbackされているので、何もしない（リストから削除のみ）
      break

    case .local:
      // ローカルを優先する場合、ローカルのスナップショットからレコードを作成し、既存のレコードを上書き（削除＋挿入）する
      if let record = parseSnapshot(conflict.localSnapshot, recordID: conflict.recordID) {
        // 既存のレコードを削除して再挿入する
        let existing = dataStore.recordsDescending.first { $0.id == conflict.recordID }
        if let existing = existing {
          dataStore.delete(existing)
        }
        dataStore.insert(record)
        do {
          try dataStore.saveChanges()
        } catch {
          lastSyncStatus = .error(friendlyErrorMessage(error))
          lastErrorLog = friendlyErrorMessage(error)
          return
        }
      } else {
        return
      }

    case .all:
      // 全てを残す場合、サーバーデータはそのまま維持し、ローカルデータを新しいIDで追加する
      if let record = parseSnapshot(conflict.localSnapshot, recordID: UUID()) { // 新しいUUID
        dataStore.insert(record)
        do {
          try dataStore.saveChanges()
        } catch {
          lastSyncStatus = .error(friendlyErrorMessage(error))
          lastErrorLog = friendlyErrorMessage(error)
          return
        }
      } else {
        return
      }
    }
    removeConflict(id: conflict.id)
  }

  /// スナップショット辞書から BatteryRecord を生成するヘルパー
  private func parseSnapshot(_ dict: [String: Any], recordID: UUID) -> BatteryRecord? {
    guard let logDate = dict["logDate"] as? Date,
          let deviceName = dict["deviceName"] as? String else {
      return nil
    }

    return BatteryRecord(
      id: recordID,
      logDate: logDate,
      deviceName: deviceName,
      deviceModelCode: dict["deviceModelCode"] as? String,
      osVersion: dict["osVersion"] as? String,
      productSku: dict["productSku"] as? String,
      storage: dict["storage"] as? String,
      ram: dict["ram"] as? String,
      manufactureDate: dict["manufactureDate"] as? String,
      firstUseDate: dict["firstUseDate"] as? Date,
      cycleCount: (dict["cycleCount"] as? Int) ?? 0,
      designCapacity: (dict["designCapacity"] as? Int) ?? 0,
      nominalCapacity: (dict["nominalCapacity"] as? Int) ?? 0,
      rawCapacity: (dict["rawCapacity"] as? Int) ?? 0,
      lowRateCapacity: dict["lowRateCapacity"] as? Int,
      deflator: dict["deflator"] as? Double,
      settingsDisplayPercent: dict["settingsDisplayPercent"] as? Int,
      diagnosticResult: dict["diagnosticResult"] as? String,
      avgTemp: dict["avgTemp"] as? Double,
      maxTemp: dict["maxTemp"] as? Double,
      minTemp: dict["minTemp"] as? Double,
      maxVoltage: dict["maxVoltage"] as? Double,
      minVoltage: dict["minVoltage"] as? Double,
      minSoC: dict["minSoC"] as? Int,
      maxSoC: dict["maxSoC"] as? Int
    )
  }

  /// テスト用: ダミーのコンフリクトを生成してリストに追加する
  @MainActor
  func simulateConflict() {
    let dummyRecordID = UUID()
    let localSnap: [String: Any] = [
      "logDate": Date(),
      "deviceName": "Test Device (Local)",
      "cycleCount": 150,
      "designCapacity": 3000,
      "nominalCapacity": 2500,
      "settingsDisplayPercent": 85
    ]
    let serverSnap: [String: Any] = [
      "logDate": Date().addingTimeInterval(-3600),
      "deviceName": "Test Device (Server)",
      "cycleCount": 140,
      "designCapacity": 3000,
      "nominalCapacity": 2600,
      "settingsDisplayPercent": 88
    ]

    let item = SyncConflictItem(
      recordID: dummyRecordID,
      localSnapshot: localSnap,
      serverSnapshot: serverSnap
    )

    unresolvedConflicts.append(item)
  }
}
