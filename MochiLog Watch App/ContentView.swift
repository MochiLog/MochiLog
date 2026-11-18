//
//  ContentView.swift
//  MochiLog Watch App
//
//  Created by りゅうや on 2026/01/30.
//

import SwiftUI

/// メインコンテンツビュー - デバイス一覧を表示
struct ContentView: View {
  @EnvironmentObject var connectivityManager: WatchConnectivityManager

  var body: some View {
    NavigationStack {
      Group {
        if connectivityManager.records.isEmpty {
          emptyStateView
        } else {
          deviceListView
        }
      }
      .navigationTitle("MochiLog")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  // MARK: - デバイス一覧

  private var deviceListView: some View {
    List {
      // サンプルモード表示バナー
      if connectivityManager.isSampleMode {
        HStack(spacing: 6) {
          Image(systemName: "eye.fill")
            .font(.caption)
            .foregroundStyle(.orange)
          Text(L10n.string("sample_data_viewing"))
            .font(.caption)
            .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(Color.orange.opacity(0.15))
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .listRowBackground(Color.clear)
      }

      ForEach(groupedDevices, id: \.name) { device in
        NavigationLink(
          destination: RecordListView(deviceName: device.name, records: device.records)
        ) {
          DeviceCard(device: device)
        }
        .accessibilityIdentifier("watch.device.\(device.name)")
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .listRowBackground(Color.clear)
      }

      // 最終同期情報
      if let lastSync = connectivityManager.lastSyncDate {
        Section {
          HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.2.circlepath")
              .font(.caption2)
            Text(
              "\(L10n.string("last_sync")) \(lastSync, format: .dateTime.month().day().hour().minute())"
            )
          }
          .font(.caption2)
          .foregroundStyle(.secondary)
          .padding(.vertical, 2)
        }
        .listRowBackground(Color.clear)
      }
    }
    .listStyle(.plain)
  }

  // MARK: - 空の状態

  private var emptyStateView: some View {
    ScrollView {
      VStack(spacing: 16) {
        Spacer()
          .frame(height: 20)

        // アイコン
        ZStack {
          Circle()
            .fill(
              LinearGradient(
                colors: [
                  Color.green.opacity(0.3),
                  Color.green.opacity(0.1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: 70, height: 70)

          Image(systemName: "battery.100")
            .font(.system(size: 32))
            .foregroundStyle(Color.green)
        }

        // メインメッセージ
        VStack(spacing: 8) {
          Text(L10n.string("waiting_for_data"))
            .font(.headline)
            .fontWeight(.semibold)
            .multilineTextAlignment(.center)

          Text(L10n.string("waiting_for_data_description"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
        }

        // 同期ステータス
        VStack(spacing: 8) {
          if connectivityManager.isReachable {
            Label(L10n.string("iphone_connected"), systemImage: "checkmark.circle.fill")
              .font(.caption2)
              .foregroundStyle(.green)
          } else {
            Label(L10n.string("iphone_not_connected"), systemImage: "iphone.slash")
              .font(.caption2)
              .foregroundStyle(.orange)
          }

          if let lastSync = connectivityManager.lastSyncDate {
            Text(
              "\(L10n.string("last_sync")) \(lastSync, format: .dateTime.month().day().hour().minute())"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
          }
        }

        // エラーメッセージ
        if let error = connectivityManager.syncError {
          Text(error)
            .font(.caption2)
            .foregroundStyle(.red)
            .padding(.horizontal)
            .multilineTextAlignment(.center)
        }

        // 同期ボタン
        Button {
          connectivityManager.requestDataFromiPhone()
        } label: {
          if connectivityManager.isSyncing {
            HStack(spacing: 6) {
              ProgressView()
                .scaleEffect(0.8)
              Text(L10n.string("syncing"))
            }
            .font(.subheadline)
            .fontWeight(.medium)
          } else {
            Label(L10n.string("sync_now"), systemImage: "arrow.triangle.2.circlepath")
              .font(.subheadline)
              .fontWeight(.medium)
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!connectivityManager.isReachable || connectivityManager.isSyncing)

        Spacer()
      }
      .padding()
    }
  }

  // MARK: - データ処理

  /// デバイスごとにグループ化されたレコード
  private var groupedDevices: [DeviceGroup] {
    let grouped = Dictionary(grouping: connectivityManager.records) { $0.deviceName }
    return grouped.map { name, records in
      let sortedRecords = records.sorted { $0.logDate > $1.logDate }
      let latestRecord = sortedRecords.first!
      return DeviceGroup(
        name: name,
        latestHealth: latestRecord.displayedHealthPercent,
        latestCycleCount: latestRecord.cycleCount,
        records: sortedRecords
      )
    }.sorted { $0.name < $1.name }
  }
}

// MARK: - デバイスグループ

struct DeviceGroup {
  let name: String
  let latestHealth: Int?
  let latestCycleCount: Int
  let records: [WatchBatteryRecord]
}

// MARK: - デバイスカード

struct DeviceCard: View {
  let device: DeviceGroup

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      // デバイス名
      Text(device.name)
        .font(.headline)
        .fontWeight(.semibold)
        .lineLimit(2)

      // メトリクス
      HStack(spacing: 12) {
        // ヘルス
        HStack(spacing: 4) {
          Image(systemName: "bolt.heart.fill")
            .font(.caption)
            .foregroundStyle(healthGradient)

          Text(WatchBatteryRecord.percentageText(device.latestHealth))
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(healthGradient)
        }

        Divider()
          .frame(height: 12)

        // サイクル数
        HStack(spacing: 4) {
          Image(systemName: "gauge")
            .font(.caption)
            .foregroundStyle(.secondary)

          Text("\(device.latestCycleCount)\(L10n.string("cycles_suffix"))")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }

      // レコード数
      Text(
        L10n.string("logs_count", defaultValue: "%d logs", table: nil, comment: "")
          .replacingOccurrences(of: "%d", with: "\(device.records.count)")
      )
      .font(.caption2)
      .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    .contentShape(Rectangle())
  }

  /// ヘルスパーセンテージに応じたグラデーション（iOS側と統一）
  private var healthGradient: LinearGradient {
    LinearGradient(
      colors: [.green, .green.opacity(0.8)],
      startPoint: .leading,
      endPoint: .trailing
    )
  }
}

// MARK: - プレビュー

#Preview {
  ContentView()
    .environmentObject(WatchConnectivityManager.shared)
}
