# 正式配布版のクラッシュ調査（2026-11-18）

## 確認した配布版

App Store Connectの「クラッシュ数」をアプリバージョン別に確認した。
集計期間は2026-10-01〜2026-11-16。

| バージョン | クラッシュ数 |
| --- | ---: |
| 3.2.2 | 105 |
| 4.0.0 | 11 |
| 4.0.1 | 8 |
| 4.1.0 | 「－」表示 |

「－」はクラッシュがない証拠ではない。Xcode Organizerから、正式配布の
**4.1.0 (1070)** にも2026-11-18 00:22 JSTのクラッシュを取得できた。
Distributorは`com.apple.AppStore`。iPhone SE 第2世代、iOS 27.3 betaで発生。
4.0.0/4.0.1のiPhone・iPadにも同じスタックがあり、最新OSのbetaだけの問題ではない。

Organizerを4.0.0・App Store and Marketplaces・Last Yearに絞ると、
表示される署名は下記の1種類、影響端末は5台。
Analyticsの11件と個別ログとの1対1対応は提供されていないため、
端末数とクラッシュ回数は同一視しない。

## 原因と再現

主要スタックは次のとおり。

```text
libswiftCore._assertionFailure
SwiftUI.AppSceneDelegate.sceneItem(flush:)
SwiftUI.AppSceneDelegate.stateRestorationActivity(for:)
UIKitCore._UISceneUserActivityManager._saveSceneRestorationState
...
MochiLog.UIApplicationDelegate.main()
```

旧SwiftUI版で作成された画面セッションをOSが保持している。
そのインストールにUIKit起動方式のアプリを上書きすると、現在の画面設定を返す
`configurationForConnecting`が呼ばれず、古い`SwiftUI.AppSceneDelegate`を復元する
場合がある。起動自体は成功しても、バックグラウンドへの移行に伴う画面状態の保存で
SwiftUIのAppGraphが存在せず停止する。

独立した試験用アプリで、旧SwiftUI版を起動・背景化・終了し、
名前付きUIKit画面設定を含む版へ上書きして再現した。
新規インストールではこの更新条件を再現できない。

過去のTestFlightで確認したMac上のMarketplaceKitクラッシュとは別件。
その古いフィードバックの件数を、今回の正式配布版11件の根拠には使用していない。

## 修正

- `MochiLogApplication`をSwiftUIの起動入口にし、旧画面セッションに必要なAppGraphを維持。
- `UIApplicationDelegateAdaptor`経由で、既存のアプリ・画面デリゲートを継続使用。
- `SceneWindowHost`は、OSが既存UIKitセッションを直接復元した場合だけウィンドウを作成。
  SwiftUIが管理する画面では追加ウィンドウや追加のデータストアを作成しない。
- SwiftUIの`onOpenURL`と既存UIKitのURLコンテキストを共通の取り込みキューへ渡す。
  共有拡張の複数ファイル受信も維持。
- 起動時に保存済み画面の設定名・デリゲート名、接続時に画面の所有方式を診断ログへ記録。
  セッションの個別IDは記録しない。

記録データ・設定・個体ID・ペアリングの削除や書き換えは行わない。
DBの属性追加、CloudKitスキーマ更新、データマイグレーションは不要。

Appleが公開するデリゲートの連携方式を使用する。
[UIApplicationDelegateAdaptorのScene delegates](https://developer.apple.com/documentation/swiftui/uiapplicationdelegateadaptor)
にあるとおり、SwiftUIからカスタム画面デリゲートにイベントを転送する。
非公開API、SwiftUIクラスの差し替え、セッション保存ファイルの削除は使用しない。

## 検証

`Tests/README.md`の起動・更新回帰チェック、および
`scripts/test-scene-lifecycle.py`に再現と予防の自動テストを追加。
個人のクラッシュ原本やAPIレスポンスはGit管理外の調査フォルダで扱い、コミットしない。

| 検証 | 結果 |
| --- | --- |
| iOS/iPadOS 27.2：SwiftUI版→修正版、UIKit版→修正版、新規、クラッシュ状態からの上書き復旧 | iPhone/iPadとも4経路成功 |
| iOS/iPadOS 27.0：同じ4経路 | iPhone/iPadとも成功 |
| 各経路の記録ファイルSHA-256・保存済み設定の保持、起動/背景化/終了/再起動、起動中/終了中のURL受信 | 成功 |
| クラッシュ再現の対照試験 | 27.0/27.2のiPhone/iPadで同じ復元スタックを再現 |
| アプリ本体のホーム表示・背景化/復帰3回・終了後の再起動 | 標準iPhone/iPad 27.2、Duo 27.2で成功 |
| Xcode 27.2 RC：Debugシミュレーター / Release実機向け（署名なし）ビルド | 成功 |
| 共通取り込みキュー / 共有拡張の8ファイル受信・再開・失敗時保持 | 成功 |

iPadOSの補助ウィンドウを重複画面と誤判定しないよう、テストではアプリ本体の
コンテンツウィンドウが1つであることを確認する。
Duo特殊ランタイムではHomeボタンの模擬操作で前面状態が変わらなかったため、
本体テストは設定アプリを前面に出して背景化を検証した。

`Scene lifecycle upgrade verification`ワークフローから同じ更新試験を手動実行できる。
この調査ではローカルで実行した。CIは自動配信を行わず、失敗時の小さなログのみ2日保持する。
試験用アプリやクラッシュ原本を成果物としてアップロードしない。
専用シミュレーターは終了時に削除し、既存シミュレーターや実機の記録は消去しない。

本調査時点の修正は開発ソースであり、公開済み4.1.0 (1070)のバイナリには含まれない。
次の署名済み配布ビルドを実機で確認するまでは、配信環境で解消したとは扱わない。
