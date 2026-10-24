import Foundation
import SwiftData

/// マイグレーション管理クラス
/// 全てのマイグレーションを実行し、実行済みマイグレーションを追跡します
@available(iOS 17, *)
struct MigrationManager {
  /// 実行済みマイグレーションを保存するキーのプレフィックス
  private static let migrationKeyPrefix = "Migration_Completed_"

  /// 登録されたマイグレーションのリスト
  /// 新しいマイグレーションはこのリストに追加してください
  private static let migrations: [Migration.Type] = [
    Migration_v1_iPhone16e_AvgTemp.self,
    Migration_v3_WatchSeries3Capacity.self,
    // 新しいマイグレーションをここに追加
    // 例: Migration_v2_NewFeature.self,
  ]

  /// 全ての未実行マイグレーションを実行する（バックグラウンドで実行）
  /// - Parameter modelContext: SwiftDataのモデルコンテキスト
  static func runPendingMigrations(modelContext: ModelContext) {
    // バックグラウンドスレッドで実行してUIをブロックしない
    Task.detached(priority: .utility) {
      await runPendingMigrationsAsync(modelContext: modelContext)
    }
  }

  /// 全ての未実行マイグレーションを非同期実行する（内部用）
  /// - Parameter modelContext: SwiftDataのモデルコンテキスト
  private static func runPendingMigrationsAsync(modelContext: ModelContext) async {
    print("[MigrationManager] Checking for pending migrations...")

    for migration in migrations {
      let migrationKey = migrationKeyPrefix + migration.version

      // 既に実行済みかチェック
      if UserDefaults.standard.bool(forKey: migrationKey) {
        print("[MigrationManager] Migration \(migration.version) already completed, skipping.")
        continue
      }

      // マイグレーションを実行
      do {
        print("[MigrationManager] Running migration: \(migration.version)")
        try migration.migrate(modelContext: modelContext)

        // 実行済みフラグを設定
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("[MigrationManager] Migration \(migration.version) completed successfully.")
      } catch {
        print("[MigrationManager] Migration \(migration.version) failed with error: \(error)")
        // エラーが発生した場合、このマイグレーションをスキップして次へ
        // 必要に応じて、ここでエラーハンドリングを追加できます
      }
    }

    print("[MigrationManager] All pending migrations completed.")
  }

  /// 特定のマイグレーションを強制的に再実行する（デバッグ用）
  /// - Parameters:
  ///   - version: マイグレーションバージョン
  ///   - modelContext: SwiftDataのモデルコンテキスト
  static func rerunMigration(version: String, modelContext: ModelContext) {
    guard let migration = migrations.first(where: { $0.version == version }) else {
      print("[MigrationManager] Migration \(version) not found.")
      return
    }

    let migrationKey = migrationKeyPrefix + version
    UserDefaults.standard.set(false, forKey: migrationKey)

    do {
      try migration.migrate(modelContext: modelContext)
      UserDefaults.standard.set(true, forKey: migrationKey)
      print("[MigrationManager] Migration \(version) rerun completed.")
    } catch {
      print("[MigrationManager] Migration \(version) rerun failed: \(error)")
    }
  }

  /// 全てのマイグレーションフラグをリセットする（デバッグ用）
  static func resetAllMigrations() {
    for migration in migrations {
      let migrationKey = migrationKeyPrefix + migration.version
      UserDefaults.standard.removeObject(forKey: migrationKey)
    }
    print("[MigrationManager] All migration flags have been reset.")
  }
}
