# MochiLog 4.0.0 (1053) Beta

エラーログ画面を改修しました。エラーメッセージで検索でき、日付別に一覧を表示します。iPadの広い画面では一覧と詳細を並べ、設定内の戻る操作も維持します。大量のログはバックグラウンドで読み込み、ページを切り替えて確認できます。全文コピーとファイル共有は維持しています。

端末と受信したPCの動作ログも、日付と機能別に探せるようにしました。画面を開くだけでは通信を開始せず、更新ボタンは保存済みログを読み直します。読み込み中・失敗時の表示を追加し、画面更新のたびに巨大なファイルを読み直す処理を廃止しました。追加した画面と文言は8言語に対応しています。

Mac・Windows版にも同じ読み込み負荷対策を適用しました。このビルドには以前の端末取り違え修正と共有・重複防止の修正も含まれます。

Redesigned the error-log viewer with message search and a list grouped by date. On wider iPad screens, the list and details appear side by side within Settings. Large logs load in the background and can be viewed page by page. Full-text copying and file sharing remain available.

Activity logs from this device and paired computers can be browsed by date and feature. Opening the viewer does not start a transfer; Refresh reloads saved logs. Loading and failure states are shown, and large files are no longer reread on every screen update. New controls and text support all eight app languages.

The same loading improvements are available in the Mac and Windows companions. This build also retains the earlier fixes for source-device identification, sharing and duplicate prevention.
