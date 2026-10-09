# MochiLog 4.0.0 Beta (1043)

## 日本語

MochiLog 4.0.0 beta (1043)

1043の更新：端末内の初回ペアリングにはDeveloper Modeをオンにする必要があります。開始ボタンの直前に専用の案内を表示し、設定経路・再起動・再起動後の承認まで説明します。初回も「オンにしました・開始」の確認が必要です。アプリは設定状態を自動検知できないため、オンにしたことを確認してから進めてください。キャンセルでは待受を開始せず、既存の認証情報を保持します。8言語対応です。iOS/iPadOS 27以降の端末内ペアリングは、iPadOS 27.2実機でOS承認・現在のバッテリー・電池ログ取得まで確認しました。PCの既存ペアリングの再利用も残ります。

MochiLog対応版のidevice_pairでは、アプリを閉じたままインストールボタンからファイルを設置し、次の起動・前面復帰時に自動で取り込めます。公式ツールへのアプリ登録PRは提出済みで、公式配布版の対応は採用・リリース待ちです。端末IDの記載の有無にかかわらず、保存前に既存のOS信頼と端末IDを確認します。VPN未接続、失効した鍵、別端末のファイル、接続方式に合わないファイルは以前の資格情報を置き換えません。成功時は端末専用Keychainへ保存し、設置元を削除します。OS更新だけを理由にペアリングを削除しません。新旧フィールド名と追加情報も保持します。

今回、iPadOS 27.2実機で標準Remoteファイルの設置・自動取り込み・現在のバッテリー情報・電池ログ読み取りを確認しました。使えないLockdownファイルを受け取った後も以前の設定で取得できることと、iOS 17の自動テスト100項目を確認しています。

自動ログ収集を設定の独立した項目に移しました。PC連携と端末内取得は別々にオン・オフでき、同時利用も可能です。手動のログ追加はPCなしでも引き続き使えます。

端末内取得は、対応するローカルVPN／リフレクター経路を利用して、そのiPhone・iPad自身の診断サービスへ認証して接続する実験機能です。初期状態はオフです。対応する最新版PCと既存のペアリングがある場合、明示的に自分の端末のOSペアリング情報を暗号化して引き継げます。外部で作成したペアリングファイルも読み込めます。Appleの初期OS信頼設定は必要で、MochiLogのQRだけでは作成できません。別アプリのLocalDevVPNなど、対応経路を有効にしてください。端末内取得はiOS/iPadOS 17以降で、アプリを開いている間に動作します。17.0〜17.3はLockdown、17.4以降はRPPairingと対応するVPN経路を使用します。17系の実機は未検証で、シミュレーターによる認証・取り込み試験を行っています。PC連携は27以降が対象です。初回設定の完全無線化・Developer Modeオフ・バックグラウンドでの取得は保証しません。

Apple WatchのログはペアのiPhoneから取得します。端末内取得とPC受信は同じスマホ側の解析・取り込み処理を使い、ファイルのハッシュと個体ID、既存記録で重複を避けます。解析前に終了した場合も一時ファイルから再開し、成功後は削除します。PCにはパーサーを追加していません。日次ログと現在のバッテリー情報は独立して取得します。

現在のバッテリーでは、同じPCとペアリングした複数のiPhone・iPadについて、双方のiCloud同期がオン・同じApple Accountと確認できた場合だけ、他の端末の現在値も表示します。同期オフ・別アカウント・未確認では共有しません。同じ個体の共通値はまとめ、PCごとに異なる値だけ比較できます。値自体は履歴・記録・iCloud・サポートの診断ログに保存しません。タブの表示切り替えは標準タブバーのアニメーションを使います。

新しいMac 0.2.21 Beta／Windows 0.1.18 Alphaでは、自動更新確認は初期状態でオフです。初回の選択画面または設定で有効にできます。既存ペアリングを引き継ぎ、旧版との自分の端末の転送も維持します。機能の案内、8言語、依存ライセンス、プライバシーポリシー・利用規約を更新しました。

PC経由の他端末共有では、共有元の同期許可を再確認します。通信不能で取り消しが届かない場合、PC内の直前の許可は最大15分で期限切れになります。Macで起動したiOS版にはPC連携の操作を表示しません。

端末内取得の認証に失敗する場合はPCを上記以降へ更新し、「既存ペアリングを利用」で情報を取り直してください。ホスト名の大文字・小文字による認証失敗を修正しています。QRやUSBの信頼設定のやり直しは不要です。

## English

MochiLog 4.0.0 beta (1043)

Build 1043 requires Developer Mode for on-device pairing (27+). A prerequisite card explains settings, restart and approval. First setup and replacement require confirmation before starting. The app cannot detect the setting; confirm it is on. Cancel keeps credentials and starts no listener. All eight languages are covered.

A MochiLog-compatible idevice_pair can install a pairing file while MochiLog is closed; import is automatic on next launch or foreground return. The official app-registration PR is submitted, awaiting acceptance and a tool release. All files, with or without device-ID metadata, must authenticate existing OS trust and identity before replacing credentials. Disconnected VPNs, revoked keys, foreign-device files and unsupported routes keep the previous credential. Successful import uses device-only Keychain storage and removes staging. OS updates alone do not delete trust; old/new field names and additional metadata are retained.

On iPadOS 27.2 hardware, standard Remote install, import, battery and Analytics reads succeeded. An unusable Lockdown file no longer replaces working credentials. The iOS 17 simulator passed 100 checks.

Automatic Log Collection is now a separate Settings section. PC transfer and on-device acquisition have independent switches and can be used together. Manual log import remains available without a computer.

On-device acquisition is experimental and off by default. It authenticates to this iPhone or iPad’s own diagnostic service through a compatible local VPN/reflector route. With an updated, already paired computer, explicitly reuse your own device’s OS pairing through encrypted authenticated transfer, or import an externally created pairing file. Initial Apple OS trust is still required: the MochiLog QR alone cannot create it. Enable a compatible route such as the separate LocalDevVPN app. On-device acquisition requires iOS/iPadOS 17 or later and foreground use: Lockdown for 17.0–17.3, RPPairing for 17.4+, with a compatible VPN route. iOS 17 physical OS services remain untested; authentication and import were tested in the simulator. PC transfer requires 27+. Fully wireless initial setup, Developer Mode-off operation and background acquisition are not guaranteed.

Apple Watch logs are read from the paired iPhone. Both acquisition paths feed the same mobile parser and import queue, checking hashes, physical-device identity and existing records to avoid duplicates. Staged files survive interruptions and are removed after successful import. No parser was added to the computer apps. Daily logs and current battery values are acquired independently.

Live Battery can now display other physical devices paired with the same computer only when both have confirmed iCloud sync enabled on the same Apple Account. Sync-off, different-account and unconfirmed cases are excluded. Common values from multiple computers reading the same device are combined; only differing values are compared. Current values are not saved to history, records, iCloud or support diagnostic logs. Enabling or disabling the tab uses the native tab bar animation.

Mac 0.2.21 Beta and Windows 0.1.18 Alpha offer automatic update checks, off by default, in an initial choice and settings. Existing pairings and older own-device transfers remain compatible. Guides, all eight app languages, dependency licenses, privacy policy and terms have been updated.

Other-device sharing rechecks source consent. If revocation cannot reach a computer, previous consent expires within 15 minutes. The iOS app running on Mac hides PC transfer controls. Please report beta issues from the companion support screens.

If on-device authentication fails, update the companion to these versions or later and reuse the existing pairing again. The companion fix preserves the original hostname spelling used for OS trust. Do not delete your QR pairing or reset USB trust.

## 検証

8言語の必須条件カードと初回確認・キャンセルをiPhone/iPadのUIテストで確認する。既存資格情報を使った状態検知は初回設定を解決しないため、自動判定として表示しない。Developer Mode検知の調査は[開発メモ](research/device-only-pairing/developer-mode-check.md)を参照。
