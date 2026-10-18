import SwiftUI
import UIKit  // for UIImage

// MARK: - チュートリアルビュー
struct TutorialView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var appSettings = AppSettings.shared
  @State private var currentPage = 0
  @State private var showingVideoPlayer = false
  @State private var pipController: PIPTutorialController?

  private let pages: [TutorialPage] = [
    // ステップ1: ウェルカム
    TutorialPage(
      icon: "hand.wave.fill",
      iconColor: .green,
      titleKey: "tutorial_welcome",
      descriptionKey: "tutorial_welcome_description",
      imageName: nil,
      showSettingsButton: false,
      showVideoButton: false
    ),
    // ステップ2: 設定アプリを開く
    TutorialPage(
      icon: "gear",
      iconColor: .gray,
      titleKey: "tutorial_open_settings_title",
      descriptionKey: "tutorial_open_settings_description",
      imageName: nil,
      showSettingsButton: true,
      showVideoButton: false,
      customButtonTitleKey: "try_with_video",  // 動画を見ながら実際にやる
      actionType: .openSheet  // シートを開く
    ),
    // ステップ3: 設定のトップに戻る
    TutorialPage(
      icon: "chevron.left",
      iconColor: .blue,
      titleKey: "tutorial_go_to_settings_top_title",
      descriptionKey: "tutorial_go_to_settings_top_description",
      imageName: nil,
      showSettingsButton: false,
      showVideoButton: false
    ),
    // ステップ3.3: プライバシーとセキュリティ
    TutorialPage(
      icon: "hand.raised.fill",
      iconColor: .blue,
      titleKey: "tutorial_privacy_security_title",
      descriptionKey: "tutorial_privacy_security_description",
      imageName: nil,
      showSettingsButton: false,
      showVideoButton: false
    ),
    // ステップ3.5: 解析と改善
    TutorialPage(
      icon: "chart.bar.xaxis",
      iconColor: .gray,
      titleKey: "tutorial_analytics_improvements_title",
      descriptionKey: "tutorial_analytics_improvements_description",
      imageName: nil,
      showSettingsButton: false,
      showVideoButton: false
    ),
    // ステップ4: 共有ON
    TutorialPage(
      icon: "switch.2",
      iconColor: .green,
      titleKey: "tutorial_share_on_title",
      descriptionKey: "tutorial_share_on_description",  // iPhone/iPad解析を共有: ON
      imageName: nil,
      showSettingsButton: false,
      showVideoButton: false
    ),
    // ステップ4.5: ログ生成タイミングの注意
    TutorialPage(
      icon: "clock.fill",
      iconColor: .orange,
      titleKey: "tutorial_log_timing_title",
      descriptionKey: "tutorial_log_timing_description",
      imageName: nil,
      showSettingsButton: false,
      showVideoButton: false
    ),
    // ステップ5: ログファイルを探す
    TutorialPage(
      icon: "doc.text.magnifyingglass",
      iconColor: .orange,
      titleKey: "tutorial_find_log_title",
      descriptionKey: "tutorial_find_log_description",  // Analytics-202x...
      imageName: nil,
      showSettingsButton: false,
      showVideoButton: false
    ),
    // ステップ5.5: ログファイル選択の注意
    TutorialPage(
      icon: "exclamationmark.triangle.fill",
      iconColor: .yellow,
      titleKey: "tutorial_log_selection_title",
      descriptionKey: "tutorial_log_selection_description",
      imageName: nil,
      showSettingsButton: false,
      showVideoButton: false
    ),
    // ステップ6: MochiLogに共有
    TutorialPage(
      icon: "square.and.arrow.up",  // ここはアプリアイコンにしたいが、一旦SF Symbolで
      iconColor: .blue,
      titleKey: "tutorial_share_title",
      descriptionKey: "tutorial_share_description",  // 共有ボタン > MochiLog
      imageName: nil,
      showSettingsButton: false,
      showVideoButton: false,
      useAppIcon: true  // 新規フラグ
    ),
    // ステップ7: 完了
    TutorialPage(
      icon: "checkmark.circle.fill",
      iconColor: .green,
      titleKey: "tutorial_complete_title",
      descriptionKey: "tutorial_complete_description",
      imageName: nil,
      showSettingsButton: false,
      showVideoButton: false
    ),
  ]

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // ページインジケーター
        HStack(spacing: 8) {
          ForEach(0..<pages.count, id: \.self) { index in
            Circle()
              .fill(index == currentPage ? Color.green : Color.gray.opacity(0.3))
              .frame(width: 8, height: 8)
              .animation(.easeInOut, value: currentPage)
          }
        }
        .padding(.top, 20)

        // コンテンツ
        TabView(selection: $currentPage) {
          ForEach(0..<pages.count, id: \.self) { index in
            TutorialPageView(
              page: pages[index],
              onOpenSettings: { view in
                if pages[index].actionType == .openSheet {
                  showingVideoPlayer = true
                } else {
                  openSettingsWithPIP(sourceView: view)
                }
              },
              onOpenVideo: { showingVideoPlayer = true }
            )
            .tag(index)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))

        // ボタン
        VStack(spacing: 16) {
          // 次へ/完了ボタン - 常に同じ構造を維持
          ZStack {
            // 次へボタン
            Button(action: {
              withAnimation {
                currentPage += 1
              }
            }) {
              Text(L10n.string("next", table: "Common"))
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(14)
            }
            .opacity(currentPage < pages.count - 1 ? 1 : 0)
            .allowsHitTesting(currentPage < pages.count - 1)

            // 完了ボタン
            Button(action: {
              appSettings.completeTutorial()
              dismiss()
            }) {
              Text(L10n.string("got_it", table: "Common"))
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(14)
            }
            .opacity(currentPage >= pages.count - 1 ? 1 : 0)
            .allowsHitTesting(currentPage >= pages.count - 1)
          }

          // 戻るボタン - 常に存在させる
          Button(action: {
            withAnimation {
              currentPage -= 1
            }
          }) {
            Text(L10n.string("back", table: "Common"))
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
          .opacity(currentPage > 0 ? 1 : 0)
          .allowsHitTesting(currentPage > 0)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
      }
      // iPad向け: コンテンツ幅を500ptに制限し中央配置
      .frame(maxWidth: 500)
      .frame(maxWidth: .infinity)
      .navigationTitle(L10n.string("tutorial", table: "Onboarding"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.string("close", table: "Common")) {
            dismiss()
          }
        }
      }
      .sheet(isPresented: $showingVideoPlayer) {
        PIPVideoPlayerFullView()
      }
    }
  }

  // MARK: - Private Methods

  /// 設定アプリの解析データ画面を開く（PIP動画を自動起動）
  private func openSettingsWithPIP(sourceView: UIView? = nil) {
    // 動画ファイルの有無に関わらず、SwiftUI Viewを使ったPIPを開始
    pipController = PIPTutorialController()
    pipController?.startPIPAndOpenSettings(sourceView: sourceView)
  }

  /// 設定アプリの解析データ画面を開く
  private func openAnalyticsSettings() {
    SettingsRedirectHelper.redirectToPrivacyAnalytics()
  }
}

// MARK: - チュートリアルアクション型
enum TutorialAction {
  case openSettings
  case openSheet
}

// MARK: - チュートリアルページデータ
struct TutorialPage {
  let icon: String  // SF Symbol name
  let iconColor: Color
  let titleKey: String
  let descriptionKey: String
  let imageName: String?
  let showSettingsButton: Bool
  let showVideoButton: Bool
  var useAppIcon: Bool = false  // Default false
  var customButtonTitleKey: String? = nil  // 新規
  var actionType: TutorialAction = .openSettings  // 新規
}

// MARK: - チュートリアルページビュー
struct TutorialPageView: View {
  let page: TutorialPage
  var onOpenSettings: ((UIView?) -> Void)?
  var onOpenVideo: (() -> Void)?

  @State private var settingsButtonView: UIView?

  var body: some View {
    VStack(spacing: 32) {
      Spacer()

      // アイコン
      ZStack {
        Circle()
          .fill(page.iconColor.opacity(0.15))
          .frame(width: 120, height: 120)

        if page.useAppIcon, let icon = Bundle.main.icon {
          Image(uiImage: icon)
            .resizable()
            .scaledToFit()
            .frame(width: 80, height: 80)
            .cornerRadius(18)
            .mochiShadow(radius: 4)
        } else {
          Image(systemName: page.icon)
            .font(.system(size: 50))
            .foregroundStyle(page.iconColor)
        }
      }

      // テキスト
      VStack(spacing: 16) {
        Text(L10n.string(String.LocalizationValue(page.titleKey), table: "Onboarding"))
          .font(.title2)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .lineLimit(nil)
          .fixedSize(horizontal: false, vertical: true)

        Text(L10n.string(String.LocalizationValue(page.descriptionKey), table: "Onboarding"))
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .lineLimit(nil)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 16)
      }
      .padding(.horizontal, 16)

      // ボタンエリア - 常に同じ構造を維持してアニメーションを阻害しないようにする
      VStack(spacing: 12) {
        // 動画チュートリアルボタン
        Button(action: { onOpenVideo?() }) {
          HStack {
            Image(systemName: "play.rectangle.fill")
            Text(L10n.string("watch_video_tutorial", table: "Onboarding"))
          }
          .font(.subheadline)
          .foregroundColor(.blue)
        }
        .opacity(page.showVideoButton ? 1 : 0)
        .allowsHitTesting(page.showVideoButton)

        // 設定（または動画を見ながら）ボタン
        Button(action: { onOpenSettings?(settingsButtonView) }) {
          HStack {
            // アイコン: 両方のアイコンを常に存在させ、opacityで切り替え
            ZStack {
              Image(systemName: "gear")
                .opacity(page.actionType == .openSettings ? 1 : 0)
              Image(systemName: "play.circle.fill")
                .opacity(page.actionType == .openSheet ? 1 : 0)
            }

            // テキスト: 両方のテキストを常に存在させ、opacityで切り替え
            ZStack {
              Text(
                L10n.string(
                  String.LocalizationValue(
                    page.customButtonTitleKey ?? "open_analytics_settings"),
                  table: "Onboarding")
              )
              .opacity(page.customButtonTitleKey != nil ? 1 : 0)
              Text(L10n.string("open_analytics_settings", table: "Onboarding"))
                .opacity(page.customButtonTitleKey == nil ? 1 : 0)
            }
          }
          .font(.headline)
          .foregroundColor(.white)
          .padding(.horizontal, 24)
          .padding(.vertical, 12)
          .background(Color.blue)
          .cornerRadius(12)
        }
        .background(
          PIPSourceView { view in
            settingsButtonView = view
          }
        )
        .padding(.top, 8)
        .opacity(page.showSettingsButton ? 1 : 0)
        .allowsHitTesting(page.showSettingsButton)
      }
      .frame(minHeight: 100)

      Spacer()
      Spacer()
    }
    .padding()
  }
}

#Preview {
  TutorialView()
}
