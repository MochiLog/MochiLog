import SwiftUI

// MARK: - インポート進捗シート

/// インポート処理中に表示されるプログレスシート
/// interactiveDismissDisabled(true) で閉じられないように制御される
struct ImportProgressSheet: View {
  @Binding var progress: Double
  @ObservedObject private var rendering = RenderingPreferences.shared
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// アイコンアニメーション用のState（iOS 16用ローテーションアニメーション）
  @State private var isAnimating = false

  /// 進捗に応じたステージラベルを返す
  private var stageLabel: String {
    switch progress {
    case ..<0.11:
      return L10n.string(
        "import_stage_reading",
        defaultValue: "ファイルを読み込んでいます…",
        table: "Settings")
    case ..<0.25:
      return L10n.string(
        "import_stage_decoding",
        defaultValue: "データを解析しています…",
        table: "Settings")
    case ..<0.35:
      return L10n.string(
        "import_stage_indexing",
        defaultValue: "重複チェックの準備中…",
        table: "Settings")
    case ..<0.72:
      return L10n.string(
        "import_stage_converting",
        defaultValue: "レコードを変換しています…",
        table: "Settings")
    case ..<0.99:
      return L10n.string(
        "import_stage_saving",
        defaultValue: "データを保存しています…",
        table: "Settings")
    default:
      return L10n.string(
        "import_stage_done",
        defaultValue: "完了しています…",
        table: "Settings")
    }
  }

  var body: some View {
    VStack(spacing: 32) {
      // アニメーションアイコン
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [Color.green.opacity(0.15), Color.blue.opacity(0.10)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 96, height: 96)

        if rendering.reduced || reduceMotion {
          Image(systemName: "arrow.down.doc.fill")
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(.tint)
        } else if #available(iOS 17, *) {
          // iOS 17+: symbolEffect で pulse アニメーション
          Image(systemName: "arrow.down.doc.fill")
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(
              LinearGradient(
                colors: [.green, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .symbolEffect(.pulse, options: .repeating)
        } else {
          // iOS 16: rotationEffect + animation で代替
          Image(systemName: "arrow.down.doc.fill")
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(
              LinearGradient(
                colors: [.green, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .scaleEffect(isAnimating ? 1.1 : 0.95)
            .animation(
              .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
              value: isAnimating
            )
            .onAppear { isAnimating = true }
        }
      }

      VStack(spacing: 12) {
        Text(
          L10n.string(
            "importing_data_title",
            defaultValue: "データをインポート中",
            table: "Settings")
        )
        .font(.title3)
        .fontWeight(.semibold)
        .foregroundStyle(.primary)

        Text(stageLabel)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .animation(.easeInOut(duration: 0.3), value: stageLabel)
      }

      // プログレスバー
      VStack(spacing: 8) {
        ProgressView(value: progress)
          .progressViewStyle(
            ImportProgressBarStyle()
          )
          .animation(.easeOut(duration: 0.25), value: progress)

        HStack {
          Spacer()
          Text("\(Int(progress * 100))%")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .animation(.easeOut(duration: 0.25), value: progress)
        }
      }
      .padding(.horizontal, 8)
    }
    .padding(.horizontal, 40)
    .padding(.vertical, 48)
    .frame(maxWidth: 400)
    .presentationDetents([.height(320)])
    .presentationDragIndicator(.hidden)
    .modifier(PresentationCornerRadiusModifier(radius: 24))
  }
}

// MARK: - presentationCornerRadius の iOS 16.4+ 互換モディファイア

/// iOS 16.4+ で presentationCornerRadius を適用するモディファイア
private struct PresentationCornerRadiusModifier: ViewModifier {
  let radius: CGFloat

  func body(content: Content) -> some View {
    if #available(iOS 16.4, *) {
      content.presentationCornerRadius(radius)
    } else {
      content
    }
  }
}

// MARK: - カスタムプログレスバースタイル

/// グラデーション付きのプログレスバースタイル
private struct ImportProgressBarStyle: ProgressViewStyle {
  func makeBody(configuration: Configuration) -> some View {
    let fraction = configuration.fractionCompleted ?? 0

    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        // バックグラウンドトラック
        RoundedRectangle(cornerRadius: 6)
          .fill(Color(.systemFill))
          .frame(height: 12)

        // 進捗フィル
        RoundedRectangle(cornerRadius: 6)
          .fill(
            LinearGradient(
              colors: [.green, .blue],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(
            width: max(12, geometry.size.width * fraction),
            height: 12
          )
      }
    }
    .frame(height: 12)
  }
}

#Preview {
  ImportProgressSheet(progress: .constant(0.55))
}
