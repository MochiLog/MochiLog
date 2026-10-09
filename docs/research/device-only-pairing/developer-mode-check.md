# Developer Modeの必須案内と検知（2026-10-09）

端末内の初回OSペアリングはiOS/iPadOS 27以上かつDeveloper Modeオンが条件。iPadOS 27.2で利用者が確認し、端末内のOS承認・Keychain保存・バッテリー情報と電池ログの取得が成功した。

## アプリの開始前の案内

開始ボタンの直前に専用の必須条件カードを表示し、設定経路・再起動・再起動後の承認を説明する。Apple公式の設定手順へリンクする。初回と既存資格情報の置き換えの両方で「オンにしました・開始」の確認を表示し、確認しない限り待受やOSペアリングを始めない。キャンセル時も既存の認証情報・PC連携・記録を変更しない。8言語対応。

これは利用者による確認であり、OSのオン状態を自動検知した表示ではない。アプリの開発署名での起動・シミュレーター・保存済み資格情報・以前の成功から、現在のDeveloper Mode状態を推測しない。

## 調査結果

Apple DTSは[2025年3月の回答](https://developer.apple.com/forums/thread/776532)で、iOSアプリからDeveloper Modeを検知するAPIはないと案内している。Xcode 27.1 SDKの公開ヘッダー／Swift interfaceでも状態取得用APIを確認できなかった。

保守ライブラリideviceにはAMFIの状態読み取りやImage MounterのQueryDeveloperModeStatusがあるが、認証済みの診断サービス接続が前提。端末内で初回ペアリングを始める前はその資格情報がないため、この経路は初回の必須条件検知を解決しない。現行MochiLogのネイティブライブラリではImage Mounter／AMFI機能を有効にしていない。非公開sysctlキー・Private Framework・設定アプリの非公開URLには依存しない。

Developer Modeを勝手にオンにする、OSの再起動や信頼承認を代行する、読めない状態を「オン」と表示する処理は追加しない。ペアリング後にDeveloper Modeをオフにした場合の端末内取得は未検証。

[Apple公式の設定手順](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)。

## ペアリング前の通信を使う判定の追加調査

公開APIがなくても、Developer Modeオフでだけ拒否される未認証の通信があれば判定に使える、という案を検証した。2026年10月9日、実機2台の27.2でペアリングファイルを読み込まず、StartSession／Pairを一切送らないlockdown接続を作った。結果の生データは[匿名化した結果](developer-mode-preauth-20261009.json)を参照。端末ID・鍵・IP・実際のバッテリー値は保存していない。

| 未認証の問い合わせ | 実機2台での結果 | 判定への利用 |
| --- | --- | --- |
| GetValue(ProductVersion) | 27.2を返す | 通信が届いた確認には使えるがDeveloper Modeは分からない |
| GetValue(DeveloperModeStatus, com.apple.security.mac.amfi) | GetProhibited | 読み取り禁止をオフと解釈できない |
| StartService(com.apple.amfi.lockdown) | SessionInactive | 認証セッションが先に必要 |
| StartService(com.apple.mobile.mobile_image_mounter) | SessionInactive | 認証セッションが先に必要 |
| StartService(com.apple.debugserver.DVTSecureSocketProxy) | SessionInactive | 認証セッションが先に必要 |
| StartService(com.apple.dt.remotepairingdeviced.lockdown) | SessionInactive | 認証セッションが先に必要 |

これは既存のOS信頼がある端末へのNetwork/usbmuxd接続で、アプリの認証情報を使わない試験。完全にOS未ペアリングの端末・端末内VPN経路・Developer Modeオフとの対照試験は未実施で、この結果から全経路で不可能とは断定しない。ただし、既存信頼がある状態でさえ上記の未認証要求はDeveloper Modeを返さないため、初回設定の事前判定として今すぐ採用する根拠はない。OS設定の変更や再起動は行っていない。

[StikPairの実装](https://github.com/StikDebug/StikPair/blob/main/rust/src/lib.rs)は端末からの接続を待つ方式で、開始前のDeveloper Mode照会は行っていない。MochiLogで使うideviceのRPPairingハンドシェイクにもDeveloper Modeの直接照会は見当たらず、受け側のallowsPairSetupはホスト側が返す能力情報であり、iOS設定状態の証明にはならない。Bonjour広告の有無も、VPN・ローカルネットワーク許可・Wi-Fi変更・OSの待機状態と区別できない。

ideviceにはデバイスが明示的に返した「Developer mode is not enabled.」を専用エラーに変換する処理があるが、これはOSからその応答を受け取れた場合に限る。無応答、GetProhibited、SessionInactive、接続拒否、タイムアウトは「不明／接続できない」と扱い、オフの確定表示には使わない。

DeveloperModeStatusの問い合わせ先は[pymobiledevice3の読み取り実装](https://github.com/doronz88/pymobiledevice3/blob/master/pymobiledevice3/lockdown.py)に基づく。使える未認証経路が見つかった場合も、実機でオン・オフ両方の対照試験と、VPN／権限／通信断の誤判定試験を通してから表示へ組み込む。
