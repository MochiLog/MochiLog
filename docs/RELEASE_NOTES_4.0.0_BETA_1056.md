# MochiLog 4.0.0 beta (1056)

## 日本語

- 複数PCとの連携で、1台の大量の過去デバッグログがほかのPCとの通信を待たせ続ける問題を改善しました。一定量を交換した後に次のPCを確認し、履歴は保存済み位置から続けます。
- 日付別デバッグログの交換で、通知された受信範囲を超えて読み込まないようにしました。過去のアプリ・PC版とも引き続き通信できます。
- 端末内取得で保存した記録のデバッグ情報に、取得経路と正しい個体IDを記録します。バッテリーの値や既存の記録IDは変更しません。
- 前回修正したiPadの端末内取得は、実機で当日ファイルの1回の取得から解析・日次停止まで進むことを確認しました。

## English

- When several computers are paired, a large diagnostic-history backlog on one computer no longer keeps the others waiting indefinitely. The app checks the next computer after a bounded exchange and later resumes history from saved offsets.
- Daily diagnostic-history transfers respect the advertised snapshot boundary while remaining compatible with previous app and companion versions.
- Import diagnostics identify on-device acquisition and its physical device identity. Battery measurements and existing record IDs are unchanged.
- The previous iPad checkpoint fix was verified on a real device: today's file was downloaded once, parsed, and counted toward the daily collection pause.
