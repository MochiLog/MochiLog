# MochiLog の AltStore PAL 配信・更新

## リポジトリと共通公開先

- iOS: https://github.com/ryuya0124/MochiLog （ローカル `/Users/ryuya/Documents/MochiLog`）
- Web: `/Users/ryuya/Documents/MochiLog-Web` （origin は `git remote -v` で確認）
- 共通source: https://github.com/ryuya0124/ryuya-altstore
- sourceローカル: `/Users/ryuya/Documents/Codex/2026-09-21/https-github-com-ryuya0124-rytmica-https/work/ryuya-altstore`
- ポータル: https://altstore.ryuya-dev.net/
- Source URL: https://altstore.ryuya-dev.net/altstore/source.json
- Worker: `ryuya-altstore` / 非公開R2: `ryuya-altstore-packages`
- Bundle ID: `net.ryuya-dev.MochiLog` / Apple ID（marketplaceID文字列）: `6756904240`

既存のAltStore PAL連携を共用する。2026-09-22にユーザーがApp Store Connectで連携済みと確認。新しい連携やドメイン、Federation登録は作らない。

## 課金の切り替え

`DonationManager.checkDistribution()` が MarketplaceKit `AppDistributor.current` を起動ごとに判定する。結果はプロセス内だけで保持し、UserDefaults等に永続化しない。

- App Store / TestFlight: 従来のStoreKit寄付を維持。
- marketplace（PALを含む）/ web: 寄付入口、商品取得、購入、購入履歴取得、Transaction監視を無効化。
- 判定失敗・未知の経路: 課金しない。
- MarketplaceKit非対応OS/プラットフォームと `.other`（開発配布等）: 従来の動作。

SimulatorのDebugビルド限定で `MOCHI_TEST_DISTRIBUTOR=appStore|testFlight|marketplace` によるUIテストが可能。Releaseにはこの上書きを含めない。`LanguageAndLayoutTests/testMarketplaceDisablesDonations` を利用する。PALアプリがインストールされているか、地域、レシートファイルの有無では判定しない。

## 新規配信と更新手順

1. 変更をテストし、App Storeと同じBundle IDで新バージョン/ビルドをXcode 27 stableでarchiveする。Duo専用作業だけXcode 27.1を使用。
2. FastlaneでApp Store Connectへアップロードし、該当版のビルドと日英リリースノートを登録する。既存の説明やスクリーンショットを消さない。
3. 通常のApp Review承認による自動公証を待つ。PALだけのNotarizationへ変更しない。
4. Alternative Distribution Package IDを取得し、`https://api.altstore.io/adps/ADP_ID` を照会。通知による自動処理を待つ。自動処理が失敗した場合だけ、共通sourceの `docs/ADDING-ANOTHER-APP.md` に従い手動処理する。
5. ADPをダウンロード・展開。manifest/署名/階層/内容を一切変更しない。App Store用IPAを代用しない。
6. ADP内の全アプリ・拡張のEntitlementsと `*UsageDescription`、最低OS、version/build、variant実ファイルサイズとSHA-256を確認・記録する。現時点の空appPermissionsは未配信のプレースホルダーであり、公開versionを追加する前に必ず実ADPから埋める。
7. 共通sourceで `node scripts/upload-adp.mjs net.ryuya-dev.MochiLog VERSION-BUILD /absolute/ADP-root`。新規release keyを使い、配信済みR2オブジェクトを上書きしない。
8. `src/source.json` のMochiLogだけを更新。新versionを先頭に追加し、downloadURLを `https://altstore.ryuya-dev.net/packages/net.ryuya-dev.MochiLog/VERSION-BUILD/manifest.json` にする。Rytmicaを含む他アプリを保持。
9. `pnpm run check && pnpm run build && git diff --check` → commit/push → `pnpm run deploy`。source・manifestの公開応答を確認。
10. MochiLog Webと共通ポータルの準備中表記を実際の公開状態に合わせて更新。source URLは共通のまま。
11. 対応地域の実機でPALからインストール・起動・更新を検証し、寄付入口がないことを確認。App Store版で寄付が維持されることも確認。端末へのインストール可否はその時点のユーザー指示に従う。

秘密鍵、APIキー、AltStoreトークン、App用パスワードをコード・メモ・gitへ保存しない。認証は既存のKeychain/セッション/環境変数を使用する。

公式資料:
- https://developer.apple.com/documentation/marketplacekit/distributing-your-app-on-an-alternative-marketplace
- https://faq.altstore.io/developers/distribute-with-altstore-pal
- https://faq.altstore.io/developers/rest-api
- https://faq.altstore.io/developers/make-a-source

## 2026-09-22 作業記録

- 共通sourceとMochiLog Webへ準備中案内を公開。sourceのMochiLogは `versions: []`。
- 3.2.1のビルド1014の審査はユーザー指示で取り消し、PAL対応を3.2.1へ統合。新ビルド番号は1015（3.2.2は使用しない）。
- 日英リリースノートは3.2.1の変更点と3.2.0の既存全文を保持。
- Marketplace/App Store/TestFlightのUI切り替えテストが成功。Webの15テストも成功。
- 公証ADPは未取得。ADP取得・権限/ハッシュ照合・R2アップロード・version公開・PAL実機検証が完了するまでは、配信中と案内しない。
