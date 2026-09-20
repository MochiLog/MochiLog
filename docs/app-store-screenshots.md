# App Store screenshots

`Capture-AppStore-Screenshots.command` をダブルクリックすると、Xcode 27.0で専用シミュレーターを作成・再利用して撮影します。初回はビルドと起動に時間がかかります。

- iPhone 17 Pro Max / iPad Pro 13インチ (M5): ホーム、ログ詳細、分析、設定
- Apple Watch Series 11 (46mm): 端末一覧、ログ一覧、ヘルス表示、詳細指標
- 日本語・英語、ダークモード、標準文字サイズ、iPhone/iPadは縦向き
- アプリ内のサンプルデータを使用。Watchには撮影用iPhoneから書き出した同じデータを渡す（Debugシミュレーター限定）
- 個人用シミュレーターや実機のデータを消去しません

結果は `build/store-screenshots/日時/screenshots/{ja,en-US}/` に24枚出力され、フォルダーが開きます。同じ日時フォルダーに `MochiLog-screenshots.zip` も作ります。PNGは原寸で、端末枠や装飾はありません。

CLI: `python3 scripts/capture-store-screenshots.py`。異常時は日時フォルダーの `.log` と `.xcresult` を確認してください。テストに失敗すると停止します。

ストアに使うブランチをチェックアウトして実行してください。Duo専用Xcode 27.1では停止します。画像はGit管理対象外です。

バイナリーのアップロードは撮影と独立しています。既存の `Upload-AppStore.command` はGitHub Actions側のXcodeを使用するため、Macの既定Xcodeとは一致するとは限りません。今回の3.2.0 (1012) はローカルのXcode 27.0でアーカイブ・アップロードしています。撮影だけで審査提出・公開は行いません。

機種を限定して撮り直す場合: `python3 scripts/capture-store-screenshots.py --devices iphone`。Watchを指定した場合は、サンプルデータを用意するためiPhoneも撮影します。
