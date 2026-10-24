# App Store screenshots

`Capture-AppStore-Screenshots.command` をダブルクリックすると、Xcode 27.0で専用シミュレーターを作成・再利用して撮影します。初回はビルドと起動に時間がかかります。

- iPhone 17 Pro Max / iPad Pro 13インチ (M5): ホーム、ログ詳細、分析、設定
- Apple Watch Series 11 (46mm): 端末一覧、ログ一覧、ヘルス表示、詳細指標
- 日本語・英語、ダークモード、標準文字サイズ、iPhone/iPadは縦向き
- アプリ内のサンプルデータを使用。Watchには撮影用iPhoneから書き出した同じデータを渡す（Debugシミュレーター限定）
- 個人用シミュレーターや実機のデータを消去しません

結果は `build/store-screenshots/日時/` に保存されます。`screenshots/{ja,en-US}/` は加工していない実画面、`app-store-artwork/{ja,en-US}/` はストア掲載用の見出し・余白を加えた画像です。どちらも24枚、対応端末の原寸です。終了時には掲載用フォルダーを開き、各セットのZIPも作成します。実画面のUI自体は編集しません。

掲載用の4枚は「状態を把握 → 詳細を確認 → 変化を分析 → 設定」の順です。日本語と英語で同じ構成にしてあり、iPhone、iPad、Apple Watchでは各端末に合った見出しを表示します。ダークモードの実画面と緑のアクセントで統一しています。1〜3枚目に主な価値を置くのは、App Storeの検索結果に最初の1〜3枚が表示されることがあるためです。

CLI: `python3 scripts/capture-store-screenshots.py`。撮影済みの実画面から掲載用画像だけ作り直す場合は `swift scripts/compose-store-screenshots.swift build/store-screenshots/日時/screenshots build/store-screenshots/日時/app-store-artwork` を実行します。見出しは `scripts/compose-store-screenshots.swift` で編集できます。異常時は日時フォルダーの `.log` と `.xcresult` を確認してください。テストに失敗すると停止します。

ストアに使うブランチをチェックアウトして実行してください。Duo専用Xcode 27.1では停止します。画像はGit管理対象外です。

バイナリーのアップロードは撮影と独立しています。既存の `Upload-AppStore.command` はGitHub Actions側のXcodeを使用するため、Macの既定Xcodeとは一致するとは限りません。撮影だけでApp Store Connectのスクリーンショット更新・審査提出・公開は行いません。

機種を限定して撮り直す場合: `python3 scripts/capture-store-screenshots.py --devices iphone`。Watchを指定した場合は、サンプルデータを用意するためiPhoneも撮影します。

App Store Connectへ登録する際は `app-store-artwork` の各言語フォルダーから、`iphone_01`〜`04`、`ipad_01`〜`04`、`watch_01`〜`04` の順に対応する端末枠へ入れます。ZIPをそのままアップロードせず、PNGを使用します。説明文など既存のストアテキストは変更しません。Appleの規則では審査承認済みの版のスクリーンショットを直接差し替えられず、次の編集可能なアプリ版が必要です（[Appleの手順](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)）。
