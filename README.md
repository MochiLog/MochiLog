# MochiLog

**今日のバッテリー。その先の変化も。**

iPhone・iPadの解析ログから容量と充放電回数を記録し、履歴をグラフで振り返るアプリです。iCloud同期は任意で利用でき、ペアリングしたApple Watchでも記録を閲覧できます。PCを使わず、スマホだけでログを手動読み込みできます。

[App Store](https://apps.apple.com/app/mochilog/id6756904240) · [TestFlightベータ](https://testflight.apple.com/join/vnHYsRgN) · [紹介サイト](https://mochilog.ryuya-dev.net/) · [使い方](https://mochilog.ryuya-dev.net/guide?lang=ja)

## 最初の記録

1. 設定 → プライバシーとセキュリティ → 解析と改善 → 解析データで、Analytics-から始まるログを探します。
2. 共有メニューからMochiLogを選びます。ファイルに保存して、アプリから読み込むこともできます。
3. 解析結果を確認して保存します。日付の異なる記録が増えると、容量やサイクルの変化をグラフで追えます。

ログの生成や取得できる項目は機種とOSで異なります。値は参考情報で、Appleの公式診断や修理判断を代替しません。

## 4.0.0ベータのPC連携

[MochiLog Mac](https://github.com/MochiLog/MochiLog-Mac/releases)と[MochiLog Windows](https://github.com/MochiLog/MochiLog-Windows/releases)が日次のバッテリー解析ログを収集し、スマホでアプリを開いたときに暗号化して転送します。解析と記録はスマホ側で行います。スマホはiOS/iPadOS 27、MacはmacOS 27、WindowsはWindows 11が対象です。PC連携を設定しなくても通常の手動読み込みは使えます。

現在の充放電回数・設計容量・最大容量などを確認する専用タブも追加しました。**設定 → 高度な設定 → 現在のバッテリー**をオンにすると表示します（初期状態はオフ）。既存のPCペアリングを使用し、アプリを開いている間に更新します。機種名を表示し、複数PCの共通値はまとめ、違う値だけ比較できます。PCごとの最終取得日時、取得できない項目、古い値を区別して表示し、現在値は履歴・記録・iCloudに保存しません。

[現在値の使い方と注意点](docs/LIVE_BATTERY.md) · [Macの利用ガイド](https://github.com/MochiLog/MochiLog-Mac/blob/main/docs/USER_GUIDE.md) · [Windowsの利用ガイド](https://github.com/MochiLog/MochiLog-Windows/blob/main/docs/USER_GUIDE.md)

## 言語と対応環境

日本語、英語、簡体字中国語、繁体字中国語、韓国語、スペイン語、フランス語、ドイツ語に対応します。本体はiOS/iPadOS 16以降、iCloud同期は17以降、PC連携は27以降です。次のベータ更新では、端末内取得とその現在値表示は17以降、端末内の初回ペアリングは27以降に対応します（初回承認と旧OSの実機検証は進行中）。PC版を更新しても既存のペアリングを引き継ぎます。ベータ版とApp Store公開版では利用できる機能が異なります。

[プライバシーポリシー](https://mochilog.ryuya-dev.net/privacy?lang=ja) · [利用規約](https://mochilog.ryuya-dev.net/terms?lang=ja) · [サポート](https://mochilog.ryuya-dev.net/support?lang=ja)

---

MochiLog turns imported iPhone and iPad Analytics files into battery records and trend charts. Manual import works without a computer. Optional iCloud sync and viewing records on a paired Apple Watch are also available.

The 4.0.0 beta supports encrypted daily-log transfer from a Mac (macOS 27) or Windows 11 to mobile (iOS/iPadOS 27). An optional **Live Battery** tab shows current cycle count and capacity through your existing computer pairing. Enable it in Advanced Settings; it is off by default. It refreshes while open, displays friendly model names, combines identical readings from multiple computers and compares only differences. Each source retains its acquisition time, missing fields and outdated state. Current values are not saved to history, records or iCloud.

In the upcoming beta update, on-device collection and current readings target iOS/iPadOS 17+, while device-only initial pairing requires 27+. Earlier versions import a pairing file; 17.0–17.3 use Lockdown format and 17.4+ can use RPPairing. First-time OS approval and older-OS real-device validation remain pending. Computer collection still requires 27+.

See the [live-value guide](docs/LIVE_BATTERY.md) and desktop user guides linked above. Build and test notes from the earlier development branch are preserved in [developer documentation](docs/README_20260908_DEVELOPMENT.md).

同じPCとペアリングしたiPhone・iPadは、同じApple Accountで双方のiCloud同期が有効と確認できる場合に限り、他の端末のログも受信できます。元の端末の個体IDを保持して記録し、片方がオフ・別アカウント・未確認なら共有しません。共有元のアプリをしばらく開いていない場合は再確認まで保留します。

Devices paired with the same PC can also receive each other’s logs when both have confirmed iCloud sync enabled on the same Apple Account. Records keep the original device identity. Disabled sync, different accounts and unconfirmed permissions prevent sharing. If the source app has not been opened for a while, sharing waits for renewed confirmation.
