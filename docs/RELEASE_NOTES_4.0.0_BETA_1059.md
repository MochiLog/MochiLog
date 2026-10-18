# MochiLog 4.0.0 beta (1059)

## 日本語

MochiLog 4.0.0 ベータ (1059)

内部コードの読みやすさと保守性を整えたメンテナンス版です。Swiftの字下げや長い条件式・引数の改行を統一し、今後の修正を確認しやすくしました。整形前後の構文を比較し、取り込み、記録削除、個体ID、PC連携、複数端末共有、Watch記録の互換性などの既存テストを確認しています。iPhone実機で更新と起動を確認しました。

1058のホームの複数選択・削除を引き続き利用できます。「選択」から対象を選び、件数を確認して削除してください。削除直前に記録IDと内容を再確認し、別端末で変更された記録を誤って削除しない仕組みを維持しています。iCloud同期が有効な場合、削除は同期先にも反映されます。

PC連携・端末内取得・現在のバッテリー表示を含む4.0.0のベータ機能を引き続き利用できます。既存の記録とペアリングを引き継ぎ、今回の更新のための再ペアリングは不要です。Mac版は0.2.34も配布します。日次解析ログを取得するときは、端末のロックを解除してください。

## English

MochiLog 4.0.0 beta (1059)

This maintenance build improves the readability and consistency of the internal source code. Swift indentation, long conditions and argument lists now follow consistent formatting, making future changes easier to review. Source syntax was compared before and after formatting. Existing tests covered importing, record deletion, physical device identity, PC pairing, multi-device sharing and Watch-record compatibility. Installation and launch were verified on a physical iPhone.

The Home multi-select and deletion feature from 1058 remains available. Tap Select, choose records and confirm the count before deleting. Record IDs and contents are checked again before deletion to protect records changed on another device. With iCloud sync enabled, deletion also applies to synced devices.

The 4.0.0 beta features, including PC pairing, on-device collection and current battery information, remain available. Existing records and pairings are retained; this update does not require pairing again. Mac 0.2.34 is also being distributed. Unlock the device when collecting daily Analytics logs.
