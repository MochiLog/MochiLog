// SettingsRedirectHelper.swift
// 設定アプリへのリダイレクト処理を提供するヘルパー

import UIKit

/// 設定アプリへのリダイレクト処理を提供する
enum SettingsRedirectHelper {
  /// ショートカット名（固定）
  private static let shortcutName = "解析データを開く(MochiLog) ver.1"

  /// iCloudショートカットリンク
  private static let shortcutURL =
    "https://www.icloud.com/shortcuts/2dec4ec5fff742bbbb87c6688a922c13"

  /// silentインポート完了後に設定アプリ（解析・改善データ画面）にリダイレクトする
  /// 「アプリを開く」がオフの場合、ユーザーはアプリを見たくないので即座に元の画面に戻す
  static func redirectToPrivacyAnalytics() {
    // iOS 18以降ではprefs: URLスキームが制限されているため、複数のURLパターンを試す
    let urlStrings = [
      "App-prefs:Privacy&path=PROBLEM_REPORTING",
      "App-prefs:Privacy",
      "App-prefs:",
    ]

    openFirstValidURL(urlStrings)
  }

  /// ショートカット経由で解析データ画面を開く（x-callback-url方式）
  static func openAnalyticsViaShortcut() {
    guard
      let encoded = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    else {
      return
    }

    // x-callback-urlでショートカットを実行
    // 成功時はアプリに戻らず、エラー時のみアプリに戻る
    let urlString =
      "shortcuts://x-callback-url/run-shortcut?"
      + "name=\(encoded)&"
      + "x-error=mochilog://shortcut-error"

    if let url = URL(string: urlString) {
      UIApplication.shared.open(url) { opened in
        guard !opened else { return }
        DispatchQueue.main.async {
          AppSettings.shared.isShortcutInstalled = false
          NotificationCenter.default.post(name: NSNotification.Name("ShortcutNotFound"), object: nil)
        }
      }
    }
  }

  /// ショートカットのセットアップ画面を開く（iCloudリンク経由）
  static func openShortcutSetup() {
    // x-successでアプリに戻る
    let callbackURL = "\(shortcutURL)?x-success=mochilog://setup-complete"

    if let url = URL(string: callbackURL) {
      UIApplication.shared.open(url)
    }
  }

  /// URLリストから最初に成功するものを開く
  private static func openFirstValidURL(_ urlStrings: [String], index: Int = 0) {
    guard index < urlStrings.count else { return }

    if let url = URL(string: urlStrings[index]) {
      UIApplication.shared.open(url) { success in
        if !success {
          openFirstValidURL(urlStrings, index: index + 1)
        }
      }
    } else {
      openFirstValidURL(urlStrings, index: index + 1)
    }
  }
}
