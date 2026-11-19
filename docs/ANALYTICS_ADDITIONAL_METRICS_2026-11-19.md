# Analyticsから追加取得できる情報と生成元の調査

2026-11-19。既存項目の意味の監査は[別台帳](BATTERY_FIELD_SEMANTICS_2026-11-19.md)。
この資料は追加機能の実装ではなく、保存済みログにある情報とIPSW内の生成処理を照合した記録。

## 調査対象と数え方

AppleのiPhone14,4 / 27.2 (24B119) のCoreAnalytics設定とPowerlogLiteOperatorsを解析した。
ファームウェアのハッシュ・URL・ツール版は[最初の調査](ANALYTICS_GENERATION_2026-11-19.md)にある。
手元の実ファイルはiPhone30件・iPad31件・Watch30件の計91件。
iPhone／iPadは27.0.1、Watchは27.2で、うち6件はベータビルド。
**27.2のiPhone実機で全候補を再現した結果ではない。**

この標本は主にPCが保管済みの正常ログであり、OSが作った全ファイルではない。
出現率は一般ユーザーへの普及率・取得成功率を意味しない。
同じ端末の複数日分なので、91台の独立した標本でもない。

91ファイルには合計2,042種類のイベント名があり、電池・充電・温度・電力・画面・ストレージ等の
キーワードで201種類を抽出した。設定側では同じ広い条件に795定義が一致したが、
アプリ別・周辺機器別の値も含むため「新しい便利機能が795個ある」とは数えない。
有望な16定義のフィールド名・型・演算・バケット境界・出現数を
[追加項目カタログ](research/additional-metrics-catalog-27.2.json)に保存した。
原本・端末ID・各端末の測定値はGitへ入れていない。

## 有望な候補

| 情報 | イベント名 | 出現ファイル数 | 何ができそうか／未確定事項 |
| --- | --- | ---: | --- |
| 非充電中の時間・使用量 | UnpluggedDurationEnergyViewNew | 87/91 | 非充電でどのくらい使ったか。Energyは電力量Whとは限らず、生成式の確認が重要 |
| 高残量域の滞在 | BatteryTimeAtHighSocLast | 78/91 | 高残量で長く保管・利用する傾向。binの境界、単位、リセットは未確定 |
| 充電が遅い理由のコード | SlowChargingReason | 78/91 | 充電状態の診断補助。コード表が未確定で、現時点では具体的な原因名を表示できない |
| 時間帯別の残量・充電・温度 | intervalUsageChargingParamsHistogramView_withTimeInterval | 30/91、全てWatch | 時間帯ごとの充電・温度の可視化候補。最後の値であり、全サンプルや区間平均ではない |
| 温度×残量の滞在分布 | BatteryHeatmapSoCAggregationViewCorrected | 28/91、全てWatch | どの残量帯・温度帯で過ごしたか。ビン境界とカウンター期間が未確定 |
| シャットダウン前後の電池情報 | BatteryShutdownHistogramDailyTotal | 12/91 | 電圧・残量・容量等の診断補助。イベント件数を突然のシャットダウン回数としない |
| 充電最適化関連 | JITCharging_aggregated_metrics_with_trial | 20/91 | 最適化処理の時間・判断の手掛かり。内部モデルの評価値で、充電の成功率と断定不可 |
| 充電最適化の生涯統計 | OBCNoRotationBatteryHealthMetricsv2 | 13/91 | LifetimeEngagements、LifetimeIdleDurationMins等。日次の実行回数ではない |
| 低電圧滞在・電池接続 | Battery_LowVoltageResidencyCountersLastValue / BatteryCellDisconnectCount_Last_Value_Of_Day | 各25/91 | 継続観察候補。Last_Value_Of_Dayは日次増分という意味ではない |
| 温度・電力・通信・稼働・NAND | 下記の補助候補 | 主にWatchの一部 | 単位・コホート・集計方法の解明が先。寿命%やアプリ別消費量へ即変換しない |

## 非充電中の時間・使用量

設定の入力は`com.apple.power.state.t_unplugged`。

| 出力 | 演算 | 読み方 |
| --- | --- | --- |
| daily_total_Duration | sum(Duration) | 送信された各Durationの合計。元の区間と日境界を別に確認する |
| daily_total_Energy | sum(Energy) | 名前からWh／mWhと決めない |
| daily_total_unplugged_count | sum(unplugged_count) | 元のイベントのカウント値を合計。Countとは別 |
| Count | count | 入力イベントの件数 |

生成元は`-[PLAggregateDictionaryService updateAggregateStateWithEntry:]`、`0x29f94b230`。
`RawLevel`、`AdapterInfo`、前回状態、前回時刻等を読み、状態変化・残量差に応じて送信する。
電源未接続中の残量差が一定量を超える場合と、接続状態の遷移で処理する分岐があり、単純な1秒タイマーではない。
ただしAdapterInfoの全コードや外部状態の更新条件までは未解明。

確認した計算経路:

1. `0x29f94b2f0–0x29f94b2f4`で前のRawLevelと現在値の差を取る。
2. `0x29f94b370`で時刻らしい値の差を取る。
3. `0x29f94b374–0x29f94b3b0`でNominalChargeCapacityを優先し、欠ければAppleRawMaxCapacityを読む。
4. `0x29f94b3c0–0x29f94b3d0`は **残量差÷100×容量値**。電圧はこの式に入っていない。
5. 小数の端数を持ち越す処理を経て、`0x29f94b4d4`で使用量と時間をイベントブロックへ渡す。
6. `0x29fddd8c8`のブロックが、その2値をEnergy／Durationとして辞書にする。

従ってEnergyは、この経路では残量差と容量に基づく電荷量相当の推定である。
容量の単位がmAhなら結果もmAh相当になるという**次元上の解釈**はできるが、
全モデルのスケールを検証するまではWh換算・高精度な積算計測として表示しない。
Durationも時刻差から来る証拠はあるが、呼び出し先の時刻基準・単位は追加確認が必要。
標本にはDurationが86,400を超えるものもあり、「その暦日の秒数」と決めて丸めたり上限を切らない。

## 時間帯別の充電・温度

生成元は`-[PLIntervalData submitToCA:]`（`0x29fc1aae4`）、充電パラメーターのブロックは
`0x29fc1ad58`。`PLAggregateUsageService`が状態変更やサンプル更新を扱う。

- `TimeInterval`に96通りの15分刻みの値が実在した。例は0、15、30、45、100…2345。
- `-[PLIntervalData init]`の`0x29fc1a458–0x29fc1a488`で**`HHmm`と`en_US`**を設定している。
  `TimeInterval=100`は100分という意味ではない。
- タイムゾーンの明示設定・変更時の処理・区間の開始／終了ラベルの厳密な対応は未確定。
  ファイルのUTC日付と、そのまま同じ基準の時刻としてつなげない。
- BatteryLevel、AdapterType、ChargingState、ConnectedState、TimeIntervalがdimensions。
  温度・充電器電流・充電器電圧は`last`で、平均ではない。
- `updateSampledMetrics`（`0x29fc1d554`）にChargerCurrent／ChargerVoltageの更新経路がある。
  値の元の単位・測定点と、全機種での温度変換は追加確認が必要。
- 同じ時間帯でも充電状態等の違う複数行が成立する。行順を1秒間隔と見なしたり、
  順序を復元したつもりで線を結んだり、勝手に平均しない。

この候補は「時間帯別に残ったサンプル」の図には使えそうだが、
**1秒ごとの一日分の温度履歴を完全復元できる証拠ではない**。
この標本での実在はWatchだけで、iPhone／iPadへの提供は未確認。

## 温度×残量のヒートマップ

`-[PLBatteryAgent logEventBackwardHeatMap]`は`IOPMCopyBatteryHeatMap`を呼び、
`logEventBackwardHeatMapCallback:andHeatMapType:`（`0x29fcb5b00`）がデータを列挙する。

| フィールド | 確認内容 |
| --- | --- |
| action | テーブル`0x2d0b80960`で0=charging_a、1=charging_b、2=dischargingに対応。charging_a/bの区別条件は未解明 |
| SoC | 25個の配列要素を列挙するビン番号。24を24%と読まない。端点・幅は未確定 |
| temperature | 元の温度側キー／ビンを使う。番号8を8°Cと読まない。実温度への境界は未確定 |
| timeSpent | `sum`対象。イベントブロック`0x29fcb60d4`で元の整数をそのまま渡す |
| version | この経路は1を付ける。将来の形式差を無視しない |

元の整数x26は`0x29fcb5e7c–0x29fcb5ea0`で**TimeInMinutes**にも格納され、
`0x29fcb5f1c`から同じ整数がブロックのtimeSpentへ渡る。分単位という強い手掛かりで、
イベント側に×60する処理はない。ただしカウンターの起点・リセット・取得差分か累積かは未確定。
Dailyファイルにあるsumを「当日中にその温度で過ごした分数」と直ちに解釈しない。
時間順の履歴ではなく、条件ごとの滞在分布という構造。

## 高残量滞在と遅い充電の理由

`parseTimeAtHighSoc:`（`0x29fcb9068`）はバイト列を4バイト整数ごとに読み、bin番号と値を作る。
`pushTimeAtHighSocToCA:`から`com.apple.power.battery.TimeAtHighSoc`へ送る。
Analyticsはbinごとに最後のvalueを保持する。標本にはbin 0〜9があるが、
**10%刻み・80%以上・分単位等の対応は未確定**。項目名だけで説明を埋めない。

`logSlowChargingReasonToCA:`（`0x29fcbbf44`）は`ChargerData.SlowChargingReason`を読む。
ChargerDataまたはキーがなければ送信しない。値が数値の0であることと、オブジェクトの欠損は別。
実ファイルには0・8・16があるが、ビットフラグか列挙値か、8や16の原因名は未確定。
「温度が高い」「充電器が弱い」といった説明は対応表を確認してからにする。

## その他の候補と誤解しやすい点

| 群 | 取得候補 | そのまま表示できない理由 |
| --- | --- | --- |
| シャットダウン | ShutdownSoc、ShutdownVoltage、VoltagePrevious、RemainingCapacity等 | 定義のdaily_total_UPOCountは標本の非null項目にない。12ファイル全てで突然の終了が起きたとは証明できない。Countを障害回数にしない |
| 充電最適化 | JITのIdleDuration／PluginDuration／UnderCharged系、OBCのLifetime系 | 内部の判断・モデル評価とユーザーの実際の充電体験を分ける。TrackingID等は公開レポートへ入れない |
| 温度 | SMCThermalKeys_90DayRotation、thermalKeys_TH0x | bucketedは生温度ではない。入力の境界配列は台帳に残したが、センサー位置と単位は別問題。90DayRotationという名前は集計期間ではない |
| 通信と放電 | BatteryLevelReportView5の残量、接続、電波強度、screenOn等 | 信号と消費の関連を調べる候補。電波が原因・どのアプリが原因という因果推定には不足 |
| 稼働 | CPUAndWallUptime | どちらもbucketed値。ビン番号を時間として表示しない。電池のTotalOperatingTimeとも別 |
| 電力 | EnergyTelemetrySummary_v3 | エネルギーらしい名前でも元の単位・窓を確認する。全端末の実測電力量ではない |
| NAND | massStorage_NANDInfo_FTLCounters_1、476 measures | 書き込み・消去等の内部カウンター。sumが差分か積算値の足し算かで意味が変わる。SSD寿命%・総書込TBへ即変換できない |
| メモリ | Jetsam関連のイベント | メモリ圧迫による終了と、アプリの例外クラッシュを区別する。アプリのクラッシュ率にはしない |

一部の定義には、端末単位の安定した乱数で`<10`とするenableIfがある。
対応機種・OSでも対象集団に入らず出ない場合を考慮する。条件のない定義も、入力がなければ出ない。
入力条件、ファイル側の集計期間、フィールドの統計期間、対象コホートの4つを別々に記録する。

## 次に確定させること

優先度が高いのは、非充電使用量の単位・日境界、時間帯温度の時刻基準・変換、
ヒートマップのビン境界・カウンターの起点。コード表が解明できていない理由コードや安全イベントは
詳細表示向けの元名を保ち、原因名の断定や健康度の計算へ使わない。

現在値APIで既に渡している生の詳細情報と、日次ファイルから新規に取れる情報を区別する。
今回の候補を追加しただけで、既存のリアルタイムAPIの取得項目が増えたという説明にしない。

## カタログの再生成

```sh
python3 scripts/research/catalog-additional-metrics.py /path/to/CoreAnalyticsConfig/defaultConfig.json \
  --observations /private/path/to/private-observed-inventory.json \
  --firmware 'iPhone14,4 / 27.2 / 24B119' \
  --output docs/research/additional-metrics-catalog-27.2.json
```

observationsは今回の91件を走査した非公開の中間台帳。出力するのは定義・項目名・非null行数だけ。
中間台帳の数値範囲・端末グループ・原本パス・実測値を転記しないことを合成入力のテストでも確認した。
出力は16定義・計653フィールド定義（同名の別定義を含む）。476項目あるNANDのように、
存在と型・集計方法を記録しただけで、意味や単位が未確定のものを含む。
