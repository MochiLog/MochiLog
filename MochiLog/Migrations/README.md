# マイグレーション

通常の保存・検索処理には補正ロジックを置かず、このディレクトリから呼び出す。
iOS 16はCoreData、iOS 17以降はSwiftDataの実行経路を持つ。

```text
Migrations/
├── CoreDataMigrations.swift
├── SwiftDataMigrations.swift
├── Migration.swift
├── MigrationManager.swift
├── Migration_v1_iPhone16e_AvgTemp.swift
└── DeviceLibrary/
    ├── DeviceLibraryMigrations.swift
    ├── DeviceLibraryCoreDataMigrations.swift
    ├── DeviceLibrarySwiftDataMigrations.swift
    ├── Migration_v3_WatchSeries3Capacity.swift
    ├── Migration_v4_DeviceLibraryIdentity.swift
    └── Migration_v5_iPadReferenceCapacity.swift
```

## DeviceLibraryの補正

`DeviceLibrary/`に、機種ライブラリのデータ補正を版ごとに追加する。
共通の判定は永続化層から独立させ、CoreDataとSwiftDataのアダプターが利用する。
既存のv3もこのフォルダへ移した。処理内容・完了フラグは従来のまま。

`DeviceLibraryMigrations.runPending(in:)`を各ストアの初期マイグレーションから呼ぶ。
`repairIfNeeded(_:in:)`は読み出し時にも呼び、遅れたインポートや旧端末からの同期に対応する。
完了フラグだけで補正を止めず、補正前の値に一致するかで再実行を安全にする。
保存に失敗した場合はロールバックし、完了フラグを設定しない。
Macで動かすiOSアプリは既存の閲覧用方針に合わせ、データの補正書き込みを行わない。

## v4 機種ID・基板ID・SoC

2026-10-25の照合結果に基づき、標準ライブラリの機種名10項目・基板対応8項目・SoC2項目を修正した。
v4は容量を変更しない。容量については下記v5に分離する。
Duoの4883mAhへの修正は1062で適用済みで、マイグレーション対象外。

Watchの既存記録では、登録済みまたは選択した機種名が保存され、モデルコードはその名前の代表IDとして付与されていた。
この経路で付いた旧代表IDと保存名の組が一致する5パターンのみ、名前を保ったまま代表IDを更新する。
これでGPS/Cellularなどの実機構成を特定したことにはならない。
IDだけを根拠にSeries 8とSE第2世代を入れ替えず、非代表ID・不明な名前・不整合なOS名は自動補正しない。

基板から解決済みの古い内部IDだけでは、元の基板を復元できない。
`N66AP`などの基板文字列そのものが残り、標準設定と整合する場合のみ、確定した内部IDと機種名へ更新する。
基板の証拠がない既存のiPhone/iPad記録は推測で書き換えない。

SoCは記録に保存せず機種ライブラリから表示するため、標準ライブラリの修正だけで反映される。
ユーザーが保存した機種プロファイルと、その変更履歴に関係する記録は自動補正から除外する。
プロファイルの変更は従来の競合確認画面からユーザーが選択できる。
記録ID・個体ID・日時・容量・実測値・診断結果はv4では変更しない。

## v5 iPadの基準容量

Apple EUのProduct Information Sheetにある定格容量 `Crated [mAh]` を採用する。
元の公式資料と取得時点の値は `docs/audits/device-library-2026-10-25.json`、
現在値との照合は `docs/audits/device-library-combined-2026-10-25.json` に残す。

| 保存された機種名 | 旧基準 (mAh) | 新基準 (mAh) |
| --- | ---: | ---: |
| iPad Pro 13 (M5) | 10340 | 10209 |
| iPad Pro 13 (M4) | 10340 | 10209 |
| iPad Pro 11 (M5) | 8340 | 8160 |
| iPad Pro 11 (M4) | 8340 | 8160 |
| iPad mini (A17 Pro) | 5124 | 5034 |
| iPad (A16) | 7698 | 7606 |
| iPad Air 13 (M4) | 9705 | 9720 |
| iPad Air 13 (M3) | 9705 | 9720 |

保存名と旧基準容量が両方一致し、標準プロファイルである記録だけを補正する。
容量だけから機種を推測しない。Air 13 (M2)や旧世代miniなど、同容量の別機種は対象外。
手動プロファイルは変更前の名前・識別子の履歴も含めて保護する。
基準容量を更新した記録は、その基準から導く診断結果も再計算する。実測値がなければ既存の診断結果を保つ。
充放電回数・実測容量・公称容量・温度・電圧・日時・記録ID・個体IDは変更しない。
補正後の値は旧値に一致しないため、再実行や複数端末からの同期で元に戻らない。
旧値が後から同期・インポートされた場合も、共通入口から同じ補正を適用する。
CoreData・SwiftDataとも保存成功後のみ完了フラグを設定し、失敗時は補正をロールバックして次回再試行する。
データモデルの属性追加はなく、CloudKitスキーマの変更は不要。

## 検証

```sh
bash scripts/test-device-library.sh
bash scripts/test-device-profiles.sh
bash scripts/test-record-migrations.sh SIMULATOR_UDID
```

`Device library migration verification`ワークフローでも同じ検証を実行できる。
一時的なシミュレーターは終了後に削除し、ストアやTestFlightにはアップロードしない。
標準参照20項目、iPad容量8項目、手動プロファイル、再実行、旧同期データの再到着、実測値の保持、保存失敗時のロールバックを確認する。
