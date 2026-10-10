# MochiLog 4.0.0 beta — build 1047

## 日本語

端末内取得を有効にすると、MochiLogを表示していない間も自動取得を試みるようになりました。

- iPhone・iPadがロック解除され、診断サービスにつながるVPNが接続中なら、OSが許可したタイミングで取得します。時刻・間隔・毎日の実行は保証されません。アプリの強制終了後は、再び開くまで自動取得が止まります。
- 取得済みの完成ファイルは保護された領域に保存し、次にアプリを開いた時に既存の解析・重複チェックを通して記録します。取得途中でOSの時間制限に達しても、完成したファイルは次回へ引き継ぎます。
- 前面での収集とバックグラウンドの収集は同時に走りません。当日分が揃った後の不要な取得も抑制します。Apple Watchのない端末や、複数のWatchがある場合も考慮しています。
- ロック解除時の資格情報再読み込み、取得中にロックされた場合の中断、設定オフ時の予約取り消しに対応しました。鍵やファイルの保護方式は維持しています。
- 起動、延期理由、予約時刻、中断、完成ファイルの保存をデバッグログに記録します。設定の案内は8言語に対応しています。

前のベータで追加した取得進捗・一時停止／再開・画面の重なり修正も含みます。端末内取得はiOS/iPadOS 17以降、端末内での初回ペアリングは27以降です。PC連携は引き続き併用できます。バックグラウンド実行はOSの判断、VPNの状態、診断サービスの利用可否に依存します。

## English

Automatic on-device collection can now attempt to run while MochiLog is not displayed.

- With on-device collection enabled, the device unlocked, and a VPN route to its diagnostic service available, collection runs when iOS grants background execution. Neither a fixed schedule nor daily execution is guaranteed. Force-quitting stops automatic collection until you open the app again.
- Complete files are stored in a protected staging area. They are analyzed and recorded through the existing duplicate checks the next time you open MochiLog. If the OS budget expires, complete files remain available for the next attempt; interrupted files are retried.
- Foreground and scheduled collection cannot run simultaneously. Unnecessary collection stops once the day's required files are available, accounting for devices without an Apple Watch and for multiple Watches.
- Credentials are reloaded after unlocking if a cold background launch could not access them. Collection pauses when protected data becomes unavailable. Turning collection off cancels pending requests. Existing key and file protection remain in place.
- Debug logs include OS wakes, deferral reasons, requested earliest times, expiration, and completed-file staging. The settings explanation supports all eight app languages.

This beta also includes the previous progress display, pause/resume, and layout fixes. On-device collection supports iOS/iPadOS 17 and later; initial pairing entirely on the device requires 27 or later. Existing PC collection remains available alongside it. Background execution depends on OS scheduling, the VPN route, and diagnostic-service availability.
