// BatchImportResultView.swift
// 共有メニューからの複数ファイルインポート結果を表示するシート
// 処理と同時に開き、各ファイルの状態をリアルタイムで更新する
import SwiftUI

// MARK: - インポート結果モデル

/// 1ファイルあたりのインポート結果
struct FileImportResult: Identifiable {
  let id: Int  // インデックスをIDとして使用（安定した順序のため）
  /// 元のファイル名
  let filename: String
  /// ログから解析した日付
  let parsedDate: Date?
  /// 解決されたデバイス名
  let deviceName: String?
  /// ログの生テキスト（手動インポートフォールバック用）
  let rawText: String?
  /// 処理ステータス
  let status: ImportStatus
  /// エラーメッセージ（status == .error の場合のみ）
  let errorMessage: String?
  /// Mac経由ログの取得元個体。手動確認へ進んでも維持する。
  var physicalDeviceID: UUID? = nil
  /// Keep the original inbox file until a manual import is durably saved.
  var sourceURL: URL? = nil
  var reviewSignature: BatchReviewSignature? = nil

  /// インポートステータス
  enum ImportStatus: Equatable {
    case processing  // パース中（スピナー表示）
    case success     // 保存成功
    case duplicate   // 重複スキップ
    case needsReview // 手動選択が必要（Watch複数・手動デバイスモード）
    case error       // 解析・保存エラー

    var iconName: String {
      switch self {
      case .processing:  return "ellipsis.circle.fill"
      case .success:     return "checkmark.circle.fill"
      case .duplicate:   return "arrow.triangle.2.circlepath.circle.fill"
      case .needsReview: return "hand.raised.fill"
      case .error:       return "xmark.circle.fill"
      }
    }

    var color: Color {
      switch self {
      case .processing:  return Color(uiColor: .secondaryLabel)
      case .success:     return Color(red: 0.18, green: 0.73, blue: 0.44)
      case .duplicate:   return Color(red: 0.98, green: 0.62, blue: 0.12)
      case .needsReview: return Color(red: 0.35, green: 0.37, blue: 0.90)
      case .error:       return Color(red: 0.92, green: 0.27, blue: 0.27)
      }
    }

    var label: String {
      switch self {
      case .processing:  return L10n.string("processing", table: "BatchImport")
      case .success:     return L10n.string("saved", table: "BatchImport")
      case .duplicate:   return L10n.string("duplicate_skipped", table: "BatchImport")
      case .needsReview: return L10n.string("review", table: "BatchImport")
      case .error:       return L10n.string("error", table: "BatchImport")
      }
    }

    var isCompleted: Bool {
      self != .processing
    }
  }
}

struct BatchReviewSignature {
  let logDate: Date
  let cycleCount: Int
  let nominalCapacity: Int
  let rawCapacity: Int
  let physicalDeviceID: UUID?

  func matches(_ record: BatteryRecord) -> Bool {
    abs(record.logDate.timeIntervalSince(logDate)) < 1
      && record.cycleCount == cycleCount
      && record.nominalCapacity == nominalCapacity
      && record.rawCapacity == rawCapacity
      && (physicalDeviceID == nil || record.physicalDeviceID == physicalDeviceID)
  }
}

struct PendingBatchReview {
  let sourceURL: URL
  let signature: BatchReviewSignature
  let existingRecordIDs: Set<UUID>
}

// MARK: - 結果画面ビュー

/// 共有インポートの結果シート
/// results はリアルタイムで更新される @Binding を受け取る
struct BatchImportResultView: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Binding var results: [FileImportResult]
  let onResolve: (FileImportResult) -> Void
  let onDismiss: () -> Void

  // MARK: - 集計値（処理完了済みのみカウント）

  private var completedCount: Int   { results.filter { $0.status.isCompleted }.count }
  private var processingCount: Int  { results.filter { $0.status == .processing   }.count }
  private var successCount: Int     { results.filter { $0.status == .success      }.count }
  private var duplicateCount: Int   { results.filter { $0.status == .duplicate    }.count }
  private var needsReviewCount: Int { results.filter { $0.status == .needsReview  }.count }
  private var errorCount: Int       { results.filter { $0.status == .error        }.count }
  private var isAllDone: Bool       { processingCount == 0 }

  // MARK: - Body

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          summaryCard
          resultList
        }
        .frame(maxWidth: 850)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
      }
      .background(Color(uiColor: .systemGroupedBackground))
      .navigationTitle(L10n.string("title", table: "BatchImport"))
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(L10n.string("done", table: "BatchImport")) {
            onDismiss()
          }
          .fontWeight(.semibold)
          // 全件完了まで非活性
          .disabled(!isAllDone)
        }
      }
    }
    .interactiveDismissDisabled(!isAllDone)
  }

  // MARK: - サマリーカード

  private var summaryCard: some View {
    VStack(spacing: 14) {
      // ヘッダー行：処理状況メッセージ
      if isAllDone {
        Label {
          Text(String(format: L10n.string("completed_count", table: "BatchImport"), results.count))
            .font(.headline)
        } icon: {
          Image(systemName: "checkmark.circle")
            .foregroundStyle(Color(red: 0.18, green: 0.73, blue: 0.44))
        }
      } else {
        HStack(spacing: 10) {
          ProgressView()
            .scaleEffect(0.85)
          Text(String(format: L10n.string("progress_count", table: "BatchImport"), completedCount, results.count))
            .font(.headline)
            .contentTransition(.numericText())
            .animation(.spring(duration: 0.3), value: completedCount)
        }
      }

      // 成功 / 重複 / 要手動選択 / エラー バッジ行
      LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count:
        dynamicTypeSize.isAccessibilitySize ? 1 : (horizontalSizeClass == .compact ? 2 : 4)), spacing: 16) {
        summaryBadge(
          count: successCount,
          label: L10n.string("saved", table: "BatchImport"),
          color: FileImportResult.ImportStatus.success.color,
          icon: "checkmark.circle.fill"
        )
        summaryBadge(
          count: duplicateCount,
          label: L10n.string("duplicate", table: "BatchImport"),
          color: FileImportResult.ImportStatus.duplicate.color,
          icon: "arrow.triangle.2.circlepath.circle.fill"
        )
        summaryBadge(
          count: needsReviewCount,
          label: L10n.string("manual_selection", table: "BatchImport"),
          color: FileImportResult.ImportStatus.needsReview.color,
          icon: "hand.raised.fill"
        )
        summaryBadge(
          count: errorCount,
          label: L10n.string("error", table: "BatchImport"),
          color: FileImportResult.ImportStatus.error.color,
          icon: "xmark.circle.fill"
        )
      }
    }
    .padding(.vertical, 18)
    .padding(.horizontal, 12)
    .frame(maxWidth: .infinity)
    .background(Color(uiColor: .secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .animation(.spring(duration: 0.4), value: isAllDone)
  }

  /// サマリーカード内の1列バッジ
  private func summaryBadge(count: Int, label: String, color: Color, icon: String) -> some View {
    VStack(spacing: 6) {
      Image(systemName: icon)
        .font(.title2.weight(.medium))
        .foregroundStyle(count > 0 ? color : Color(uiColor: .tertiaryLabel))
      Text("\(count)")
        .font(.system(.title, design: .rounded).bold())
        .foregroundStyle(count > 0 ? color : Color(uiColor: .tertiaryLabel))
        .contentTransition(.numericText())
        .animation(.spring(duration: 0.4), value: count)
      Text(label)
        .font(.caption)
        .foregroundStyle(Color(uiColor: .secondaryLabel))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - 結果リスト

  private var resultList: some View {
    LazyVStack(spacing: 0) {
      ForEach(results) { result in
        ResultRowView(result: result, onResolve: {
          if isAllDone { onResolve(result) }
        })
          .disabled(!isAllDone)
          .transition(
            .asymmetric(
              insertion: .opacity.combined(with: .move(edge: .top)),
              removal: .opacity
            )
          )
        if result.id < results.count - 1 {
          Divider()
            .padding(.leading, 56)
        }
      }
    }
    .background(Color(uiColor: .secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .animation(.spring(duration: 0.4), value: results.map { $0.status })
  }
}

// MARK: - 結果行

/// 1件分の結果行
private struct ResultRowView: View {
  let result: FileImportResult
  let onResolve: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      // ステータスアイコン（処理中はスピナー）
      ZStack {
        if result.status == .processing {
          ProgressView()
            .frame(width: 28, height: 28)
        } else {
          Image(systemName: result.status.iconName)
            .font(.system(size: 24, weight: .medium))
            .foregroundStyle(result.status.color)
            .transition(.scale.combined(with: .opacity))
        }
      }
      .frame(width: 32)
      .padding(.top, 2)
      .animation(.spring(duration: 0.4), value: result.status)

      VStack(alignment: .leading, spacing: 5) {
        // デバイス名
        if let device = result.deviceName {
          Text(DeviceLibrary.localizedName(for: device))
            .font(.body.weight(.semibold))
            .foregroundStyle(.primary)
            .transition(.opacity)
        } else if result.status == .processing {
          Text(L10n.string("parsing", table: "BatchImport"))
            .font(.body.weight(.semibold))
            .foregroundStyle(Color(uiColor: .secondaryLabel))
        } else {
          Text(L10n.string("unknown_device", table: "BatchImport"))
            .font(.body.weight(.semibold))
            .foregroundStyle(Color(uiColor: .secondaryLabel))
        }

        // 日付
        if let date = result.parsedDate {
          Label {
            Text(date.formatted(date: .long, time: .omitted))
              .font(.subheadline)
              .foregroundStyle(Color(uiColor: .secondaryLabel))
          } icon: {
            Image(systemName: "calendar")
              .font(.caption)
              .foregroundStyle(Color(uiColor: .tertiaryLabel))
          }
          .transition(.opacity.combined(with: .move(edge: .top)))
        }

        // ファイル名
        Label {
          Text(result.filename)
            .font(.caption)
            .foregroundStyle(Color(uiColor: .tertiaryLabel))
            .lineLimit(2)
            .truncationMode(.middle)
        } icon: {
          Image(systemName: "doc")
            .font(.caption2)
            .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }

        HStack(spacing: 12) {
          Label(result.status.label, systemImage: result.status.iconName)
            .font(.caption.weight(.medium))
            .foregroundStyle(result.status.color)
            .fixedSize(horizontal: false, vertical: true)
          if result.status == .needsReview {
            Button(L10n.string("add_manually", table: "BatchImport"), action: onResolve)
              .font(.body.weight(.semibold))
              .frame(minHeight: 44)
              .buttonStyle(.bordered)
          }
        }

        // エラーメッセージ（エラー時のみ）
        if let errorMsg = result.errorMessage {
          Text(errorMsg)
            .font(.caption)
            .foregroundStyle(result.status.color)
            .padding(.top, 2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(result.status.color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
      .animation(.spring(duration: 0.4), value: result.deviceName)
      .animation(.spring(duration: 0.4), value: result.parsedDate)
      .animation(.spring(duration: 0.4), value: result.errorMessage)


    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}
