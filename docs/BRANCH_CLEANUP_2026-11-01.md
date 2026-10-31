# 開発ブランチの整理（2026-11-01）

対象はMochiLog Organizationのモバイル、Mac、Windows、Webの4リポジトリ。各originを取得し、mainへの到達性、公開中のPR、ローカル作業ツリーを確認した。公開中のPRは4リポジトリともなし。Mac・Windows・Webはすでにmainのみだった。

## モバイルの整理対象

| ブランチ | 先端コミット | 扱い |
| --- | --- | --- |
| `chore/testflight-release-workflow` | `f55a7dffe1b0ef2198eb008d48af99bea4e93967` | mainに統合済み。ローカル枝を削除。originに同名枝はなし |
| `experiment/mac-log-transfer` | `c2093b8cc396f57fb02a2ac1af60db51f4c1bbbb` | mainに統合済み。ローカルとoriginの枝を削除 |
| `refactor/ios27-batch-import-adaptive-ui-20260908` | `940d32400d0f3604ae7f2ad135e80c6439f62d49` | mainに統合済み。ローカルとoriginの枝を削除 |
| `backup/detached-icloud-diagnostics-20260919` | `bd8094e3fcd7d22df196c3c618169ace291ab187` | 未統合の診断WIP。先に公開タグへ保存し、ローカルとoriginの枝を削除 |

`main`とストア用`release/4.0.1`は維持する。バックアップのWIPをmainへ取り込む作業ではなく、コードや配布済みビルドは変更しない。

## 履歴と作業ファイルの保護

- 未統合の診断WIPは注釈付きタグ`archive-icloud-diagnostics-20260919`へ保存。originのタグを再取得し、元のコミットへの参照を確認してから枝を削除する。
- さらにGit bundleをGit管理外の`build/branch-cleanup-20261101/icloud-diagnostics.bundle`へ保存・検証した。bundleの前提コミットはmain履歴にある。
- 統合済み3枝のコミットはmainの履歴に残る。旧開発メモの再現手順とMac調査資料のリンクは、削除する枝名から固定コミットへ変更する。
- 旧`MochiLog-mac-log-transfer`作業ツリーは同じ先端コミットのdetached HEADへ切り替える。ファイル、未コミット変更、無視対象のビルド・ログを削除しない。
- すでに存在しない一時作業ツリー`/private/tmp/mochilog-main-testflight-workflow`の登録だけをpruneする。
- 削除時はoriginの対象枝に期待するコミットを指定し、同時更新があれば削除を停止する。

必要なら履歴から枝を再作成できる。例えば診断WIPは次のように復元する。

```sh
git fetch origin --tags
git branch recovered/icloud-diagnostics archive-icloud-diagnostics-20260919
```

整理前後のローカル参照と作業ツリーの状態は、Git管理外の`build/branch-cleanup-20261101/`へ記録する。
