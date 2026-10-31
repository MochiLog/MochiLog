# MochiLog

**今日のバッテリー。その先の変化も。**

iPhone・iPadの解析ログからバッテリー容量と充放電回数を記録し、履歴をグラフで振り返るアプリです。スマホ単体でログを取り込めます。任意のiCloud同期や、Apple Watchでの記録の閲覧にも対応します。

[App Store](https://apps.apple.com/app/mochilog/id6756904240) · [TestFlightベータ](https://testflight.apple.com/join/vnHYsRgN) · [公式サイト](https://mochilog.ryuya-dev.net/) · [使い方](https://mochilog.ryuya-dev.net/guide?lang=ja)

## できること

- 解析ログや保存したファイルからバッテリー記録を追加し、複数のログもまとめて取り込み。
- 機種ごとの容量・充放電回数の変化をグラフで確認。
- iCloud同期を有効にして、同じApple Accountの端末間で記録を共有。
- ペアリングしたApple Watchで記録を閲覧。
- 任意のMac・Windows連携で、ログを収集してスマホへ転送。
- 「現在のバッテリー」タブで、取得できた現在値と最終取得日時を確認。

日本語、英語、簡体字中国語、繁体字中国語、韓国語、スペイン語、フランス語、ドイツ語に対応します。

## 最初の記録

1. 端末の「設定 → プライバシーとセキュリティ → 解析と改善 → 解析データ」を開き、`Analytics-`で始まるログを探します。
2. 共有メニューからMochiLogを選びます。ファイルに保存してアプリから読み込むこともできます。
3. 解析結果を確認して保存します。日付の異なる記録が増えると、バッテリーの変化を振り返れます。

ログがない場合は、同じ設定画面で解析の共有を確認してください。オンにした直後は、新しいログが生成されるまで時間がかかります。ログの項目は機種とOSによって異なります。値は参考情報で、Appleの公式診断や修理判断を代替しません。

## 自動ログ収集と現在値

**設定 → 自動ログ収集**で、PC連携と実験的な端末内取得をそれぞれ設定できます。

[MochiLog Mac](https://github.com/MochiLog/MochiLog-Mac/releases/latest)・[MochiLog Windows](https://github.com/MochiLog/MochiLog-Windows/releases/latest)がログを収集し、端末でMochiLogを開くと受信・解析・記録します。Apple Watchのログは、ペアリング先のiPhoneに保存されたものを収集します。初回設定や収集時のロック解除などの条件は[自動ログ収集ガイド](docs/automatic-log-collection.md)をご確認ください。

PCを使わない端末内取得は、対応VPNと初回の信頼設定が必要な実験機能です。利用条件と操作は同じガイドで案内しています。自動取得の時刻や間隔はOSの制限を受けます。

**設定 → 高度な設定 → 現在のバッテリー**をオンにすると、現在値のタブが表示されます。初期状態はオフです。複数PCで同じ値がある場合はまとめ、異なる値だけ比較できます。現在値は履歴として保存されません。[現在値の使い方](docs/LIVE_BATTERY.md)もご覧ください。

## 4.1.0ベータの機種データ更新

新しい機種の情報を、アプリのアップデートなしで取得できます。自動確認は初期状態でオンです。**設定 → 高度な設定 → デバイス情報を管理 → 機種データの更新**で切り替えたり、今すぐ確認したりできます。

オフラインでは保存済みの機種データを使用します。手動で編集した値と過去の記録は保護されます。新しいログ形式や新機能への対応には、引き続きアプリのアップデートが必要です。[TestFlight](https://testflight.apple.com/join/vnHYsRgN)で先行版を試せます。

## 対応環境

| 機能 | 対応環境 |
| --- | --- |
| 手動のログ取り込み・記録 | iOS / iPadOS 16以降 |
| iCloud同期 | iOS / iPadOS 17以降 |
| Mac・Windows連携 | iOS / iPadOS 27以降、macOS 27以降またはWindows 11 |
| 端末内取得 | iOS / iPadOS 17以降、対応VPN・初回の信頼設定が必要 |
| 端末内だけで行う初回ペアリング | iOS / iPadOS 27以降、Developer Modeが必要 |

公開版とベータ版では利用できる機能が異なる場合があります。詳細は各機能のガイドをご確認ください。

## サポート

[使い方・困ったときは](https://mochilog.ryuya-dev.net/guide?lang=ja) · [お問い合わせ](https://mochilog.ryuya-dev.net/support?lang=ja) · [プライバシーポリシー](https://mochilog.ryuya-dev.net/privacy?lang=ja) · [利用規約](https://mochilog.ryuya-dev.net/terms?lang=ja)

## English

MochiLog turns imported iPhone and iPad analytics files into battery records and trend charts. Import files directly on your device, optionally sync records through iCloud, and view them on a paired Apple Watch.

Start with the [App Store app](https://apps.apple.com/app/mochilog/id6756904240) and [user guide](https://mochilog.ryuya-dev.net/guide?lang=en). Manual import supports iOS/iPadOS 16+, iCloud sync requires 17+, and computer transfer requires 27+ with macOS 27+ or Windows 11. Optional on-device collection requires iOS/iPadOS 17+ and a compatible VPN; first-time pairing entirely on the device requires 27+ and Developer Mode.

Enable the optional **Live Battery** tab in Advanced Settings to view current readings and acquisition times. These values are not saved as history. The 4.1.0 [TestFlight beta](https://testflight.apple.com/join/vnHYsRgN) also updates device reference data independently of app updates, with manual checks, offline use and preservation of manual settings and saved records.

Available in Japanese, English, Simplified Chinese, Traditional Chinese, Korean, Spanish, French and German. Visit [support](https://mochilog.ryuya-dev.net/support?lang=en) for help.

---

[開発者向け文書 / Developer documentation](docs/DEVELOPMENT.md) · [ライセンス / License](LICENSE)
