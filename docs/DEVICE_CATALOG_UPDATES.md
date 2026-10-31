# 機種データの独立更新（4.1.0以降）

## 管理と配信

機種データ、Swift製の署名ツール、検証コードはすべて **MochiLog OrganizationのMochiLog/MochiLog** で管理する。

- レビュー用データ：`device-catalog/catalog.json`
- 配信用の署名付きデータ：`device-catalog/catalog.signed.json`
- 署名ツール：`scripts/DeviceCatalogSigner.swift` / `scripts/device-catalog.sh`
- アプリの形式検証・公開鍵：`MochiLog/Models/DeviceCatalog.swift`
- 公開先：<https://raw.githubusercontent.com/MochiLog/MochiLog/main/device-catalog/catalog.signed.json>

JSONには機種名、識別子、基板ID、SoC、モデル番号、標準容量、地域・SIM構成別の容量だけを置く。実行コードや解析ルールは配信しない。元資料は確認して採用し、外部サイトの未確認値を自動採用しない。

`schemaVersion`は形式、`revision`は内容の版を表す。初版は`2026110101`。内容を変更するときは、必ず現在より大きいrevisionにする。日付と連番の`YYYYMMDDNN`を推奨する。同じrevisionで内容を差し替えると、既存キャッシュを持つアプリは拒否する。

## 通常の機種追加・修正

1. `catalog.json`の該当機種を編集する。既存profileの`id`は変えない。新機種には重複しない固定IDを付け、`revision`を増やす。
2. 元資料、機種ID・基板IDの組み合わせ、容量・SIM構成を確認する。
3. 下記を実行し、JSONと署名を同じコミットに入れてmainへ公開する。

```sh
bash scripts/device-catalog.sh sign device-catalog/catalog.json device-catalog/catalog.signed.json
bash scripts/device-catalog.sh verify device-catalog/catalog.signed.json device-catalog/catalog.json
bash scripts/test-device-catalog.sh
bash scripts/test-device-library.sh
bash scripts/test-device-profiles.sh
git diff --check
```

データだけの更新ではアプリのビルド番号を増やしたり、TestFlight/App Reviewへ提出したりする必要はない。GitHub Actionsの`Verify signed device catalog`も署名とレビュー用JSONの完全一致、および回帰テストを検証する。CIは署名鍵を持たず、検証だけを行う。

`scripts/export-device-catalog.sh`はアプリの同梱データからの初期エクスポート用で、通常の更新には使わない。使うとダウンロード配信だけで追加した機種がエクスポート対象に入らないため、既存JSONを上書きしないこと。

## 署名鍵

Ed25519署名にApple CryptoKitを使用する。アプリには公開鍵だけを同梱する。秘密鍵はMacのKeychainに保存し、ソース、JSON、CIログ、成果物には含めない。ローカルツールは`build/tools/DeviceCatalogSigner`に生成し、ビルド済みツールを再利用する。初回やツール更新時にはMacのKeychainアクセス許可が必要な場合がある。

`generate-key`はKeychainにまだ鍵がないときだけ新規作成し、公開鍵だけを出力する。既に配布した公開鍵を勝手に変更しない。新しい署名鍵へ移行する際はアプリ側の信頼鍵更新が必要になる。CIなどで明示的に署名する場合のみ`DEVICE_CATALOG_SIGNING_KEY`のBase64秘密鍵に対応するが、公開リポジトリへ保存しない。

## アプリの更新動作

- 自動確認は初期状態でオン。「高度な設定 → デバイス情報を管理 → 機種データの更新」で切り替える。
- 起動・復帰時、成功した確認から24時間以上経過していれば取得する。失敗後の自動確認は最短1時間後で、復帰のたびに再試行しない。
- 未知の機種IDをログから検出した場合は、通常の24時間待ちとは別に確認を試みる。機種をまたいでも最短1時間に1回に制限する。自動確認オフの場合は実行しない。
- 単一ログ・複数ログの取り込みは共通の確認処理を利用する。同時要求は1件の通信を共有する。更新で機種を解決できた場合は、保存前に元ログを再解析する。
- 手動確認は自動確認オフでも使える。データ版と最終成功確認日時を表示する。
- HTTPSと署名、対応するschema、全体の整合性、サイズ制限、revisionを検証する。HTTPリクエストは15秒、リソース全体は30秒に制限する。2MBを超える応答は読み込み途中で打ち切る。
- 正常な署名付きデータだけを原子的にキャッシュへ保存する。キャッシュはバックアップ対象外。読み込み時にも署名を検証する。
- 同梱版より古いデータ、現在のデータからの巻き戻り、同一revisionの異なる内容は拒否する。誤配信を戻す際も修正内容を新しいrevisionで配信する。
- 通信失敗、形式非対応、署名不正では最後の正常データを維持する。キャッシュが使えなければ同梱データへ戻る。同梱モデルを一部省略した配信でも、そのモデルを消さない。
- ETagがある場合は変更有無だけを確認する。キャッシュがない状態では古いETagを使わない。

## 設定・記録・互換性

優先順位は手動設定、配信標準データ、同梱データ。ローカルの手動編集エントリーは更新で書き換えず、標準データが変わった場合は既存の競合確認画面で選択できる。復元・競合解決も、その時点の標準データを参照する。

保存済みのバッテリー記録、測定値、個体ID、日付、Core Data/SwiftData/iCloudスキーマは変更しない。過去記録の補正が必要な場合は`Migrations/DeviceLibrary/`へ別途バージョン付きの補正を追加し、旧値一致、手動値保護、再適用防止、両ストアでの検証を行う。配信JSONから任意の移行処理を動かさない。

4.0.1以前にはこの更新機能がないため、引き続きそのアプリに同梱されたデータを使う。新しいログ形式・計算処理・機能やカテゴリの追加、形式や信頼鍵の変更にはアプリ更新が必要。

更新の開始・成功・拒否理由・保持したrevisionは`DeviceCatalog`カテゴリのOSログへ残す。問い合わせや通常の記録データを更新リクエストに載せない。GitHubへの通信についてアプリ内8言語とWebのプライバシーポリシーへ記載する。

## 検証

`test-device-catalog.sh`は署名の改ざん・別の鍵、応答サイズ、非対応形式、不正・重複データ、キャッシュ再起動、巻き戻り・同一版差し替え、手動設定・競合・同梱フォールバック、同時要求、自動確認オフ、手動確認、オフライン・未知機種の再試行制限、ETagを検証する。

UIテストではiPhone/iPadの8言語で設定への導線、版表示、手動確認、自動確認オフ時の利用、結果の翻訳を確認する。実施結果とベータ配信状態は`TESTFLIGHT_BETA_4.1.0.md`へ記録する。
