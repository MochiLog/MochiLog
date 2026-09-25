# MochiLog

**今日のバッテリー。その先の変化も。**

MochiLogは、iPhone・iPadの解析ログからバッテリーの容量や充電サイクルを記録し、履歴をグラフで振り返るアプリです。ペアリングしたApple Watchでも、iPhoneから転送された記録を閲覧できます。

[App Store](https://apps.apple.com/app/mochilog/id6756904240) · [紹介サイト](https://mochilog.ryuya-dev.net/) · [使い方](https://mochilog.ryuya-dev.net/guide?lang=ja) · [Webリポジトリ](https://github.com/MochiLog/MochiLog-Web)

## このブランチについて

このREADMEは `refactor/ios27-batch-import-adaptive-ui-20260908` の実装を説明しています。cloudfixの変更を統合し、iOS 27への対応確認、複数ログ取り込み、画面表示、言語設定、Watch連携を改善しています。**mainへのマージやApp Storeへの公開はまだ行っていません。** 公開版と利用できる機能が異なる場合があります。

## 主な機能

| 機能 | 内容 |
| --- | --- |
| ログの取り込み | 共有メニューからアプリ本体を開いて読み込み。保存済みファイルやZIPからの取り込みにも対応 |
| 複数ログの処理 | キューで取り込みを管理し、重複・保存成功・エラーを個別に表示 |
| 記録と分析 | デバイス別の履歴管理、容量・サイクルのグラフ、表示期間の切替 |
| iCloud同期 | 任意で有効にし、同じApple Accountの端末間で記録を同期 |
| Apple Watch | ペアリングしたiPhoneから記録と言語設定を受け取り、デバイスの状態を閲覧 |
| 画面への適応 | iPhone・iPadの幅、横向き、大きな文字サイズに応じて表示を調整 |
| 言語設定 | 初期値は端末の言語。アプリ内で表示言語を選択可能 |

共有拡張（Share Extension）は使用していません。共有後にMochiLog本体を開く動作を維持し、起動時と起動中のファイル受け取りを処理します。

対応言語は日本語、英語、簡体字中国語、繁体字中国語、韓国語、スペイン語、フランス語、ドイツ語の8言語です。

## 最初の記録を作る

1. iPhone・iPadの「設定」→「プライバシーとセキュリティ」→「解析と改善」→「解析データ」を開きます。
2. `Analytics-` で始まるログを探し、共有メニューからMochiLogを選びます。表示されない場合は「ファイル」に保存してアプリから取り込みます。
3. 解析結果を確認して記録します。日付の異なるログを追加すると、変化をグラフで振り返れます。

ログの生成状況や取得できる項目は、端末・OS・ログ形式によって異なります。アプリ内のチュートリアルも参照してください。

MochiLogは読み込まれたログを使います。アプリを入れるだけで常時測定したり、Watch自身のバッテリーを自動収集したりする機能ではありません。数値は参考情報であり、Appleの公式診断や修理・保証の判断を代替しません。

## 対応環境

| 対象 | 設定・確認状況 |
| --- | --- |
| iPhone / iPad | Deployment TargetはiOS・iPadOS 16.0以降。iCloud同期は17以降 |
| Apple Watch | Deployment TargetはwatchOS 9.0以降 |
| 開発 | macOSとXcode。本ブランチはXcode 27 beta / iOS 27 SDKで検証 |
| 検証スクリプト | Xcode Command Line Tools、Python 3 |

Deployment Targetは、この作業で全OS・全実機を試験したという意味ではありません。iOS 27 / watchOS 27の確認にはbeta版シミュレータを使用しています。

## ビルド

```sh
git clone --branch refactor/ios27-batch-import-adaptive-ui-20260908 https://github.com/MochiLog/MochiLog.git
cd MochiLog
open MochiLog.xcodeproj
```

Xcodeで `MochiLog` スキームと実行先を選びます。Swift Package Managerの依存関係はプロジェクトから解決されます。実機では、自分の開発チーム・署名・iCloud等のCapabilitiesを設定してください。

コマンドラインでシミュレータ向けにビルドする場合:

```sh
xcodebuild -project MochiLog.xcodeproj \
  -scheme MochiLog \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Releaseを確認する場合は `-configuration Release` に変更します。使用するXcodeは `xcode-select` または `DEVELOPER_DIR` で指定してください。埋め込まれたWatchターゲットのSDK選択を妨げないよう、上の例では `-sdk` を指定していません。

## テスト

リポジトリのルートで実行します。

```sh
bash scripts/test-shared-import.sh
bash scripts/test-languages.sh
bash scripts/test-watch-records.sh
bash scripts/test-cloud-errors.sh
```

取り込みキュー・日付解析、言語選択と翻訳カタログ、Watchデータ互換性、CloudKitエラー判定を検証します。翻訳監査は空欄・不足言語・書式引数などの機械的な確認であり、翻訳品質の保証ではありません。

UIテストは `MochiLogUITests`、WatchのUIテストは `MochiLogWatchUITests` スキームです。Watchのテストには、ペアリングしたiPhoneから合成ログを取り込む準備が必要です。実行条件と制約は [Tests/INTEGRATION.md](Tests/INTEGRATION.md)、取り込みテストの詳細は [Tests/README.md](Tests/README.md) を参照してください。

### 2026-09-08の確認結果と残る確認事項

- Debug / Releaseビルド、上記4スクリプトが成功。
- iPhone 17 Pro（iOS 27）、iPhone SE（iOS 17）、iPad mini（iOS 27）で言語設定・大きな文字サイズ・横向き表示を確認。
- Watch SE 40mm / Ultra 49mm（watchOS 27）で同期された記録とドイツ語の詳細表示を確認。
- Watchシミュレータの初回タップは不安定な場合があり、UIテストでは画像を記録して一度だけ再試行します。初回応答の安定性は未解決です。
- 実機の「ファイル」からの複数共有、および実際のiCloudアカウントを使う2端末間同期は追加検証が必要です。

## データの扱い

ログの解析は端末内で行います。iCloud同期を有効にした場合は、記録を利用者のiCloudプライベートデータベースへ保存します。Watch利用時はペアリングしたWatchへ転送し、共有やお問い合わせでは利用者が選んだ情報を送信します。

開発者がアプリを通じてバッテリー記録を収集する仕組みはありません。詳しくは [プライバシーポリシー](MochiLog/Resources/PrivacyPolicy.md) を参照してください。

## コード構成

| パス | 役割 |
| --- | --- |
| `MochiLog/App/` | アプリ・シーンの起動とファイル受け取り |
| `MochiLog/Services/` | ログ解析、取り込みキュー、保存、iCloud・Watch連携 |
| `MochiLog/Views/` | ホーム・分析・設定画面 |
| `MochiLog Watch App/` | Watch側の画面と受信処理 |
| `Shared/` | 共通の言語設定と翻訳リソース |
| `Tests/`, `UITests/`, `WatchUITests/` | 検証コードと合成データ |
| `scripts/` | 検証・翻訳監査のコマンド |

## 関連プロジェクト・問い合わせ

- [MochiLog-Web](https://github.com/MochiLog/MochiLog-Web): Cloudflare Workersで動く紹介サイト
- [サポート](https://mochilog.ryuya-dev.net/support?lang=ja)
- [GitHub Issues](https://github.com/MochiLog/MochiLog/issues): 不具合報告には機種・OS・アプリのバージョンと再現手順を添えてください。ログ全体の公開は避け、必要な範囲を確認して共有してください。

## License

[LICENSE](LICENSE) を参照してください。

## English overview

MochiLog turns imported iPhone and iPad analytics logs into battery records and history charts. Optional iCloud sync shares records between your devices, and the paired Apple Watch app displays records delivered by iPhone. Analysis runs on-device; MochiLog is not a continuous battery monitor or an official Apple diagnostic tool.

This development branch adds improved multi-file imports, adaptive layouts, and eight-language settings that default to the device language. It has not been merged into main or released on the App Store. See [integration checks](Tests/INTEGRATION.md) for test setup and remaining limitations, including intermittent initial taps on the watchOS 27 simulator and unverified physical-device sharing/iCloud scenarios.
