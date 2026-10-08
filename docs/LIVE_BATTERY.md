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

通常の画面は、意味が確認できた容量・充放電回数・充電状態・外部電源・電圧・電流などを「項目／値」の表で表示する。存在する正しい型の項目だけを追加する。「詳細情報を表示」は初期状態では閉じており、推測が必要な内部値・不明なコード・IOReportのチャンネル情報などを元の名前と値で確認できる。未知の単位は推測しない。チャンネル名だけで現在の温度が得られたと扱わない。これらもメモリ内だけで扱い、履歴・サポートログには保存しない。

The normal view is a field/value table for understood readings such as capacity, cycle count, charging, external power, voltage and current. Additional rows require the exact known path and expected type. **Show detailed information** is collapsed by default and preserves uncertain internal values, unknown codes and channel metadata without guessing units or meanings. An IOReport channel name is not a live temperature reading. All fields stay in memory and are excluded from history and support logs.

PC側のPythonはpymobiledevice3による端末接続・API呼び出し・型を保持したplistの出力だけを担当する。検証・分類・ハッシュ・取得日時はSwift／C#へ移した。スマホへの暗号化形式と既存ペアリングは変更しない。詳細は各PCリポジトリの `docs/NATIVE_PYTHON_BOUNDARY.md` を参照。
