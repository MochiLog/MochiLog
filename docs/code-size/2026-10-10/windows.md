# MochiLog Windows コード規模

測定日時: 2026-10-10T23:42:19.045279+09:00。cloc 2.10。

リポジトリ: `MochiLog-Windows` ／ ブランチ: `main`

測定コミット: `607aa25543803b45f67d0f7a27b333c2dd197aca`

アプリ実装は **5,535行**、テスト・ツール・研究を含む管理対象ソースは **6,838行／51ファイル**。

## 用途別

| 用途 | ファイル | コード行 | コメント行 | 空行 | 全行 |
| --- | --- | --- | --- | --- | --- |
| アプリ実装・UI | 41 | 5,535 | 109 | 350 | 5,994 |
| テスト・試験補助 | 5 | 1,067 | 3 | 31 | 1,101 |
| ビルド・配信・開発ツール | 5 | 236 | 5 | 20 | 261 |
| 研究・プローブ | 0 | 0 | 0 | 0 | 0 |

## 言語別（実装・テスト・ツール・研究の合計）

| 言語 | ファイル | コード行 | コメント行 | 空行 |
| --- | --- | --- | --- | --- |
| C# | 32 | 5,655 | 79 | 312 |
| XAML | 8 | 592 | 1 | 13 |
| Python | 8 | 459 | 37 | 64 |
| PowerShell | 2 | 75 | 0 | 5 |
| Inno Setup | 1 | 57 | 0 | 7 |

## 実装の構成

| 範囲 | ファイル | コード行 |
| --- | --- | --- |
| `src/MochiLog.Windows/Services` | 22 | 3,548 |
| `src/MochiLog.Windows/Pages` | 12 | 1,437 |
| `WinUIアプリ直下` | 4 | 331 |
| `収集用Python` | 3 | 219 |

## 大きい実装ファイル（上位10件）

| ファイル | 言語 | コード行 |
| --- | --- | --- |
| `src/MochiLog.Windows/Services/TransferServer.cs` | C# | 807 |
| `src/MochiLog.Windows/Services/Collector.cs` | C# | 596 |
| `src/MochiLog.Windows/Services/CompanionRuntime.cs` | C# | 539 |
| `src/MochiLog.Windows/Pages/HomePage.xaml.cs` | C# | 351 |
| `src/MochiLog.Windows/Pages/SettingsPage.xaml.cs` | C# | 291 |
| `src/MochiLog.Windows/Pages/HomePage.xaml` | XAML | 255 |
| `src/MochiLog.Windows/Services/BatteryLogStorage.cs` | C# | 247 |
| `src/MochiLog.Windows/Services/LiveBattery.cs` | C# | 225 |
| `src/MochiLog.Windows/Services/DebugArchiveSync.cs` | C# | 174 |
| `src/MochiLog.Windows/MainWindow.xaml.cs` | C# | 171 |

## 実装とは別に管理しているファイル

| 区分 | ファイル | 物理行数（テキストのみ） | 容量KiB |
| --- | --- | --- | --- |
| 翻訳リソース | 2 | 15,740 | 518.4 |
| 説明資料 | 30 | 774 | 106.5 |
| 設定・データ・その他テキスト | 12 | 575 | 17.1 |
| 画像・バイナリ | 10 | 0 | 404.6 |
| 外部由来・ライセンス・開発支援素材 | 7 | 2,657 | 138.0 |

## 集計方法

- Git管理下のファイルのみ。スマホは4.0.0の開発ブランチを1回だけ数え、mainとの二重計上をしない。iPhone／iPad／Duoで共用するコードも重複計上しない。Watchと共有拡張はスマホ版の内訳に含む。
- コード行数はclocによる空行・コメントを除いた行数。SwiftUI／XAML／CSSなどUI定義も含む。検証専用コードもソースとして数えるため、配布バイナリの構成とは一致しない。
- テスト、研究、ビルド・配信ツールは実装から分離。JSON／翻訳／設定／ドキュメントを実装行数へ足さない。ただしWebの翻訳がTSXに埋め込まれている部分はTypeScript行数に含む。
- 外部依存のダウンロード元、生成物、Build／DerivedData／node_modules、画像、実機ログは実装から除外。第三者ライブラリの内部規模は測定しない。取得してパッチするRustライブラリは含めず、リポジトリ内のパッチ用Pythonは開発ツールとして数える。
- 4リポジトリ合算では同じ内容のコピーも各リポジトリの保守対象として加算する。別途、完全一致するファイルだけを1回とした参考値も掲載。意味が似た移植コードは除去しない。
- 行数は複雑さ、品質、工数、バイナリ容量を示す指標ではない。文字列、データ定義、書式で増減する。
- この集計スクリプトと結果は対象外。コミットIDはレポート追加前の測定時点。

[全体集計](report.md) · [機械可読な集計・全ファイル内訳](metrics.json)
