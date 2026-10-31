# MochiLog — 開発・運用

この文書は、実装・検証・ビルド・配信を行う開発者向けの入口です。利用者向けの機能、導入、操作、サポートは[ルートREADME](../README.md)と[利用ガイド](https://mochilog.ryuya-dev.net/guide?lang=ja)で案内します。

## 文書の置き分け

- ルート`README.md`：GitHubで最初に読む利用者向けの説明と使い方。開発コマンド、署名・鍵の管理、CI、検証結果、作業履歴を混在させない。
- `docs/DEVELOPMENT.md`：開発者向け文書の入口。
- `docs/`：実装・運用・リリース・調査・検証の記録。ビルド番号や当時の制約は日付・対象版を明示する。
- `Tests/README.md`、`fastlane/README.md`など：各領域の開発手順。第三者ライセンス配下のREADMEは原文を維持する。

## 開発環境・ビルド・テスト

- [開発環境の確認記録](DEVELOPMENT_ENVIRONMENT_2026-10-26.md)：Xcode、依存関係、署名と実機・シミュレーターの確認。本文の情報は記録日の状態。
- [ローカル資源管理](LOCAL_DEVELOPMENT_RESOURCES.md)
- [テスト](../Tests/README.md)
- [fastlane](../fastlane/README.md)
- [DeviceLibrary移行の構成](../MochiLog/Migrations/README.md)

現在のmainは4.1.0ベータの開発対象。App Store向け4.0.1は`release/4.0.1`で管理する。プロジェクトのmainアプリ、共有拡張、Watchアプリのバージョンとビルド番号を揃える。

## 配信・機種データ

- [4.1.0 TestFlight配信記録・次回の手順](TESTFLIGHT_BETA_4.1.0.md)
- [機種データの更新と署名ツール](DEVICE_CATALOG_UPDATES.md)：アプリのビルドを伴わないデータ更新、Keychainの署名鍵、CI、検証と復旧。
- [機種情報の修正とストア提出記録](DEVICE_LIBRARY_RELEASE_2026-10-25.md)

APIキー、秘密鍵、ペアリング情報、実機の生ログや診断スナップショットは公開リポジトリに保存しない。配信状態はApple/GitHubの最終状態を確認して記録し、ビルドやアップロードの成功だけで公開済みと扱わない。

## 互換性・過去の作業記録

端末内取得のOS別経路、背景実行と検証対象の違いは[自動ログ収集の詳細](automatic-log-collection.md)を参照する。17.0〜17.3のLockdown経路、17.4以降のRPPairing経路、ベータ1050以降の背景取得などは対象版と条件を区別する。

`idevice_pair`への登録の経緯は[PR #84](https://github.com/jkcoxson/idevice_pair/pull/84)を参照する。利用者向けの対応状況を案内するときは、採用されたソースと実際に配布された版を確認する。

[旧開発ブランチの記録](README_20260908_DEVELOPMENT.md)は履歴資料。その文書内の「未マージ」「未公開」や当時の共有方式を現在の状態として扱わない。
