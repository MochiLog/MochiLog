import Combine
import Foundation

/// バッテリーレコードの永続化を抽象化するデータストア
/// iOS 17+: SwiftDataStore（SwiftData使用）
/// iOS 16:  CoreDataStore（CoreData使用）
class DataStore: ObservableObject {
  // MARK: - Properties

  /// 内部的にiCloudが有効化されているかどうか
  @Published private(set) var isICloudEnabled: Bool

  // MARK: - Published Records (キャッシュ済み)

  /// レコード（降順：最新が先頭）
  @Published private(set) var recordsDescending: [BatteryRecord] = []

  /// レコード（昇順：古いものが先頭）
  @Published private(set) var recordsAscending: [BatteryRecord] = []

  /// デバイス名リスト（ソート済み）
  @Published private(set) var deviceNames: [String] = []

  /// レコード数
  var count: Int { recordsDescending.count }

  /// レコードが空かどうか
  var isEmpty: Bool { recordsDescending.isEmpty }

  init(isICloudEnabled: Bool = false) {
    self.isICloudEnabled = isICloudEnabled
  }

  // MARK: - CRUD (サブクラスでオーバーライド)

  /// レコードを挿入
  func insert(_ record: BatteryRecord) {
    fatalError("Subclass must override insert(_:)")
  }

  /// レコードを削除
  func delete(_ record: BatteryRecord) {
    fatalError("Subclass must override delete(_:)")
  }

  /// 複数レコードを削除
  func deleteRecords(_ records: [BatteryRecord]) {
    for record in records {
      delete(record)
    }
    save()
    refreshRecords()
  }

  /// 全レコード削除
  func deleteAll() {
    fatalError("Subclass must override deleteAll()")
  }

  /// 特定デバイスのレコードを削除
  func deleteRecords(for deviceName: String) {
    fatalError("Subclass must override deleteRecords(for:)")
  }

  /// 変更を保存
  func save() {
    fatalError("Subclass must override save()")
  }

  /// Imports must distinguish a durable save from a rolled-back write.
  func saveChanges() throws {
    fatalError("Subclass must override saveChanges()")
  }

  /// Only records explicitly tagged with this installation's previous ID are
  /// relinked after user confirmation. Legacy nil-ID records are untouched.
  func reassignPhysicalDeviceID(from oldID: UUID, to newID: UUID,
    matchingModelCode: String) throws -> Int { 0 }

  /// 特定デバイスのレコードを取得（日付昇順）
  func fetchRecords(for deviceName: String, ascending: Bool = true) -> [BatteryRecord] {
    fatalError("Subclass must override fetchRecords(for:ascending:)")
  }

  /// キャッシュを更新（永続化レイヤーから再取得）
  func refreshRecords() {
    fatalError("Subclass must override refreshRecords()")
  }

  /// マイグレーションを実行（iOS 17+ のみ）
  func runMigrations() {
    // デフォルト実装: 何もしない（CoreDataStore用）
  }

  // MARK: - キャッシュ更新ヘルパー

  /// 取得したレコードでキャッシュを更新
  func updateCachedRecords(_ records: [BatteryRecord]) {
    // Both stores fetch in descending date order; avoid sorting the same data twice.
    let sorted = records
    recordsDescending = sorted
    recordsAscending = sorted.reversed()
    let names = Array(Set(records.map { $0.deviceName })).sorted()
    if deviceNames != names { deviceNames = names }
  }

  /// Update only device metadata; measured capacities, dates and record IDs stay intact.
  func applyDeviceProfile(_ profile: DeviceProfile, names: Set<String>, identifiers: Set<String>) throws -> Int {
    fatalError("Subclass must override applyDeviceProfile")
  }

  // MARK: - Factory

  /// OS バージョンに応じた DataStore を生成
  static func create(iCloudEnabled: Bool) -> DataStore {
    if #available(iOS 17, *) {
      return SwiftDataStore(iCloudEnabled: iCloudEnabled)
    } else {
      return CoreDataStore()
    }
  }

  /// iCloud設定変更時にストアを再生成
  static func recreate(iCloudEnabled: Bool) -> DataStore {
    return create(iCloudEnabled: iCloudEnabled)
  }
}
