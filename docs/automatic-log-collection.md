# 自動ログ収集（4.0.0 beta）

MochiLog単体でも手動で解析ログを追加できます。自動ログ収集は追加の選択肢です。設定の「自動ログ収集」にPC連携と端末内取得をまとめています。PC連携は従来の設定を引き継ぎ、端末内取得は初期状態ではオフです。

## PC連携

MacまたはWindows 11アプリが解析ログを収集し、スマホを開いた際に転送します。PCアプリ、既存のペアリング、ローカルWi-Fiを利用します。Tailscaleとモバイル通信の許可がある場合は、保存済みログと現在のバッテリー情報を外出先でも受信できます。診断ログを新たに収集できるかは、端末のロック状態と診断サービスへの到達性によります。

## 端末内取得（実験機能）

対応するローカルVPN／リフレクターの経路を使って、そのiPhone・iPad自身の診断サービスに接続します。対応VPNは別アプリです。MochiLogがVPNを自動的に置き換えることはありません。

1. iOS／iPadOS 17以上で「自動ログ収集 → 端末内取得」を開く。
2. iOS/iPadOS 27以降では「端末内ペアリングを開始」を選べます。ローカルネットワークを許可し、設定 → プライバシーとセキュリティ → デベロッパモードで、アプリに表示されたMochiLogの名前を選んでください。端末のパスコードによるOS承認と、タスクのバナー／通知に出る6桁コードの入力が必要です。外部ペアリングファイルの用意・PCへの接続はこの方式では不要です。この端末内の初回ペアリングにはDeveloper Modeが必須です。開始前の案内に従ってオンにし、再起動後の承認を完了してください。「オンにしました・開始」で確認してから待受を始めます。キャンセルでは待受を始めず、既存の認証情報を保持します。設定状態を自動検知した表示ではありません。
3. 既存のPCのOSペアリングを引き継ぐ方法も残っています。「既存ペアリングを利用」を選ぶと、更新済みの認証済みPCからこの端末自身の認証情報を暗号化して取得します。17〜26では、PCで用意したペアリングファイルを取り込みます。17.0〜17.3はLockdown形式、17.4以上はRPPairing形式も選べます。MochiLogのQRだけではAppleのOS信頼は作成されません。
4. 対応VPNなどの経路を有効にし、端末内取得をオンにします。MochiLogを開いている間に取得します。バックグラウンドでの取得やDeveloper Modeオフでの動作は保証していません。

ペアリング中だけ設定アプリへ移動するための継続処理を申請します。OSに許可されない場合は短い制限時間を画面に表示し、期限切れ・中止で待受を停止します。成功したときだけ端末専用Keychainの認証情報を置き換えます。PCのペアリングや保存済み記録は変更しません。

端末内取得の設定には、現在のバッテリータブの表示切り替え・「今すぐ受信」・現在値画面への導線があります。現在値はログ収集と別の認証接続で約15秒ごとに更新し、最終取得日時を表示します。PCを介さず、履歴記録には保存しません。

Apple Watchの解析ログは、ペアになっているiPhone内の保存先から取得します。取得したログは既存のiPhone側パーサーで解析します。両方式を同時に使う場合も、ファイルのハッシュ・個体ID・既存記録を確認し、共通の取り込み待ちへ渡します。解析前に終了した場合は保存済みファイルから再開し、成功後は一時ファイルを削除します。

## 現在のバッテリー情報

高度な設定でタブをオンにすると、現在値・最終取得時刻を確認できます。この値は履歴記録として保存しません。複数PCから同じ端末の情報を受け取った場合は、同じ項目をまとめ、異なる値だけ比較できます。

同じPCとペアリング済みの複数端末が、どちらもiCloud同期を有効にして同じApple Accountと確認できた場合は、他の端末の現在値も表示します。同期オフ・別アカウント・確認未完了の場合は共有しません。端末内取得の現在値とPCから受け取った同じ個体の値も、この一覧で確認できます。

## PCの更新確認

Mac・Windowsとも自動アップデート確認は初期状態でオフです。最初の選択画面で有効にするか選び、後から設定で変更できます。手動の更新確認も利用できます。

# Automatic Log Collection (4.0.0 beta)

Manual log import works without a computer. Settings → Automatic Log Collection contains independent PC and on-device options. Existing PC preferences are retained; on-device collection is off by default.

PC companions collect raw logs and transfer them when MochiLog is open. Saved logs and current battery values can also be received over Tailscale when mobile data is allowed. Fresh diagnostic collection still depends on device lock state and service reachability.

On-device collection is experimental and needs a compatible local VPN/reflector route, through a separate compatible VPN app. On iOS/iPadOS 27, choose Start on-device pairing. Allow Local Network, select the displayed MochiLog host in Settings → Privacy & Security → Developer Mode, authorize with the device passcode, and enter the six-digit code from the task banner or notification. This route requires neither an external pairing file nor a PC. Developer Mode is required for this on-device initial pairing. Follow the prerequisite card, enable it, restart and approve after restart. Confirm “Enabled — Start” before listening begins. Cancel leaves existing credentials intact and starts no listener. The app does not automatically detect the setting. On 17–26, import a pairing file prepared on a computer: Lockdown for 17.0–17.3, with RPPairing also available from 17.4. Encrypted reuse from an authenticated PC remains available on 27+. A MochiLog QR invitation alone does not create Apple's OS trust. Initial OS pairing must be completed first. iOS/iPadOS 17 or later and foreground use are required; first-time setup without Developer Mode and background collection are not guaranteed. MochiLog does not replace or configure another VPN silently.

Watch logs are read from the paired iPhone. Both acquisition paths feed the same mobile parser and import queue, using physical-device identity, hashes and saved records to prevent duplicate imports. Staged files survive interruptions and are removed after a successful import.

Live Battery is an optional tab. Values and acquisition timestamps are displayed without becoming history records. Common values from multiple computers are combined and differences remain inspectable. Other physical devices appear only when both devices opt into iCloud sync and the same Apple Account is confirmed. Sync-off, different-account and unconfirmed cases are excluded.

PC automatic update checks are off by default, offered once, and can be changed in settings. Manual checks remain available.

The on-device settings also expose Live Battery opt-in, Receive Now and the current-value screen. Current values refresh on an independent authenticated connection while MochiLog is open, without becoming history records.

## 対応環境と検証状況（TestFlight 1042）

| 機能 | iOS／iPadOS |
| --- | --- |
| 端末内のログ取得・現在のバッテリー | 17以上。17〜26は外部ペアリングファイルを取り込み |
| 端末内だけで行う初回OSペアリング | 27以上・Developer Mode必須 |
| MochiLog PCアプリ経由の取得・転送 | 27以上 |

17.0〜17.3の従来経路は、VPNから端末自身のlockdownサービスへ到達できる必要があります。到達できない場合に認証を省略したり、別の端末へ取得先を変えたりはしません。27系では現在の新しい診断トンネルを使います。iPadOS 27.2では端末内の初回OS承認を完了し、新しい認証情報によるバッテリー情報・電池ログの取得も確認しました。17系の実機試験はまだ完了していません。上記は2026年10月9日にTestFlightで配布した1042の対応条件です。17系のシミュレーター試験と27.2の既存ペアリングを使った実機試験を実施しています。
