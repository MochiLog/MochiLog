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

UIFileSharingEnabledを有効化し、Documents/pairingFile.plistまたはrpPairingFile.plistを認識する。64KiB以下の通常ファイルのみ読み、シンボリックリンクを拒否。両形式を厳格に区別し、UDIDメタデータが含まれる場合は既存の端末UDIDと照合する。標準ファイルにUDIDがない場合、MochiLog側で既存のOS信頼による接続を確認し、診断の読み取り前にUniqueDeviceIDを取得して資格情報へ紐づける。既存の資格情報がある場合はそのUDIDとも照合し、違う端末・認証失敗・不正なファイルでは以前のKeychain資格情報・履歴・PCペアリングを保持する。通常の読み取りでもUniqueDeviceIDを照合する。

UDIDなしのファイルを受け取ったときはVPNと既存信頼の検証が成功するまで配置元を保持し、次の前面復帰で再試行する。新規のOSペアリングを自動で始めない。確認できた鍵はWhenUnlockedThisDeviceOnlyのKeychainに保存し、成功後に配置元を削除。ログにはキー、PIN、証明書本文を記録しない。iOSアプリのMac実行ではこの機能を開始しない。

## 上流ツール用変更案

`scripts/patches/idevice-pair-mochilog.patch`は上流c8114c2bb88a80e2e17c0d9297b9915f09498eadに対して適用する。ユーザーの指定に従い、既存のKSign等の追加PRと同じ登録方式に限定した。

- `known_apps.rs`のLockdown/Remoteの両リストに `("MochiLog", PLIST)` を追加（2行）。
- READMEの対応アプリ一覧にMochiLogのリンクを追加（1行）。

MochiLog専用の書き込み分岐、端末IDの追記、AFC rename、Bundle ID分岐、依存ライブラリの追加は含めない。上流の標準ファイル・共通のインストール処理をそのまま使う。先の専用処理付きローカル案とそのビルド結果は、この最小登録案の実機動作証明として使わない。

実機AFC設置と、起動後の利用確認が通るまで、ユーザーの指定に従って上流PRを提出しない。

## 自動テスト

`scripts/test-local-diagnostics-cold-install.py`は、既存のシミュレーターを初期化せず、各ケース専用の端末を作成・削除する。終了中のMochiLogに合成ファイルを配置してから起動し、通常の初期化処理が取り込むかを確認する。正常ファイル、UDIDなしの標準ファイル、新旧Remoteフィールドの別名、破損ファイル、シンボリックリンクが対象。

UDIDなしの標準ファイルは合成Lockdownサービスと相互TLSで検証する。Remoteの別名ケースは形式の互換性を確認するための合成鍵であり、Appleの実RPPairingサービスを再現するものではない。iOS 17の実機OSサービスの可否、USBの信頼ダイアログ、公式インストールボタン、AFC書き込み中の挙動、実RPPairingの最終利用は実機検証として別に残る。

2026-10-09: iOS 17.0のiPhone 15 Proシミュレーターで、5つの起動時ケース × 19項目（95項目）が成功。値を含まない結果は `docs/research/direct-install-cold/phone-ios17.json`。UDIDのない標準ファイルも、既存信頼の認証後に端末IDを取得して取り込めた。iPadOS 27.0側は再確認中。
