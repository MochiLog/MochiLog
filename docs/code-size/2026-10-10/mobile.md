# MochiLog（iPhone・iPad・Watch） コード規模

測定日時: 2026-10-10T23:42:19.045279+09:00。cloc 2.10。

リポジトリ: `MochiLog-mac-log-transfer` ／ ブランチ: `experiment/mac-log-transfer`

測定コミット: `4044a198c2a3dc5bc168d9d0bbc9227269bb97a6`

アプリ実装は **25,803行**、テスト・ツール・研究を含む管理対象ソースは **29,867行／195ファイル**。

## 用途別

| 用途 | ファイル | コード行 | コメント行 | 空行 | 全行 |
| --- | --- | --- | --- | --- | --- |
| アプリ実装・UI | 130 | 25,803 | 1,815 | 2,560 | 30,178 |
| テスト・試験補助 | 43 | 2,493 | 43 | 130 | 2,666 |
| ビルド・配信・開発ツール | 19 | 1,206 | 83 | 85 | 1,374 |
| 研究・プローブ | 3 | 365 | 14 | 7 | 386 |

## 言語別（実装・テスト・ツール・研究の合計）

| 言語 | ファイル | コード行 | コメント行 | 空行 |
| --- | --- | --- | --- | --- |
| Swift | 160 | 28,262 | 1,850 | 2,667 |
| Python | 11 | 811 | 64 | 80 |
| Ruby | 6 | 502 | 29 | 32 |
| Bourne Shell | 18 | 292 | 12 | 3 |

## 実装の構成

| 範囲 | ファイル | コード行 |
| --- | --- | --- |
| `MochiLog/Views` | 63 | 14,064 |
| `MochiLog/Services` | 37 | 7,930 |
| `MochiLog/Models` | 8 | 1,388 |
| `MochiLog/Utilities` | 6 | 854 |
| `MochiLog Watch App` | 6 | 700 |
| `MochiLog/App` | 1 | 280 |
| `MochiLog/Helpers` | 2 | 157 |
| `MochiLog/Migrations` | 3 | 147 |
| `Shared` | 2 | 131 |
| `MochiLogShareExtension` | 1 | 122 |
| `MochiLog/Debug` | 1 | 30 |

## 大きい実装ファイル（上位10件）

| ファイル | 言語 | コード行 |
| --- | --- | --- |
| `MochiLog/Services/MacTransferManager.swift` | Swift | 2,197 |
| `MochiLog/Views/Records/RecordViews.swift` | Swift | 1,057 |
| `MochiLog/Services/LocalDiagnosticsManager.swift` | Swift | 814 |
| `MochiLog/Views/Settings/SettingsView.swift` | Swift | 800 |
| `MochiLog/Views/Home/HomeView.swift` | Swift | 792 |
| `MochiLog/Models/DeviceLibrary.swift` | Swift | 786 |
| `MochiLog/Views/Home/HomeView+LogProcessing.swift` | Swift | 680 |
| `MochiLog/Views/Settings/MacTransferSettingsView.swift` | Swift | 670 |
| `MochiLog/Services/AppSettings.swift` | Swift | 592 |
| `MochiLog/Views/Home/RecordListView.swift` | Swift | 504 |

## 実装とは別に管理しているファイル

| 区分 | ファイル | 物理行数（テキストのみ） | 容量KiB |
| --- | --- | --- | --- |
| 翻訳リソース | 17 | 65,209 | 1,950.3 |
| 説明資料 | 56 | 2,572 | 331.4 |
| 設定・データ・その他テキスト | 61 | 38,694 | 1,894.6 |
| 画像・バイナリ | 26 | 0 | 23,143.1 |
| 外部由来・ライセンス・開発支援素材 | 55 | 5,034 | 649.8 |

## 集計方法

- Git管理下のファイルのみ。スマホは4.0.0の開発ブランチを1回だけ数え、mainとの二重計上をしない。iPhone／iPad／Duoで共用するコードも重複計上しない。Watchと共有拡張はスマホ版の内訳に含む。
- コード行数はclocによる空行・コメントを除いた行数。SwiftUI／XAML／CSSなどUI定義も含む。検証専用コードもソースとして数えるため、配布バイナリの構成とは一致しない。
- テスト、研究、ビルド・配信ツールは実装から分離。JSON／翻訳／設定／ドキュメントを実装行数へ足さない。ただしWebの翻訳がTSXに埋め込まれている部分はTypeScript行数に含む。
- 外部依存のダウンロード元、生成物、Build／DerivedData／node_modules、画像、実機ログは実装から除外。第三者ライブラリの内部規模は測定しない。取得してパッチするRustライブラリは含めず、リポジトリ内のパッチ用Pythonは開発ツールとして数える。
- 4リポジトリ合算では同じ内容のコピーも各リポジトリの保守対象として加算する。別途、完全一致するファイルだけを1回とした参考値も掲載。意味が似た移植コードは除去しない。
- 行数は複雑さ、品質、工数、バイナリ容量を示す指標ではない。文字列、データ定義、書式で増減する。
- この集計スクリプトと結果は対象外。コミットIDはレポート追加前の測定時点。

[全体集計](report.md) · [機械可読な集計・全ファイル内訳](metrics.json)
