# MochiLog 4.0.0 beta (1055)

## 日本語

端末内の自動取得で、保存済みの当日ログを認識できず、同じファイルを繰り返し取り直す問題を修正しました。ファイルのパスを正規化し、完全に保存できたログを共通の取り込み処理へ回復します。取得済みの当日ログを認識できるため、不要な再ダウンロードを抑え、翌日の取得まで待機できます。

中断・再起動後の回復でも、元の端末の個体ID、Apple Watchとの区別、既存の重複防止を維持します。保存完了と取り込みへの回復を動作ログに記録し、取得できたのに記録へ進まない場合も調べやすくしました。

Mac 0.2.27／Windows 0.1.25では、新しいログを先に取得し、読めないファイルの連続再試行を抑える修正を追加しています。Windowsの現在値取得の一時エラーも修正しました。既存のPCペアリングをやり直す必要はありません。

## English

Fixed repeated downloads in on-device automatic collection when a fully saved report for the current day was not recognized. Saved file paths are normalized before complete reports are recovered through the shared import queue. Recognizing an already acquired daily report avoids unnecessary downloads and allows collection to wait until the next day's window.

Recovery after interruption or restart preserves the original device identity, separates Apple Watch reports and retains existing duplicate prevention. Activity logs now record completed file checkpoints and recovery into the import queue, making acquisition-to-import problems easier to investigate.

Mac 0.2.27 and Windows 0.1.25 prioritize newer reports and schedule retries for unreadable files. Windows also fixes a transient current-battery response error. Existing PC pairings remain valid; no re-pairing is required.
