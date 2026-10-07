日本語

現在のバッテリー表示を拡張しました。充放電回数や容量のカードに加え、「APIの全項目」から製造情報、状態フラグ、バッテリー識別情報など、診断APIが返す全項目を分類して表示できます。大きな整数も丸めず、バイナリ情報はBase64で表示します。項目の単位や意味は推測しません。

現在値はメモリ内のみで扱い、履歴・バッテリー記録・iCloud・サポートログには保存しません。既存ペアリングの暗号化通信を利用し、主要項目と詳細項目それぞれの変化を検出して変更がない値は再送しません。旧版の主要項目表示も引き続き使えます。

Tailscale経由の現在値受信に対応し、PC連携のモバイル通信許可を尊重します。PCから端末への診断問い合わせは、MacとWindowsの双方でTailscale接続のiPadに成功しました。ただし端末の診断サービスへの接続可否に依存し、モバイル回線・長時間ロック・全機種での取得を保証しません。取得できない場合は以前の値と最終取得日時を示します。日次Analyticsファイルのロック中取得とは別の機能です。

English

Live Battery now displays all fields returned by the diagnostics battery API, grouped under All API fields, alongside the main cycle-count and capacity cards. Manufacturing metadata, battery identifiers and flags are retained. Large integers keep their precision; binary data is shown as Base64. Units and field meanings are not guessed.

Values remain in memory only and are never saved to history, records, iCloud or support logs. Existing encrypted pairings are preserved. Core and full-detail revisions are tracked independently; unchanged values are not resent. Older clients can still use core fields.

Current-value reception supports Tailscale routes and respects the mobile PC Link cellular permission. Fresh acquisition from an iPad over Tailscale succeeded from both Mac and Windows. Availability still depends on the device diagnostics service; cellular-radio operation, long locks and every model are not guaranteed. Failed refreshes retain previous values and acquisition time. This does not enable locked daily Analytics-file acquisition.
