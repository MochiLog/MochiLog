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
