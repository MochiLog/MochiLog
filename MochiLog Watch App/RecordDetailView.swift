//
//  RecordDetailView.swift
//  MochiLog Watch App
//
//  Created by りゅうや on 2026/01/30.
//

import SwiftUI

/// バッテリーレコードの詳細ビュー
struct RecordDetailView: View {
  let record: WatchBatteryRecord

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        // ヘルスリング（iOS側と同じスタイル）
        HealthRingView(
          percentage: record.displayedHealthPercent
        )
        .frame(height: 120)
        .padding(.top, 8)

        // メトリクス（全情報表示）
        VStack(spacing: 12) {
          // 実測ヘルス
          MetricRow(
            icon: "heart.fill",
            label: L10n.string("actual_health"),
            value: record.healthPercentText
          )

          // 公称ヘルス
          MetricRow(
            icon: "heart",
            label: L10n.string("nominal_health"),
            value: record.nominalHealthPercentText
          )

          // サイクル数
          MetricRow(
            icon: "gauge",
            label: L10n.string("cycle_count"),
            value: String(format: L10n.string("cycles_count"), record.cycleCount)
          )

          // 診断結果
          if !record.diagnosticResult.isEmpty {
            HStack(spacing: 8) {
              Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundStyle(.green)

              VStack(alignment: .leading, spacing: 2) {
                Text(L10n.string("diagnostic_result"))
                  .font(.caption2)
                  .foregroundStyle(.secondary)

                Text(record.localizedDiagnosticResult)
                  .font(.subheadline)
                  .fontWeight(.medium)
              }

              Spacer()
            }
            .padding(10)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.15))
            )
          }

          // ログ日時（詳細表示）
          VStack(alignment: .leading, spacing: 4) {
            Text(L10n.string("log_date"))
              .font(.caption)
              .foregroundStyle(.secondary)

            Text(formatDateFull(record.logDate))
              .font(.subheadline)
              .fontWeight(.medium)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(10)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(Color.gray.opacity(0.15))
          )

          // デバイス名
          VStack(alignment: .leading, spacing: 4) {
            Text(L10n.string("device_name"))
              .font(.caption)
              .foregroundStyle(.secondary)

            Text(record.deviceName)
              .font(.subheadline)
              .fontWeight(.medium)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(10)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(Color.gray.opacity(0.15))
          )
        }
      }
      .padding(.horizontal, 8)
      .padding(.bottom, 16)
    }
    .navigationTitle(record.deviceName)
    .navigationBarTitleDisplayMode(.inline)
  }

  /// 日付をフォーマット
  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M/d HH:mm"
    return formatter.string(from: date)
  }

  /// 日付を詳細フォーマット
  private func formatDateFull(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = L10n.locale
    formatter.dateStyle = .long
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}

// MARK: - ヘルスリング（iOS側と同じスタイル）

struct HealthRingView: View {
  let percentage: Int?

  var body: some View {
    ZStack {
      // 背景リング
      Circle()
        .stroke(Color.gray.opacity(0.2), lineWidth: 10)

      // プログレスリング（iOS側と同じグラデーション）
      Circle()
        .trim(from: 0, to: CGFloat(min(max(percentage ?? 0, 0), 100)) / 100)
        .stroke(
          AngularGradient(
            gradient: Gradient(colors: [.green, .green]),
            center: .center
          ),
          style: StrokeStyle(lineWidth: 10, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.easeInOut, value: percentage)

      // 中央テキスト
      VStack(spacing: 2) {
        Text(WatchBatteryRecord.percentageText(percentage))
          .font(.title2)
          .fontWeight(.bold)
      }
    }
    .padding(8)
  }
}

// MARK: - メトリクス行

struct MetricRow: View {
  let icon: String
  let label: String
  let value: String

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack {
        Label(label, systemImage: icon).font(.caption).foregroundStyle(.secondary)
        Spacer()
        Text(value).font(.headline).fontWeight(.semibold)
      }
      .fixedSize(horizontal: true, vertical: false)
      VStack(alignment: .leading, spacing: 4) {
        Label(label, systemImage: icon).font(.caption).foregroundStyle(.secondary)
        Text(value).font(.headline).fontWeight(.semibold)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 4)
  }
}

// MARK: - プレビュー

#Preview {
  NavigationStack {
    RecordDetailView(
      record: WatchBatteryRecord(
        deviceName: "iPhone 15 Pro",
        logDate: Date(),
        cycleCount: 120,
        nominalHealthPercent: 95,
        healthPercent: 95,
        diagnosticResult: "✅ 正常"
      )
    )
  }
}
