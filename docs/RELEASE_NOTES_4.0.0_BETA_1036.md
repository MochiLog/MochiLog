# MochiLog 4.0.0 Beta (1036)

This is a TestFlight beta, not an App Store public release. / TestFlightベータ版です。App Storeの一般公開版の変更ではありません。

- [TestFlight](https://testflight.apple.com/join/vnHYsRgN)
- [MochiLog Mac Beta 0.2.17](https://github.com/MochiLog/MochiLog-Mac/releases/tag/v0.2.17)
- [MochiLog Windows Alpha 0.1.14](https://github.com/MochiLog/MochiLog-Windows/releases/tag/v0.1.14)

## 日本語

日次ログとは別に、ペアリング済みiPhone・iPadの現在のバッテリー情報を確認できるベータ機能を追加しました。PCの概要画面に端末別で表示し、スマホの高度な設定でオンにすると専用タブでも表示できます（初期状態はオフ）。既存のペアリングを引き継ぎます。

通常の「項目／値」の表は意味・単位を確認した正確なパスだけを表示します。充放電回数、確認できたルートの設計容量、充電状態、外部電源、電圧・電流などが対象です。設計容量がない場合は未取得と表示します。公称・生の最大・満充電容量、単位が未確定の現在残量、BatteryData内の容量、不明なコードやチャンネル情報は、初期状態で閉じた「詳細情報を表示」から任意に確認できます。元の値を保持し、単位を推測せず、大きな整数も丸めません。チャンネル名を温度の測定値として扱いません。

アプリを開いている間に定期取得し、変化した値だけを暗号化して転送します。最終取得日時、欠けている項目、取得失敗時の古い値を区別し、今すぐ受信／送信・PCへの更新要求にも対応します。現在値はメモリだけで扱い、履歴・記録・iCloud・診断ログには保存しません。

取得にはpymobiledevice3の診断APIを使用します。機種・OS・接続状態によって取得できない項目があります。ロック中の取得成功を確認していますが、常に成功することや日次ログのロック中取得を保証するものではありません。Apple Watchの現在値は対象外です。MochiLog Mac 0.2.14／MochiLog Windows 0.1.11以降と組み合わせてください。

4.0.0ベータにはPC連携による日次ログの自動収集・暗号化転送も含まれます。iOS/iPadOS 27、macOS 27、Windows 11が対象です。Windowsの初回USB信頼設定にはApple DevicesまたはApple公式サイトのクラシック版iTunesが必要です。PC用アプリには必要な実行環境を同梱しています。初回はロック解除した端末をUSBで信頼設定し、PC側のQRをスマホの「設定 → 高度な設定 → PC連携」で読み取ります。無線のOSペアリング済みならUSBを省略できます。PC連携なしでもスマホ単体で手動読み込みできます。

ログ収集には端末のロック解除が必要です。iPhoneに保存されたWatchログも対象で、解析・記録はスマホで行います。複数のPCを連携でき、事前照会で受信済みログを確認し、両側の確認後に転送を完了します。日次ログがそろうと自動通信を抑えます。Tailscaleとモバイル通信の許可設定で収集済みログを外出先から受け取れます。PC保管庫は送信後削除または保存を選べ、保存時は既定500MB・1か月です。

接続・転送の診断ログは日付別に確認・コピーでき、専用サポートには発生日と前2日分の両側のログを添付できます。完全一致の重複記録は、候補を確認しバックアップ後に整理できます。iPadの設定は右側ペインで表示し、Mac上のスマホ版ではPC連携を表示しません。

共有画面のクラッシュ、翻訳された機種名の分析グラフ、Watchの処理結果の再表示、Mac上のスマホ版の起動を修正済みです。要求全体をAES-GCMで暗号化し、有効期限・永続的な再送防止・旧方式への切り戻し防止を備えます。既存ペアリングと旧版からの段階的更新に対応します。ベータのため、不安定な場合は日付付きのログと操作内容を添えてご報告ください。

Pythonは保守されているpymobiledevice3による端末接続・API呼び出し・型を保持するデータ出力に絞りました。検証・表示分類・ハッシュ生成・取得日時とログ候補選別はSwift／C#で行います。読みやすいソースと役割分担メモをリポジトリで公開しています。実行環境は同梱され、ユーザーの環境構築は不要です。既存ペアリング・暗号化と旧版の主要6項目の転送形式を維持します。

## English

Added a beta view of current battery information for paired iPhones and iPads, separate from daily Analytics logs. Enable Live Battery in the mobile app’s Advanced Settings to show a dedicated tab; it is off by default.

The field/value table uses verified exact paths for cycle count, root design capacity, charging, external power, voltage and current. Design capacity is unavailable when the root field is absent. Ambiguous nominal, raw maximum, full-charge and charge-level values, nested BatteryData capacities, unknown codes and channel metadata remain under Show detailed information, collapsed by default. Original names and values keep their precision without guessed units. A channel name is not an actual temperature measurement.

While the app is open, values refresh periodically and only changed values are transferred using encryption. Acquisition time, unavailable fields and outdated values after a failed refresh are shown separately. Receive Now, Send Now and mobile requests to refresh the computer are available. Values remain in memory only and are never saved to history, records, iCloud or diagnostic logs.

Acquisition uses the maintained pymobiledevice3 diagnostics API. Field availability depends on device, OS and connectivity. A locked query has succeeded in testing, but this does not guarantee all locked queries or locked-state daily Analytics collection. Live Apple Watch values are not included. Use with MochiLog Mac 0.2.14 or MochiLog Windows 0.1.11 or later.

The 4.0.0 beta also includes automatic daily-log collection and encrypted computer transfer for iOS/iPadOS 27, macOS 27 and Windows 11. Windows initial USB trust requires Apple Devices or the classic iTunes EXE from Apple’s website. Runtime dependencies are bundled in the desktop apps. Unlock and trust the device over USB once, then scan the computer QR in Settings → Advanced Settings → PC Transfer. Existing wireless OS pairing can skip USB. Manual mobile import still works without computer transfer.

Daily Analytics collection requires an unlocked device. Watch files stored on iPhone are eligible; parsing and recording happen on mobile. Multiple computers are supported, with authenticated duplicate inventory before transfer and confirmation on both sides before completion. Automatic communication pauses once the required daily logs are complete. Tailscale and the cellular permission setting allow receipt of collected logs away from home. Desktop storage can delete delivered files immediately or retain them, with adjustable defaults of 500 MB and one month.

View and copy diagnostics by date. Dedicated support can attach both sides’ logs for the incident date and the two preceding days. Exact duplicate records can be reviewed and cleaned up after a backup. iPad settings remain in the right pane; computer transfer is hidden when the mobile app runs on Mac.

Previous fixes include the record-sharing crash, charts with localized device names, recurring Watch processing results and mobile-app launch on Mac. AES-GCM request encryption, expiry, persistent replay protection and downgrade prevention preserve existing pairings and support staged upgrades. This is beta software: report problems with dated diagnostics and the steps that triggered them.

Python is limited to the maintained pymobiledevice3 connection/API adapter and lossless data output. Validation, display classification, hashes, timestamps and log-candidate selection run in native Swift/C#. Readable sources and architecture notes are in the repositories. Runtime dependencies remain bundled; users do not configure Python. Existing encrypted pairings and older clients’ six core-field wire format are preserved.
