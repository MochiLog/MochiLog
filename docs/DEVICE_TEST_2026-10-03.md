# 2026-10-03 実機検証メモ

利用者向けの説明は Mac・Windows 各リポジトリの `docs/USER_GUIDE.md` に置く。この文書は開発・回帰確認用であり、README には統合しない。

## 対象

- iPhone 17（iOS 27.2）と iPad Pro 13-inch M4（iPadOS 27.2）：MochiLog 4.0.0 (1028) の開発署名ビルドを既存アプリの上にインストール。`devicectl device info apps` で両方 1028 を確認。iOS 27.2 実機用のローカルビルドには Xcode 27.2 beta 2 を指定し、既定の `xcode-select` は Xcode 27.0 のまま維持した。
- Mac：MochiLog Mac 0.2.9。Windows 11：MochiLog Windows 0.1.7。iPad は両方とアプリペアリング済み、iPhone は Mac とペアリング済み。
- App Store Connect 用 1028 は GitHub Actions の Xcode 27 ランナーで署名ビルド・アップロードに成功。日本語・英語の TestFlight 説明を登録し、既存の内部グループと外部 `main` グループへ追加。外部ベータ審査は `WAITING_FOR_BETA_REVIEW`。

## 確認した動作

1. Mac と Windows は、当日のホストログと必要な Watch ログが揃った端末の自動再走査を翌朝まで停止した。手動収集と暗号化転送の待受は継続する。
2. Windows 実機では標準ポート `54556` が OS の予約範囲にあり、旧版は転送待受を起動できなかった。0.1.7 は別の空きポートを選択・保存し、再起動後も同じポートで待受。Mac から TCP 接続を確認した。QR と Bonjour には実際のポートを広告する。
3. iPhone 17 の MochiLog 起動後、Mac は当日の iPhone ログ1件と Watch ログ2件を SHA-256 事前照会後に転送。端末ログに `Transfer: confirmed 3 received file(s)` と Mac 側の受信確認・解析開始が記録された。端末は必要な当日分を確認し、Mac へ翌朝までの自動収集停止を要求・確認した。
4. iPad 起動後、Mac から前日と当日のホストログ2件を受信。端末ログに `Transfer: confirmed 2 received file(s)` と解析開始が記録された。続いて Windows へ自動で切り替わり、同じ2件について `local=imported; decision=have` を返し、本文の再送なしで Windows の転送キューを完了した。両 PC の日付別デバッグログも端末へ転送され、両 PC に当日分の自動収集停止を確認した。
5. iPad の Bonjour 処理に `saved updated computer transfer port` が記録され、今回追加したポート保存処理が Windows の実ポートにも適用された。

## 切り分け・残る確認

- iPad へのインストール後、最初の `devicectl` 起動は OS の `Guided Access active` で拒否された。アクセスガイドのセッション終了後は起動できた。端末が起動直後にバックグラウンドへ移ると、転送途中の接続は停止し、次のフォアグラウンド起動で再開した。
- 端末ログで転送と PC の確認応答、解析開始まで確認した。解析後の画面上の記録値を人の目で確認する試験、モバイル回線＋Tailscale の遠隔転送、Windows の初回 QR ペアリング、Developer Mode オフでの TestFlight 起動は今回の試験範囲外。
- PC 側は生ログを解析しない。転送の再現では `MacTransferDebugLogs` と各 PC の `DebugLogs` を日付で比較し、個体 ID やペアリング鍵を文書・ログの共有先へ書き出さない。
