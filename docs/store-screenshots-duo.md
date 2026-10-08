# ストアのスクリーンショット更新

ストア更新時はiPhone・iPad・iPhone Duo・Apple Watchを確認します。既存の説明・キーワード・スクリーンショットを一括削除しません。撮影は公開予定のバージョンから行い、TestFlightだけの機能を既存の安定版の画像へ混ぜません。

Xcode 27.1以降を使用します。DuoはDevice Hubの「Open」で内側、「Closed」で外側に切り替えます。ディスプレイの電源操作は折りたたみの代わりになりません。通常の撮影は検証済みの外側を既定とし、内側は明示的に指定します。

```sh
python3 scripts/capture-store-screenshots.py
# 内側も撮る場合、Device HubでOpenに切り替えてから実行
python3 scripts/capture-store-screenshots.py --devices duo --duo-screen inner
```

JA・ENのホーム／詳細／分析／設定を実際の画面から撮影し、内側2007×2853・外側1398×2034を検証します。Duoを除く端末の画像を拡大して代用しません。デザイン出力はRGB・アルファなしのPNGです。撮影中は1並列ビルドとし、端末ごとに停止します。Watchの撮影に必要なペアだけは同時起動します。失敗時も今回の撮影用シミュレーターを停止し、個人用端末を消去しません。

デザインしたDuo画像を`fastlane/store-assets/duo/ja`と`en-US`へ保存してコミットします。`Inspect Store Assets`の`upload-duo`を実行すると、新しいAppleのAsset Library APIにDuoとして追加します。既存の説明・iPhone・iPad・Watch画像は変更しません。同じ画像を再実行しても参照名と配置を確認します。APIキーはGitHub Secretsを使います。画像登録と安定版アプリの審査提出は別で、スクリプトは新しいストアバージョン作成・審査提出・公開をしません。

## 次回の更新チェック

- iPhone、iPad、Duo、WatchそれぞれのJA・ENを撮影する。
- Duoの両画面を確認し、画像サイズ・言語・UIの切れを確認する。
- 追加対象バージョンを指定してアップロードし、既存ストア情報と既存画像が保持されていることを確認する。
- 一時ビルド・今回だけ作成した不要シミュレーターは検証後に整理する。
