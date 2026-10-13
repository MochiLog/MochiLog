# MochiLog 4.0.0 beta (1058)

## 日本語

MochiLog 4.0.0 ベータ (1058)

ホームにバッテリー記録の複数選択・削除を追加しました。「選択」を押して記録にチェックを付け、画面下の削除ボタンから件数を確認して削除できます。全選択・選択解除・キャンセルに対応し、iPhoneとiPadの両レイアウト、8言語で利用できます。サンプル表示中には削除しません。

確認画面を開いた時の記録IDと内容を保持し、削除直前に再確認します。別端末で変更・削除された記録を別の記録で置き換えて削除することはありません。保存失敗時は変更を戻してエラーを表示します。iCloud同期が有効な場合、削除は同期先端末にも反映されます。削除は取り消せないため、残したい記録を選択していないか確認してください。

1057のPC連携改善も含みます。現在のLANアドレスを既存の暗号化通信内で知らせ、転送元IPとApple診断先が異なる場合に正しい候補を試します。対応PC版はMac 0.2.29／Windows 0.1.27です。再ペアリングは不要で、旧版との通信も維持します。PCの取得失敗・再試行待ちを完了扱いにしない判定も引き続き利用できます。収集には端末のロック解除が必要です。

## English

MochiLog 4.0.0 beta (1058)

Home now supports selecting and deleting multiple battery records. Tap Select, check the records, then use Delete at the bottom and confirm the count. Select all, deselect all and cancellation are supported on iPhone and iPad in all eight languages. Sample records cannot be deleted.

Confirmation captures the selected record IDs and contents. They are checked again immediately before deletion, so a record changed or deleted on another device is never replaced with a different record as a deletion target. Failed saves are rolled back and reported. With iCloud sync enabled, deletion also applies to synced devices. Deletion cannot be undone, so check that records you want to keep are not selected.

This build includes the PC pairing improvements from 1057. Current LAN address hints are sent inside the existing encrypted request, allowing updated companions to try the right Apple diagnostic endpoint when it differs from the transfer peer address. Use Mac 0.2.29 or Windows 0.1.27. Existing pairings and older-version communication remain supported. Companions distinguish failed downloads and retry waiting from completed acquisition. Log collection still requires the device to be unlocked.
