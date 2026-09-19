# iPhone Duo / Xcode 27.1 検証

作業ブランチ: `feature/iphone-duo-xcode27.1`（main `940d324` から作成）。

## Xcodeの使い分け

- システムの既定はXcode 27.0（27A266a）のまま。インストール先の名前は `Xcode-27.0.0-release.candidate.app`。
- Duo検証のみXcode 27.1 beta（27A9269）を `DEVELOPER_DIR` で指定する。
- `xcode-select --switch` やシェル全体の環境設定変更は行わない。
- CIの `latest-stable` と配布用ワークフローは変更していない。

```bash
./scripts/test-duo.sh
```

スクリプトは `feature/iphone-duo-*` ブランチ以外では停止する。iOS 27.1のDuoを検出し、専用DerivedDataと日時別の `build/duo/` に結果を保存する。複数のDuoがある場合は `DUO_SIMULATOR_ID` を指定する。Xcodeの置き場所が変わった場合は `DUO_DEVELOPER_DIR` を指定する。

特定のテストだけ再実行する場合:

```bash
./scripts/test-duo.sh -only-testing:MochiLogUITests/LanguageAndLayoutTests/testNativeDuoDetailRotationAndSharing
```

## 専用シミュレーターでの確認

2026-09-19、iPhone Duo / iOS 27.1（24A94401）で実行。前回の `MOCHI_LAYOUT_TEST` は使わず、OSが提供する実際のサイズクラスとsafe areaを使用する。

- ホーム・分析・設定の基本UIテストは成功。縦システムバーの領域とコンテンツの分離をスクリーンショットでも確認。
- 詳細画面の共有ボタンに多言語の読み上げラベルとテスト用識別子を追加。
- 詳細画面への向き変更要求後の選択ログ維持、共有UIの存在、ダークモード、大きな文字のテストを追加。5件のUIテストが成功した。
- スクリーンショットの目視で、大きな文字の場合にレンジ選択とグラフの軸・凡例が潰れる問題を発見。レンジ操作を縦配置にし、グラフの高さを確保、凡例を折り返し可能な別領域へ移した。軸の数字は最大xxxLargeとし、凡例と統計はユーザー指定サイズを保持する。
- スクリーンショット取得はアプリを対象にする。文字が大きい場合のテストは対象スクロール領域を操作して、画面外の項目が操作可能になることを確認する。
- 修正後も既定Xcode 27.0でのReleaseビルドが成功。
- グラフ修正後の通常文字・最大文字の2テストも成功。添付画像でレンジ表示、軸、折り返し凡例の重なり解消を確認した。

結果: `build/duo/20260919-212336/Test.xcresult`（5テスト）、`build/duo/20260919-212659/Test.xcresult`（グラフ修正後2テスト）。これらはローカル生成物でGit管理対象外。

## 未確認事項と環境の制約

Device HubのUI取得が権限許可・接続初期化後も `timeoutReached (-10005)` で失敗するため、開閉・中間角度・Split Viewの操作は未検証。XCUIDeviceへの向き変更要求だけでは、Duoの実際のpose遷移を確認したことにはならない。新しいreserved regionやhinge APIを、必要性を確認せずに追加してはいない。

テスト失敗後のシミュレーター診断収集が終了しなかったため、スクリプトでは `-collect-test-diagnostics never` を指定する。テストの判定・xcresult・通常ログ・添付スクリーンショットは保存する。

Appleは27.1 betaの既知の問題として、シミュレーター初回起動に数分かかること、StandByおよび大半のApp Extensionの実行・デバッグが利用できないことを記載している。共有拡張による複数ログ受信の検証は通常端末でも継続する。

参照: [Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)、[Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/)。
