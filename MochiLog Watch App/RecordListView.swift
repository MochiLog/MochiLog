//
//  RecordListView.swift
//  MochiLog Watch App
//
//  Created by りゅうや on 2026/01/30.
//

import SwiftUI

/// 特定デバイスのレコード一覧ビュー
struct RecordListView: View {
  let deviceName: String
  let records: [WatchBatteryRecord]

  var body: some View {
    List {
      ForEach(records, id: \.id) { record in
        NavigationLink(destination: RecordDetailView(record: record)) {
          RecordRow(record: record)
        }
        .accessibilityIdentifier("watch.record")
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .listRowBackground(Color.clear)
      }
    }
    .listStyle(.plain)
    .navigationTitle(deviceName)
    .navigationBarTitleDisplayMode(.large)
  }
}

// MARK: - レコード行

struct RecordRow: View {
  let record: WatchBatteryRecord

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      // 日付
      Text(record.logDate, style: .date)
        .font(.caption)
        .foregroundStyle(.secondary)

      // メトリクス
      HStack(spacing: 10) {
        // ヘルス
        HStack(spacing: 4) {
          Circle()
            .fill(healthGradient)
            .frame(width: 8, height: 8)

          Text(record.healthPercentText)
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(healthGradient)
        }

        Divider()
          .frame(height: 14)

        // サイクル数
        HStack(spacing: 4) {
          Image(systemName: "gauge")
            .font(.caption2)
            .foregroundStyle(.secondary)

          Text("\(record.cycleCount)\(L10n.string("cycles_suffix"))")
            .font(.subheadline)
            .foregroundStyle(.primary)
        }

        Spacer()

        // インジケーター
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }

      // 診断結果
      if !record.diagnosticResult.isEmpty {
        Text(record.localizedDiagnosticResult)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.vertical, 4)
    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    .contentShape(Rectangle())
  }

  /// ヘルスステータスのグラデーション（iOS側と統一）
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
  NavigationStack {
    RecordListView(
      deviceName: "iPhone 15 Pro",
      records: [
        WatchBatteryRecord(
          deviceName: "iPhone 15 Pro",
          logDate: Date(),
          cycleCount: 120,
          nominalHealthPercent: 95,
          healthPercent: 95,
          diagnosticResult: "正常"
        ),
        WatchBatteryRecord(
          deviceName: "iPhone 15 Pro",
          logDate: Date().addingTimeInterval(-86400 * 30),
          cycleCount: 90,
          nominalHealthPercent: 88,
          healthPercent: 88,
          diagnosticResult: "良好"
        ),
      ]
    )
  }
}
