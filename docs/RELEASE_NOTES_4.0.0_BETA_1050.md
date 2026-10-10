# MochiLog 4.0.0 beta — build 1050

## 日本語

端末内取得を有効にすると、MochiLogを表示していない間も自動取得を試みるようになりました。

- iPhone・iPadがロック解除され、診断サービスにつながるVPNが接続中なら、OSが許可したタイミングで取得します。時刻・間隔・毎日の実行は保証されません。アプリの強制終了後は、再び開くまで自動取得が止まります。
- 取得済みの完成ファイルは保護された領域に保存し、次にアプリを開いた時に既存の解析・重複チェックを通して記録します。取得途中でOSの時間制限に達しても、完成したファイルは次回へ引き継ぎます。
- 前面での収集とバックグラウンドの収集は同時に走りません。当日分が揃った後の不要な取得も抑制します。Apple Watchのない端末や、複数のWatchがある場合も考慮しています。
- 端末内取得とPC連携で日次ログの停止・翌日の再開・Watch必要件数の判定を共通化しました。解析失敗やPCの確認応答待ちでは早まって停止しません。現在のバッテリー情報の更新は日次ログの停止とは独立しています。
- ロック解除時の資格情報再読み込み、取得中にロックされた場合の中断、設定オフ時の予約取り消しに対応しました。鍵やファイルの保護方式は維持しています。
- 診断ログを日付と機能別のファイルに分割し、先頭に形式バージョン2とアプリ・ビルド情報を記録します。OSの背景起動には実行ID・開始終了・所要時間・中断理由が残ります。旧ログと旧PCとの診断ログ交換も維持します。
- 起動、延期理由、予約時刻、中断、完成ファイルの保存をデバッグログに記録します。設定の案内は8言語に対応しています。

前のベータで追加した取得進捗・一時停止／再開・画面の重なり修正も含みます。端末内取得はiOS/iPadOS 17以降、端末内での初回ペアリングは27以降です。PC連携は引き続き併用できます。バックグラウンド実行はOSの判断、VPNの状態、診断サービスの利用可否に依存します。

## English

Automatic on-device collection can now attempt to run while MochiLog is not displayed.

- With on-device collection enabled, the device unlocked, and a VPN route to its diagnostic service available, collection runs when iOS grants background execution. Neither a fixed schedule nor daily execution is guaranteed. Force-quitting stops automatic collection until you open the app again.
- Complete files are stored in a protected staging area. They are analyzed and recorded through the existing duplicate checks the next time you open MochiLog. If the OS budget expires, complete files remain available for the next attempt; interrupted files are retried.
- Foreground and scheduled collection cannot run simultaneously. Unnecessary collection stops once the day's required files are available, accounting for devices without an Apple Watch and for multiple Watches.
- On-device collection and PC reception now share the daily completion, next-day restart, and required Watch-count policy. Failed imports and pending computer acknowledgments do not prematurely stop reception. Live battery updates remain independent of daily-log completion.
- Credentials are reloaded after unlocking if a cold background launch could not access them. Collection pauses when protected data becomes unavailable. Turning collection off cancels pending requests. Existing key and file protection remain in place.
- Diagnostic files are separated by date and feature, with format version 2 and app/build metadata in their headers. OS background wakes carry a run ID, start/end times, duration, and expiration reason. Legacy logs and diagnostic exchange with older computers remain supported.
- Debug logs include OS wakes, deferral reasons, requested earliest times, expiration, and completed-file staging. The settings explanation supports all eight app languages.

This beta also includes the previous progress display, pause/resume, and layout fixes. On-device collection supports iOS/iPadOS 17 and later; initial pairing entirely on the device requires 27 or later. Existing PC collection remains available alongside it. Background execution depends on OS scheduling, the VPN route, and diagnostic-service availability.
