# MochiLog 4.0.0

## 日本語

4.0.0

・Mac／Windowsとの連携による、iPhone・iPadのバッテリー解析ログの自動収集と暗号化転送を追加しました。解析・記録はスマホで行い、PCなしの手動読み込みも引き続き使えます。
・iPhoneに保存されたApple Watchログも収集します。Watchなし、未登録のWatch、複数Watch・複数iPhoneを考慮し、手動追加と共通の登録・取り込み処理を使います。
・複数のMac／Windowsを同時にペアリングできます。QRと確認コード、既存のOS信頼設定の確認、端末ごとの解除と相手への解除通知に対応しました。
・受信前にファイルのハッシュと既存記録を照会し、複数PCやiCloud同期との重複を防ぎます。受信・PCの確認応答が完了してから解析を始めます。
・同じApple Accountで双方のiCloud同期が有効と確認できた端末だけ、PC経由で他の端末のログと現在値を共有できます。元端末の個体IDを保持し、未確認・同期オフでは共有しません。
・接続状態、アプリを開いている端末、転送の進捗と結果を分かりやすくしました。スマホの「今すぐ受信」、PCの手動収集・送信にも対応します。
・自動再接続、IP変更への追従、手動IP指定、対応VPN経由の転送、モバイル通信の許可切り替えに対応しました。Tailscale等の対応経路が必要な通信を案内します。
・低速回線や中断後の再試行を改善し、1台のPCとの大量の診断履歴交換が、ほかのPCを待たせ続ける問題を修正しました。
・当日の本体と必要なWatchログが揃うと不要な自動通信を抑え、翌日の取得へ再開します。手動操作は引き続き使え、現在値の更新は日次ログの停止と独立しています。
・新しい順にログを取得し、session・Census・電池情報のない短いファイルを除外します。取得失敗や再試行待ちを完了扱いにせず、状況を表示します。
・「設定 → 自動ログ収集」を新設し、PC連携と端末内取得を独立してオン・オフできるようにしました。
・対応するローカルVPN／リフレクター経路で、自分の端末からログと現在のバッテリー情報を取得する任意の実験機能を追加しました。初期状態はオフです。
・既存PCから自分のOSペアリングを暗号化して引き継ぐ方法と、ペアリングファイルの読み込みに対応しました。対応版idevice_pairからの直接インストールも利用できます。
・iOS／iPadOS 27以降では端末内の初回ペアリングも行えます。Developer Modeの設定・再起動・OS承認を案内し、認証できないファイルで既存の資格情報を置き換えません。
・取得段階、件数、読み取り量、経過時間を表示し、一時停止・再開に対応しました。状態表示を1つにまとめ、画面やタブへの重なりを改善しました。
・OSが許可するバックグラウンド継続・定期取得に対応しました。完成ファイルを安全に引き継ぎ、アプリを開いた時に解析します。実行時刻・間隔は保証されません。
・中断・再起動後に保存済みログを回復し、同じファイルの再取得や、取得できたのに記録へ進まない問題を改善しました。不完全なファイルは取り込みません。
・高度な設定で有効にできる「現在のバッテリー」タブを追加しました。初期状態はオフで、現在値は履歴・記録・iCloudへ保存しません。
・充放電回数、容量、電圧・電流、充電・電源状態など、意味を確認できた項目を表で表示します。不明な項目は任意の詳細表示に分け、単位や値を推測しません。
・取得できる全項目の詳細、最終取得日時、未取得・取得失敗・古い値を確認できます。値の変化だけを転送し、今すぐ更新する操作も利用できます。
・複数PCの共通値をまとめ、異なる項目だけを比較します。機種番号は機種名に変換して表示します。
・記録に個体IDを導入し、新規取り込み、既存記録との対応、エクスポート／インポート、iCloud同期で端末を区別できるようにしました。
・共有ログでiPhone・iPadやWatchを取り違える問題を修正しました。確認できた過去の記録は、日付・記録ID・実測値を保持して訂正します。
・完全一致の重複記録を起動時に確認し、候補を見てバックアップ後に整理できます。複数端末からの削除で残す記録まで消さないよう保護します。
・ホームの記録を複数選択・全選択して削除できます。確認中に他端末で変更された記録を保護し、保存失敗時は変更を戻します。
・動作ログを「設定 → デバッグ」に集約しました。端末と受信したPCのログを日付・機能別に確認、コピー、共有できます。保存日数とストレージ整理も設定できます。
・エラーログに日付別一覧、メッセージ検索、ページ切り替え、先頭・末尾への移動を追加しました。iPadは一覧と詳細を並べ、大きなログの読み込み負荷を軽減しました。
・サポートで発生日時を選び、当日と前2日分のスマホ・PC双方の診断情報を添付できます。解決・返信を保証できないことも案内します。
・バックグラウンド起動、取得・転送の開始終了、所要時間、中断・停止・再開理由を診断ログへ記録します。形式・アプリ・ビルドのバージョンも識別できます。
・診断ログを日付・機能別に分割し、旧形式との交換を維持しました。再送の内容を照合し、不足分だけを保存して保存済みデータを保護します。
・PCにログの保管庫、保存期間・容量設定、削除・書き出し・手動再送を追加しました。保存時の初期値は500MB・1か月で、未転送分は保護します。
・PCにログイン時起動、メニューバー／タスクトレイ常駐、閉じた後の動作設定、自動更新確認、画面非表示時のメモリ解放設定を追加しました。
・公開鍵方式のQR、鍵のKeychain等での保護、要求と診断情報の暗号化、改ざん・再送・旧方式への切り戻し対策を強化しました。段階的な更新でも既存ペアリングを引き継ぎます。
・iPadの設定を右側ペインに揃え、戻る操作、デバイス管理、QRカメラの向きを改善しました。iPhone Duoのレイアウトにも対応しました。
・Macで動かすiPhone／iPad版の起動、iCloud同期、表示言語と寄付画面を改善し、PC連携の操作を非表示にしました。
・共有画面のクラッシュ、翻訳された機種名による分析グラフの不具合、Watchの処理結果が繰り返し出る問題を修正しました。
・8言語の新画面と案内、タブの切り替え、概要・図解・困ったときのヘルプ、PC導入リンク、依存ライセンスとプライバシー説明を更新しました。
・内部コードの整形、メモリと処理時間の制限、テスト・ビルド手順を整備しました。
・PC連携はiOS／iPadOS 27以降とmacOS 27以降またはWindows 11、端末内取得は17以降が対象です。日次ログ収集にはロック解除と解析データの生成が必要です。VPNとバックグラウンド動作はOS・通信環境に依存します。

## English

4.0.0

• Encrypted Mac/Windows log transfer. Parsing stays on mobile; PC-free manual import remains.
• Watch logs from iPhone use the shared import flow, including unregistered/multiple Watches.
• Pair multiple PCs by QR/code, verify OS trust and unpair with remote revocation.
• Check hashes and existing records before transfer; analyze after receipt and PC acknowledgement. Avoid multi-PC/iCloud duplicates.
• Share logs/readings only with confirmed iCloud sync on both devices and the same Apple Account; retain source identity.
• Connection/app-presence status, progress/results, Receive Now and manual PC actions.
• Auto reconnect, IP-change recovery, manual IPs, VPN transfers and cellular controls with Tailscale guidance.
• Improve slow-link recovery and prevent one PC's history exchange from blocking others.
• Stop daily polling when device/required Watch logs are complete, then resume next day. Manual actions and live readings stay independent.
• Prioritize newer logs; exclude session/Census and short non-battery files. Failed/retry-waiting files remain incomplete.
• Independent PC/on-device switches in Settings → Automatic Log Collection.
• Experimental on-device logs/live readings through a compatible local VPN/reflector route; off by default.
• Reuse your own pairing encrypted from PC, import files or install from compatible idevice_pair builds.
• Device-only pairing on 27+, with Developer Mode/restart/OS approval guidance. Invalid imports preserve credentials.
• Collection stages, counts, bytes, elapsed time, pause/resume and one expandable status display.
• OS-permitted background continuation/scheduled collection; import completed files on next activation. Timing is not guaranteed.
• Recover saved files after interruption/restart, avoid repeat downloads and reject incomplete files.
• Optional Live Battery tab, off by default. Values are not saved in history, iCloud or diagnostics.
• Verified cycle, capacity, voltage/current and charging/power fields in a table; optional uncertain details without guessed units.
• Raw fields, acquisition times, missing/failed/stale states, changed-value transfer and refresh.
• Combine matching PC readings, compare differences and show friendly model names.
• Device identities support records, imports, export/import and iCloud sync.
• Fix source-device mix-ups; repair verified old records without changing dates, IDs or measurements.
• Review exact duplicates at launch with lists/backup; protect retained records across synced deletions.
• Multi-select/select-all deletion protects concurrent edits and rolls back failed saves.
• Debug settings groups mobile/PC logs by date/feature, with copy/share, retention and cleanup.
• Search dated errors, page large logs, jump to first/last; iPad list/detail layout and lighter loading.
• Dated support attaches both sides' logs for that day and two prior days; no guaranteed reply/fix.
• Versioned daily/feature logs trace background wakes, timings, stops and retries. Verify repeated chunks; save only missing bytes.
• PC log vault: export/delete/resend, 500 MB/one-month defaults and protected unsent files.
• PC startup, tray/menu bar, close behavior, opt-in updates and hidden-UI memory release.
• Public-key QR, protected keys, encrypted requests/diagnostics and tamper/replay/downgrade protection; retain existing pairings during staged upgrades.
• Improve iPad settings/navigation, device management and QR orientation; add Duo layouts.
• Fix Mac-hosted mobile launch, iCloud and language/tip displays; hide PC controls there.
• Fix sharing crashes, localized charts and recurring Watch results.
• Eight-language screens, tab animations, illustrated help, downloads, licenses/privacy and code/resource maintenance.
• PC: iOS/iPadOS 27+, macOS 27+ or Windows 11. On-device: 17+; device-only pairing: 27+ with Developer Mode. Daily logs need an unlocked device and generated analytics. VPN/background behavior depends on OS/connectivity.
