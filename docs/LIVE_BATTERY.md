## 現在のバッテリー値（ベータ）

ペアリングしたiPhone・iPadの充放電回数、設計容量、最大容量などを、PCの概要画面で端末ごとに確認できます。スマホでも使う場合は **設定 → 高度な設定 → 現在のバッテリー** をオンにしてください。初期状態はオフです。既存のPCペアリングを使うため、この機能のための再ペアリングは不要です。

アプリを開いている間は定期的に取得し、変化した値だけを暗号化して送ります。最終取得日時を表示し、取得できない項目は空欄として扱います。接続できない場合は最後の値を過去の値として表示します。**今すぐ受信／送信**で手動更新もできます。スマホからのPC更新要求は、PCの取得完了後に次の受信で反映されます。

この表示は日次の解析ログとは別の現在値です。履歴・バッテリー記録・iCloudには保存しません。アプリ終了後は値を保持しません。診断項目の意味や取得可否はOS・機種で異なるため、日次ログと一致する保証はありません。ロック中に取得できた場合もありますが、長時間のロックや接続条件で取得できないことがあります。Apple Watchの現在値を測る機能ではありません。スマホ単体の手動ログ読み込みはこれまでどおり使えます。

スマホはMochiLog 4.0.0の新しいベータ、PCはMochiLog Mac 0.2.14／MochiLog Windows 0.1.11以降に更新してください。モバイル通信ではPC連携のモバイル通信設定とTailscaleによる接続が必要です。

## Current battery values (beta)

View cycle count, design capacity and other current capacity fields for each paired iPhone or iPad on the computer dashboard. On mobile, enable **Settings → Advanced Settings → Live Battery** to show the new tab. It is **off by default**. It uses your existing computer pairing; no new pairing is required.

Values refresh periodically while the app is open. Only changed values are sent, using encrypted transfer. The display includes the last acquisition time; unavailable fields remain empty, and a failed refresh leaves the previous values marked as outdated. Use **Receive Now / Send Now** for a manual update. A mobile request to refresh the computer appears on a subsequent receive after acquisition completes.

These are current diagnostic values, separate from daily Analytics files. They are not saved as history, battery records or iCloud data, and are discarded when the app exits. Available fields and their meaning depend on the device and OS; they may differ from daily Analytics values. A locked-device query has succeeded in testing, but long locks and connection conditions can prevent acquisition. This feature does not measure live Apple Watch battery values. Manual log import on mobile remains available without a computer.

Use the new MochiLog 4.0.0 beta with MochiLog Mac 0.2.14 or MochiLog Windows 0.1.11 or later. Cellular access requires the companion cellular setting and connectivity through Tailscale.

## 検証メモ

現在値はLiveBatteryManagerのセッション内だけで保持する。レコード保存、iCloud同期、サポートの診断ログには含めない。個体IDは既存のPCペアリングを使用する。合成データはDEBUG環境変数指定時だけで、配布版には入らない。暗号化TCP試験は合成サーバーとxctestrunのEnvironmentVariablesにMOCHI_LIVE_BATTERY_PORTを渡して実施する。未指定の場合はこの試験だけスキップする。
