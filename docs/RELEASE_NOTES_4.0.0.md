# MochiLog 4.0.0

## 日本語

4.0.0

自動ログ収集
・MochiLog Mac／Windowsとの連携に対応しました。初回の信頼設定とQRペアリング後、PCが収集したiPhone・iPad・Apple Watchの解析ログを暗号化して受信し、スマホで解析・記録します。
・「設定 → 自動ログ収集」からPC連携と端末内取得を個別に設定できます。従来の手動読み込みもそのまま利用できます。
・端末内取得はiOS／iPadOS 17以降の任意の実験機能です。対応VPNとOSペアリングが必要です。27以降はDeveloper Modeを有効にして端末内で初回ペアリングできます。バックグラウンド取得はOSが許可するタイミングで試行します。

現在のバッテリー
・任意のタブで充放電回数、容量などの現在値と最終取得時刻を表示できます。初期状態はオフです。取得した値は履歴やiCloudへ保存しません。
・複数PCの同じ値をまとめ、違いを比較できます。同じApple AccountでiCloud同期が有効な端末間のみ、対応するPC経由でログや現在値を共有できます。

記録と使いやすさ
・記録へ個体IDを導入し、エクスポート／インポート、複数端末同期、重複確認を改善しました。
・ホームのバッテリー記録を複数選択して削除できます。確認中に別端末で変更された記録を保護します。
・日付別・機能別の動作ログとエラーログ、発生日時を選べるサポート添付を追加しました。
・iPad／iPhone Duoのレイアウト、共有画面の安定性、多言語表示を改善しました。
・診断ログの再送は保存済みデータを確認し、不足分だけを保存するよう改善しました。既存のペアリングは引き続き利用できます。

PC連携はiOS／iPadOS 27以降、macOS 27以降またはWindows 11に対応します。日次ログの収集には端末のロック解除と解析データの生成が必要です。VPN経由の通信は利用者のネットワーク設定と通信許可に従います。

## English

4.0.0

Automatic log collection
• Pair with MochiLog Mac or Windows. After initial trust setup and QR pairing, receive encrypted iPhone, iPad and Apple Watch analytics files collected by your computer. Analysis and record creation happen on the mobile device.
• Configure PC Transfer and On-device Collection independently in Settings → Automatic Log Collection. Manual import remains available.
• Optional experimental on-device collection supports iOS/iPadOS 17 and later with a compatible VPN and OS pairing. Initial pairing entirely on the device requires 27 or later and Developer Mode. Background collection is attempted only when the OS allows it.

Live Battery
• An optional tab displays current cycle count, capacities and other available readings, with the last acquisition time. It is off by default. Readings are not saved to history or iCloud.
• Matching readings from multiple computers are grouped, with differences available for comparison. Eligible logs and current readings can be shared through a paired computer only between devices with iCloud sync enabled on the same Apple Account.

Records and usability
• Individual device identities now work with export/import, synchronization and duplicate review.
• Select and delete multiple battery records from Home. Records changed on another device while you confirm are protected.
• Browse activity and error logs by date and feature. Support attachments can be selected around an incident date.
• Improved iPad and iPhone Duo layouts, sharing stability and multilingual text.
• Diagnostic retries verify existing bytes and save only the missing portion. Existing pairings continue to work.

PC Transfer requires iOS/iPadOS 27 or later and macOS 27 or later, or Windows 11. Collecting daily analytics requires an unlocked device and generated analytics data. VPN communication follows your network configuration and communication permissions.
