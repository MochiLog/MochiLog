# 自動ログ収集（4.0.0 beta）

MochiLog単体でも手動で解析ログを追加できます。自動ログ収集は追加の選択肢です。設定の「自動ログ収集」にPC連携と端末内取得をまとめています。PC連携は従来の設定を引き継ぎ、端末内取得は初期状態ではオフです。

## PC連携

MacまたはWindows 11アプリが解析ログを収集し、スマホを開いた際に転送します。PCアプリ、既存のペアリング、ローカルWi-Fiを利用します。Tailscaleとモバイル通信の許可がある場合は、保存済みログと現在のバッテリー情報を外出先でも受信できます。診断ログを新たに収集できるかは、端末のロック状態と診断サービスへの到達性によります。

## 端末内取得（実験機能）

対応するローカルVPN／リフレクターの経路を使って、そのiPhone・iPad自身の診断サービスに接続します。LocalDevVPNは別アプリです。MochiLogがVPNを自動的に置き換えることはありません。

1. 「自動ログ収集 → 端末内取得」を開く。
2. 対応する最新版PCとペアリング済みなら、そのPCの初期設定情報を明示的に引き継ぐ。再度のMochiLog QR登録は不要。
3. PCでOSペアリングしたことがない場合は、最初にOSの信頼設定を済ませる。外部ツールで作成したRPPairing形式のファイルも読み込めます。MochiLogのQRだけではAppleのOSペアリング情報は作成できません。
4. LocalDevVPNなどの対応経路を有効にし、端末内取得をオンにする。iOS/iPadOS 27以降でアプリを開いている間に動作します。初回設定・Developer Modeオフ・バックグラウンドでの取得を保証する機能ではありません。

Apple Watchの解析ログは、ペアになっているiPhone内の保存先から取得します。取得したログは既存のiPhone側パーサーで解析します。両方式を同時に使う場合も、ファイルのハッシュ・個体ID・既存記録を確認し、共通の取り込み待ちへ渡します。解析前に終了した場合は保存済みファイルから再開し、成功後は一時ファイルを削除します。

## 現在のバッテリー情報

高度な設定でタブをオンにすると、現在値・最終取得時刻を確認できます。この値は履歴記録として保存しません。複数PCから同じ端末の情報を受け取った場合は、同じ項目をまとめ、異なる値だけ比較できます。

同じPCとペアリング済みの複数端末が、どちらもiCloud同期を有効にして同じApple Accountと確認できた場合は、他の端末の現在値も表示します。同期オフ・別アカウント・確認未完了の場合は共有しません。端末内取得の現在値とPCから受け取った同じ個体の値も、この一覧で確認できます。

## PCの更新確認

Mac・Windowsとも自動アップデート確認は初期状態でオフです。最初の選択画面で有効にするか選び、後から設定で変更できます。手動の更新確認も利用できます。

# Automatic Log Collection (4.0.0 beta)

Manual log import works without a computer. Settings → Automatic Log Collection contains independent PC and on-device options. Existing PC preferences are retained; on-device collection is off by default.

PC companions collect raw logs and transfer them when MochiLog is open. Saved logs and current battery values can also be received over Tailscale when mobile data is allowed. Fresh diagnostic collection still depends on device lock state and service reachability.

On-device collection is experimental and needs a compatible local VPN/reflector route, such as the separate LocalDevVPN app. Explicitly reuse your own device's existing OS pairing through an updated, authenticated PC companion, or import an RPPairing file. A MochiLog QR invitation alone does not create Apple's OS trust. Initial OS pairing must be completed first. iOS/iPadOS 27 or later and foreground use are required; first-time setup without Developer Mode and background collection are not guaranteed. MochiLog does not replace or configure another VPN silently.

Watch logs are read from the paired iPhone. Both acquisition paths feed the same mobile parser and import queue, using physical-device identity, hashes and saved records to prevent duplicate imports. Staged files survive interruptions and are removed after a successful import.

Live Battery is an optional tab. Values and acquisition timestamps are displayed without becoming history records. Common values from multiple computers are combined and differences remain inspectable. Other physical devices appear only when both devices opt into iCloud sync and the same Apple Account is confirmed. Sync-off, different-account and unconfirmed cases are excluded.

PC automatic update checks are off by default, offered once, and can be changed in settings. Manual checks remain available.
