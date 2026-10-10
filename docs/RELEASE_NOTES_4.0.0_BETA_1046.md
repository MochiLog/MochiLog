# MochiLog 4.0.0 Beta (1046)

## 日本語

MochiLog 4.0.0 beta (1046)

iPhone・iPadの端末内取得に進捗表示を追加しました。ホームを含む各画面で、接続・一覧確認・ファイル取得・取り込み準備の段階、件数、読み取り量、経過時間を確認できます。普段は1行の状態表示にまとめ、タップした時だけ詳細を同じ領域に展開します。追加ポップアップと重複カードを減らし、一時停止と再開にも対応します。8言語対応です。

手動収集ではiOS/iPadOS 26以降のバックグラウンド継続APIを使用し、対応するシステムの進捗表示とキャンセルに対応します。自動収集や旧OSでは短時間のバックグラウンド処理を使います。OSが開始を許可しない場合も短時間の処理へ切り替えます。アプリの強制終了、VPNや診断サービスの切断、OSの時間制限がある場合には取得が中断されます。

完成した電池ログを1件ずつ安全に一時保存してから次のファイルを取得します。中断後は取得済みファイルを引き継ぎ、途中のファイルを取り直します。OSが返すファイルサイズと読み取り量の照合を追加し、不完全な内容は取り込みません。Census・sessionや電池項目のない短いファイルを除外します。既存の個体ID・ハッシュ・重複防止・ペアリングを維持します。

端末内取得は実験機能で、初期状態はオフです。対応するローカルVPN経路と自分の端末のOS信頼設定が必要です。端末内取得は17以降、端末のみでの初回ペアリングとPC連携は27以降が対象です。端末内ペアリングにはDeveloper Modeをオンにする必要があります。17系実機のOSサービスは未検証です。PCの既存ペアリング情報の再利用とファイル取り込みも残ります。

PC経由と端末内取得は独立してオン・オフできます。Apple WatchのログはペアのiPhoneから取得します。ログ解析と記録はスマホ側の共有取り込み処理を使用し、現在のバッテリー値は履歴へ保存しません。Mac 0.2.22 Beta／Windows 0.1.20 Alphaが最新の対応版です。手動追加などスマホ単体での利用は引き続き可能です。

不具合はサポート画面から発生日時と診断ログを添えて報告してください。ベータ機能のため解決や返信を保証できません。

## English

MochiLog 4.0.0 beta (1046)

On-device acquisition now shows progress on both iPhone and iPad. A banner across the app, including Home, displays connection, listing, file download and import preparation, file counts, bytes and elapsed time. The status normally uses one compact row; tapping expands details in the same reserved area, without another popup or duplicate card. Pause and resume are available. All eight app languages are supported.

Manual collection uses BGContinuedProcessingTask on iOS/iPadOS 26 or later, with system progress and cancellation. Automatic collection and older systems use a short background execution allowance. If continued processing cannot start, collection falls back to that short allowance. Force-quitting the app, loss of the VPN or diagnostic service, or OS time limits can interrupt collection.

Each complete, validated battery log is atomically checkpointed before reading the next file. Resume keeps completed files and retries unfinished ones. When the OS supplies a file size, the app checks it against the complete read; truncated files are not imported. Census/session files and short files without battery fields are excluded. Existing physical-device identity, hashes, duplicate prevention and pairings are preserved.

On-device acquisition remains experimental and off by default. It needs a compatible local VPN route and OS trust for this device. Acquisition requires 17+, while PC transfer and initial on-device pairing require 27+. Developer Mode must be enabled for on-device pairing. Real OS services on iOS 17 hardware remain untested. Reusing existing computer pairing information and importing a pairing file remain supported.

PC transfer and on-device acquisition have independent switches. Apple Watch logs are read from the paired iPhone. Both routes use the shared mobile import and parser pipeline; current battery values are not saved to history. Mac 0.2.22 Beta and Windows 0.1.20 Alpha are the latest companions. Manual import and other standalone mobile features remain available.

Please report beta issues with the occurrence date and diagnostic logs using the support screen. A resolution or reply cannot be guaranteed.

## 検証記録

詳細は[進捗・背景処理の開発メモ](local-collection-progress.md)。この更新ではPCアプリの変更はありません。
