# 2026-10-11 端末内取得のチェックポイント調査

原本や個体IDは公開せず、検証用のコピーはgitignoreされたBuild内だけに置く。

## 発見

Macが受信したiPadの当日動作ログで、同じ当日Analyticsファイルのダウンロード開始が98回あった。収集の完了はsuccess=trueでも、保存済みチェックポイントの件数が0で日次停止へ進まなかった。開始イベントの回数だけから全98回の本文転送量を断定しない。

iPadのアプリコンテナを確認すると、該当ファイルは19,421,823バイト・30,200行で完全に保存されていた。iPhoneOSのヘッダーと3つのバッテリーマーカーがある。LocalDiagnosticsImportedには当日ファイルがなかった。

旧実装はURL.pathの文字数でファイルの相対名を切り出していた。URLの別名やディレクトリ表記が異なると、検証可能なHost/Watchトークンを復元できない。正規化したパス要素の包含比較へ変更し、チェックポイント検出と取り込みの両方で同じ関数を使う。受信したバッテリー値やログ解析方式、信頼・暗号化は変更しない。

## 検証

- `scripts/test-local-pairing.sh` 成功。異なる長さのパス別名、通常パス、WatchのProxiedDevice、ディレクトリ外への参照拒否、sessionファイル拒否を確認。従来のペアリング・進捗・日次ポリシーの試験も成功。
- 8言語とプレースホルダーの監査成功（15カタログ・1,445文字列）。ライセンス検査成功。Xcode 27.1でDebug実機ビルド成功。
- iPadを1055へ上書き更新し、20:26:08に `verified checkpoints queued for import; count=1` と `recovered 1 completed file checkpoint(s)` を確認。
- 同時刻に `automatic collection deferred; reason=dailyComplete, earliest=2026-10-12T09:00:00+09:00` を確認。更新後の取得済み一覧に当日トークンが加わった。
- 同じファイルの `parsed=true`、解析219ms、`result=success` と当日の日付を確認した。回復はキューに入れただけでなく、共通処理による解析・記録まで成功した。
- この実機のroot正規化ログはaliasesResolved=falseだった。旧URLのどの表記差が起きていたかまでは保存されていないため、実機の原因を `/var` と `/private/var` の差だけに限定しない。
- iPhoneへの1055の上書きインストールは成功。起動はOSからLockedで拒否されたため、今回のiPhoneの実機動作確認には数えない。

Mac・Windowsの調査と収集側の修正は、各PCリポジトリの同日メモへ記録した。
