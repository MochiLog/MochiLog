import SwiftUI

struct ConflictDetailView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var dataStore: DataStore

  let conflict: SyncConflictItem
  let syncManager = ICloudSyncManager.shared

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          // ヘッダー説明
          Text(
            L10n.string(
              "conflict_detail_description",
              defaultValue: "同一の記録が複数のデバイスで同時に変更されました。以下の差分を確認し、どちらのデータを保持するか選択してください。",
              table: "Settings")
          )
          .font(.subheadline)
          .foregroundColor(.secondary)
          .padding(.horizontal)
          .padding(.top)

          // 差分テーブル
          GroupBox {
            VStack(spacing: 0) {
              // テーブルヘッダー
              HStack {
                Text(L10n.string("conflict_property", defaultValue: "項目", table: "Settings"))
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .frame(maxWidth: .infinity, alignment: .leading)

                Text(L10n.string("conflict_local", defaultValue: "ローカル", table: "Settings"))
                  .font(.caption)
                  .bold()
                  .foregroundColor(.blue)
                  .frame(width: 100, alignment: .trailing)

                Text(L10n.string("conflict_server", defaultValue: "サーバー", table: "Settings"))
                  .font(.caption)
                  .bold()
                  .foregroundColor(.green)
                  .frame(width: 100, alignment: .trailing)
              }
              .padding(.bottom, 8)

              Divider()

              // 比較行
              buildComparisonRow(
                title: L10n.string("device_name", table: "Common"),
                localValue: conflict.localDevice,
                serverValue: conflict.serverDevice
              )

              buildComparisonRow(
                title: L10n.string("log_date", defaultValue: "記録日時", table: "Common"),
                localValue: format(date: conflict.localDate),
                serverValue: format(date: conflict.serverDate)
              )

              buildComparisonRow(
                title: L10n.string("cycle_count", table: "Analytics"),
                localValue: format(int: conflict.localCycleCount),
                serverValue: format(int: conflict.serverCycleCount)
              )

              buildComparisonRow(
                title: L10n.string(
                  "nominal_capacity", defaultValue: "最大容量(mAh)", table: "Analytics"),
                localValue: format(int: conflict.localNominalCapacity),
                serverValue: format(int: conflict.serverNominalCapacity)
              )

              buildComparisonRow(
                title: L10n.string(
                  "design_capacity", defaultValue: "設計容量(mAh)", table: "Analytics"),
                localValue: format(int: conflict.localDesignCapacity),
                serverValue: format(int: conflict.serverDesignCapacity)
              )

              buildComparisonRow(
                title: L10n.string(
                  "battery_health_percent", defaultValue: "設定アプリ表示(%)", table: "Settings"),
                localValue: format(percent: conflict.localSettingsDisplayPercent),
                serverValue: format(percent: conflict.serverSettingsDisplayPercent)
              )
            }
            .padding(8)
          }
          .padding(.horizontal)

          // 解決アクションボタン群
          VStack(spacing: 12) {
            Button {
              resolve(.local)
            } label: {
              Text(L10n.string("keep_local", defaultValue: "ローカルのデータを優先", table: "Settings"))
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .cornerRadius(12)
            }

            Button {
              resolve(.server)
            } label: {
              Text(L10n.string("keep_server", defaultValue: "サーバーのデータを優先", table: "Settings"))
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.15))
                .foregroundColor(.green)
                .cornerRadius(12)
            }

            Button {
              resolve(.all)
            } label: {
              Text(L10n.string("keep_both", defaultValue: "両方残す (新しい記録として複製)", table: "Settings"))
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.15))
                .foregroundColor(.orange)
                .cornerRadius(12)
            }
          }
          .padding(.horizontal)
          .padding(.bottom, 32)
        }
      }
      .navigationTitle(L10n.string("resolve_conflict", defaultValue: "競合の解決", table: "Settings"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.string("cancel", table: "Common")) {
            dismiss()
          }
        }
      }
    }
  }

  // MARK: - Helpers

  private func resolve(_ resolution: SyncConflictResolution) {
    syncManager.resolveConflict(conflict, resolution: resolution, dataStore: dataStore)
    dismiss()
  }

  @ViewBuilder
  private func buildComparisonRow(title: String, localValue: String, serverValue: String)
    -> some View
  {
    let isDifferent = localValue != serverValue

    VStack(spacing: 0) {
      HStack {
        Text(title)
          .font(.subheadline)
          .foregroundColor(.primary)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text(localValue)
          .font(.subheadline)
          .foregroundColor(isDifferent ? .red : .secondary)
          .bold(isDifferent)
          .frame(width: 100, alignment: .trailing)

        Text(serverValue)
          .font(.subheadline)
          .foregroundColor(isDifferent ? .red : .secondary)
          .bold(isDifferent)
          .frame(width: 100, alignment: .trailing)
      }
      .padding(.vertical, 12)

      Divider()
    }
  }

  private func format(date: Date?) -> String {
    guard let date = date else { return "-" }
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  private func format(int: Int?) -> String {
    guard let val = int else { return "-" }
    return "\(val)"
  }

  private func format(percent: Int?) -> String {
    guard let val = percent else { return "-" }
    return "\(val)%"
  }
}
