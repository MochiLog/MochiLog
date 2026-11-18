# MochiLog — 開発・運用

この文書は、実装・検証・ビルド・配信を行う開発者向けの入口です。利用者向けの機能、導入、操作、サポートは[ルートREADME](../README.md)と[利用ガイド](https://mochilog.ryuya-dev.net/guide?lang=ja)で案内します。

## 文書の置き分け

- ルート`README.md`：GitHubで最初に読む利用者向けの説明と使い方。開発コマンド、署名・鍵の管理、CI、検証結果、作業履歴を混在させない。
- `docs/DEVELOPMENT.md`：開発者向け文書の入口。
- `docs/`：実装・運用・リリース・調査・検証の記録。ビルド番号や当時の制約は日付・対象版を明示する。
- `Tests/README.md`、`fastlane/README.md`など：各領域の開発手順。第三者ライセンス配下のREADMEは原文を維持する。

## 開発環境・ビルド・テスト

2026-11-04に、このMacのソースを`/Users/ryuya/Documents/MochiLog/`へ集約した。同名の親フォルダと区別し、スマホ版のGitルートは`/Users/ryuya/Documents/MochiLog/MochiLog/`とする。`MochiLog-Mac`、`MochiLog-Windows`、`MochiLog-Web`はその兄弟フォルダ。署名ツールはスマホ版の`scripts/`に含まれる。各リポジトリのGit履歴・ブランチ・未コミット変更・ビルド中間物は保持している。署名鍵の保管場所は変更していない。

- [開発環境の確認記録](DEVELOPMENT_ENVIRONMENT_2026-10-26.md)：Xcode、依存関係、署名と実機・シミュレーターの確認。本文の情報は記録日の状態。
- [ローカル資源管理](LOCAL_DEVELOPMENT_RESOURCES.md)
- [テスト](../Tests/README.md)
- [fastlane](../fastlane/README.md)
- [DeviceLibrary移行の構成](../MochiLog/Migrations/README.md)

2026-11-18現在、mainは4.1.1 (1071)。ストアは審査待ち、内部TestFlightは配布中、外部TestFlightはベータ審査待ち。配信・取り込み監査は[4.1.1の記録](RELEASE_4.1.1.md)を参照する。公開版4.1.0の履歴は保持し、廃止済み4.0.2を再配布しない。旧release/4.0.1とrelease/4.0.2は履歴タグへ保存して整理した。プロジェクトの本体・共有拡張・Watchアプリの版とビルド番号を揃える。

## 配信・機種データ

- [4.1.0 TestFlight配信記録・次回の手順](TESTFLIGHT_BETA_4.1.0.md)
- [機種データの更新と署名ツール](DEVICE_CATALOG_UPDATES.md)：アプリのビルドを伴わないデータ更新、Keychainの署名鍵、CI、検証と復旧。
- [機種情報の修正とストア提出記録](DEVICE_LIBRARY_RELEASE_2026-10-25.md)

APIキー、秘密鍵、ペアリング情報、実機の生ログや診断スナップショットは公開リポジトリに保存しない。配信状態はApple/GitHubの最終状態を確認して記録し、ビルドやアップロードの成功だけで公開済みと扱わない。

## 互換性・過去の作業記録

端末内取得のOS別経路、背景実行と検証対象の違いは[自動ログ収集の詳細](automatic-log-collection.md)を参照する。17.0〜17.3のLockdown経路、17.4以降のRPPairing経路、ベータ1050以降の背景取得などは対象版と条件を区別する。

`idevice_pair`への登録の経緯は[PR #84](https://github.com/jkcoxson/idevice_pair/pull/84)を参照する。利用者向けの対応状況を案内するときは、採用されたソースと実際に配布された版を確認する。

[旧開発ブランチの記録](README_20260908_DEVELOPMENT.md)は履歴資料。その文書内の「未マージ」「未公開」や当時の共有方式を現在の状態として扱わない。

## Pairing diagnostics and support exports (2026-11-13)

See [the implementation and verification notes](PAIRING_DIAGNOSTICS_2026-11-13.md) for pairing failure audits, split-file attachments, compatibility and export limits.

See also [the timeout-path audit and ZIP follow-up](PAIRING_TIMEOUT_AUDIT_2026-11-13.md).
