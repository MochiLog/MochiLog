# MochiLog 4.0.0

## 日本語

4.0.0

・Mac／Windowsと連携して、iPhone・iPadのバッテリーログを自動で取り込めるようになりました。これまでの手動読み込みも、PCなしで引き続き使えます。
・iPhoneに保存されたApple Watchのログも取り込めます。複数のWatchを使っている場合や、まだMochiLogに登録していないWatchにも対応しました。
・複数のMac／Windowsを登録できるようになりました。QRコードと確認コードで接続し、不要になったPCや端末は個別に解除できます。
・同じApple Accountで双方のiCloud同期がオンの場合、ほかの端末のログと現在のバッテリー情報もPC経由で受け取れます。
・PCとの接続状態、転送の進み具合、取り込み結果を確認しやすくしました。「今すぐ受信」も利用できます。
・接続が途切れた後の再接続や、低速回線での転送を改善しました。複数のPCを利用しているときも、それぞれから受信しやすくなりました。
・手動でのIPアドレス指定と、モバイル通信のオン・オフ設定を追加しました。外出先からの通信にはTailscaleなどの対応VPNが必要です。
・必要なログを受け取った後の不要な通信を減らし、バッテリー消費を抑えるようにしました。
・「設定 → 自動ログ収集」を追加しました。PC連携と端末内取得は、それぞれ個別にオン・オフできます。
・PCを使わず、自分の端末からログや現在のバッテリー情報を取得する実験機能を追加しました。対応VPNの設定が必要で、初期状態はオフです。
・端末内取得の設定では、登録済みのPCのペアリング設定や、ペアリングファイルを利用できます。対応版idevice_pairからのインストールにも対応しました。
・iOS／iPadOS 27以降では、端末だけで初回ペアリングできます。必要なDeveloper Modeの設定や、承認手順も案内します。
・ログ取得中の進捗、件数、経過時間を表示し、一時停止・再開できるようにしました。進捗表示が画面に重なる問題も改善しました。
・バックグラウンドでの取得継続・定期取得に対応しました。実行のタイミングはOSや利用状況によって変わります。
・取得を中断した場合やアプリを再起動した場合の再開を改善しました。受信できたログが記録に反映されない問題も修正しました。
・「現在のバッテリー」タブを追加しました。高度な設定で表示を切り替えられ、初期状態はオフです。現在値は履歴として保存されません。
・充放電回数、容量、電圧・電流、充電状態などを表で確認できます。より詳しい項目は、必要なときに詳細表示から確認できます。
・最終取得日時と更新状況を表示し、今すぐ更新する操作も追加しました。複数の端末の情報も確認できます。
・複数のPCから届く同じバッテリー情報はまとめ、異なる値だけを比較できるようにしました。機種番号の代わりに機種名を表示します。
・同じ機種を複数台使っている場合も、端末ごとに記録を区別しやすくしました。書き出し・読み込みやiCloud同期でも引き継げます。
・iPhone・iPad・Apple Watchの記録が別の端末として表示される問題を修正しました。
・完全に同じ重複記録を起動時に確認し、候補を見てから整理できるようにしました。
・ホームのバッテリー記録を複数選択・全選択して削除できるようになりました。
・PCとの通信の安全性を強化しました。これまでのペアリング設定も引き続き利用できます。
・iPadの設定画面、戻る操作、デバイス情報の管理、QR読み取り時のカメラの向きを改善しました。iPhone Duoの大きな画面にも対応しました。
・共有画面でのクラッシュ、分析グラフの表示不具合、Apple Watchの処理結果が繰り返し表示される問題を修正しました。
・複数ログの共有メニューの案内を分かりやすくし、共有項目の表示を改善しました。
・Apple Watch Series 3 Cellularの容量表示を修正しました。これまでの記録の容量表示も補正されます。
・8言語の画面と案内を更新しました。図解付きの機能紹介、設定手順、困ったときのヘルプ、PC版へのダウンロード案内も追加しました。
・PC連携はiOS／iPadOS 27以降とmacOS 27以降またはWindows 11、端末内取得はiOS／iPadOS 17以降が対象です。日次ログの取得には、解析データの生成と端末のロック解除が必要です。

## English

4.0.0

• Automatically import iPhone and iPad battery logs with the new Mac and Windows apps. Manual import remains available without a PC.
• Import Apple Watch logs saved on your iPhone, including multiple Watches and Watches not yet registered in MochiLog.
• Pair multiple Macs and Windows PCs using QR codes and confirmation codes. Remove individual pairings when no longer needed.
• Receive other devices' logs and current battery information through a PC when both devices enable iCloud sync with the same Apple Account.
• See connection status, transfer progress and import results. Use Receive Now to import on demand.
• Improved reconnection, slow-network transfers and receiving from multiple PCs.
• Added manual IP addresses and cellular controls. Remote access requires a compatible VPN such as Tailscale.
• Reduced unnecessary communication after daily logs arrive to help save battery.
• Added Settings → Automatic Log Collection, with separate PC and on-device collection switches.
• Added experimental on-device collection of logs and current battery information without a PC. A compatible VPN is required; this feature is off by default.
• Set up on-device collection with an existing PC pairing or a pairing file. Installation from compatible idevice_pair versions is also supported.
• Pair directly on iOS/iPadOS 27 or later, with Developer Mode and approval guidance.
• See collection progress, file counts and elapsed time, with pause and resume. Improved overlapping progress displays.
• Continue or schedule collection in the background when allowed by iOS. Timing depends on the OS and device use.
• Improved recovery after interruption or restart, and fixed received logs failing to appear as records.
• Added the optional Live Battery tab in Advanced Settings, off by default. Current readings are not saved as history.
• View cycles, capacity, voltage, current and charging status in tables, with optional details for more fields.
• Check the last update time and status, refresh now, and view multiple devices.
• Combine matching readings from multiple PCs, compare differences and display friendly model names.
• Distinguish records from devices of the same model, including after export, import and iCloud sync.
• Fixed records being attributed to the wrong iPhone, iPad or Apple Watch.
• Review exact duplicates at launch and choose which to remove.
• Select multiple battery records, or all records, for deletion from Home.
• Improved PC connection security while retaining existing pairings.
• Improved iPad settings, navigation, device management and QR camera orientation; added larger iPhone Duo display support.
• Fixed sharing crashes, chart display issues and recurring Apple Watch import results.
• Clarified how to import multiple logs from the share menu and improved when the import action appears.
• Corrected capacity references for Apple Watch Series 3 Cellular, including capacity displays in existing records.
• Updated eight languages, illustrated introductions, setup guides, troubleshooting and PC download links.
• PC collection requires iOS/iPadOS 27+ and macOS 27+ or Windows 11. On-device collection requires iOS/iPadOS 17+. Daily logs require generated analytics and an unlocked device.
