# idevice_pairからMochiLogへの直接インストール

2026-10-09。MochiLog側の受け口と上流ツールへの変更案を実装。公式へのPRは未提出、公式配布版の対応は未完了。

## 公式への追加方法を確認した結果

現行の[known_apps.rs](https://github.com/jkcoxson/idevice_pair/blob/c8114c2bb88a80e2e17c0d9297b9915f09498ead/src/known_apps.rs)は、対応アプリの表示名とDocuments内の保存先を固定リストで管理している。任意のアプリが自己登録するInfo.plistキー、設定ファイル、URLスキームによる登録口は、現在のリスト生成・書き込みコードにはない。

[KSignの追加PR #64](https://github.com/jkcoxson/idevice_pair/pull/64)は2026-05-05にマージされている。[作者のコメント](https://github.com/jkcoxson/idevice_pair/pull/64#issuecomment-4376410708)にも、アプリ側の対応ができたら所有者がPRを開いてよい旨がある。[Antragの追加PR #12](https://github.com/jkcoxson/idevice_pair/pull/12)もマージ済み。[README](https://github.com/jkcoxson/idevice_pair#contributing)はPR・Issue・機能要望を受け付けている。

したがって公式版の一覧へ追加するには上流コードの変更と作者による配布が必要で、PRは実績のある方法。ただし「PRだけが唯一の申請手続き」という規則は見つかっていない。MochiLog側の対応だけで公式ボタンが増えるとは案内しない。

## 利用者の動作

MochiLog対応版のidevice_pairで対象端末を選び、ペアリングファイルを作成または読み込んでMochiLogへのインストールを選ぶ。House Arrest/AFCがDocuments/pairingFile.plistへ直接配置するため、この操作にMochiLogの起動は不要。次回の起動・前面復帰で自動的に利用し、アプリ内ファイル選択は不要。

iOSの終了中プロセスはこの操作で起動しないため、Keychainへの取り込みと元ファイルの削除は次の起動・復帰時。外部ツールがMochiLogのKeychainへ直接書くわけではない。アプリの自動収集・現在値のオプトインは変更しない。

公式版にMochiLogがまだ出ない場合、既存の書き出し＋手動取り込みを利用できる。iOS 17.0–17.3はLockdown、17.4以降はRPPairingも対象。端末内の新規OSペアリングは27以上。OS更新だけで既存ファイルを失効扱いにはしない。

## アプリ側

UIFileSharingEnabledを有効化し、Documents/pairingFile.plistまたはrpPairingFile.plistを認識する。64KiB以下の通常ファイルのみ読み、シンボリックリンクを拒否。両形式を厳格に区別し、UDIDメタデータが必須。既存の端末UDIDと異なるものや不正なファイルは採用せず、以前のKeychain資格情報・履歴・PCペアリングを保持する。認証後の診断読み取りでもUniqueDeviceIDを照合する。

受け取った鍵はWhenUnlockedThisDeviceOnlyのKeychainに保存し、成功後に配置元を削除。ログにはキー、PIN、証明書本文を記録しない。iOSアプリのMac実行ではこの機能を開始しない。

## 上流ツール用変更案

scripts/patches/idevice-pair-mochilog.patchは上流c8114c2bb88a80e2e17c0d9297b9915f09498eadに対して適用する。

- Lockdown/Remoteの両リストにMochiLogを追加し、正しいBundle IDのみに限定。
- Remoteファイルに通常ないUDIDを、認証済みの対象端末から読み取って追加。既存UDIDが違えば書き込みを拒否する。
- その他のペアリング項目は全て保持。他アプリへの書き込みは変更しない。
- 一時ファイルを閉じてからAFC renameで設置し、途中のファイルをアプリが読むのを防ぐ。

上流パッチのplist変換部分は4項目のRustテストで確認。フルGUIビルドはGitHub Actionsで別途検証する。Mac/Windowsの公式ツールを使用した実機AFC設置は未確認。シミュレーターでは配置されたファイルの採用・異なる端末の拒否・破損ファイルで以前の設定を保持する動作を確認している。
