# 追加バッテリー項目8候補の生成経路・解釈監査

2026-11-19。[前段の候補調査](ANALYTICS_ADDITIONAL_METRICS_2026-11-19.md)から、
8候補についてOSの生成側・利用側・集計設定まで追加追跡した結果。
アプリの解析処理や表示、配布ビルドは変更していない。

## 結論と確度

「生成元まで追えた」と「全機種で意味・起点が確定した」は区別する。
以下の確定は解析した **iPhone14,4 / 27.2 (24B119)** の経路に対するもの。
実ログは従来と同じ91件で、iPhone30件・iPad31件は27.0.1、Watch30件は27.2。
Watch専用のバイナリを解析した結果ではなく、iPhoneの式・ビン表をWatchへ無条件に適用できない。
保存済みの正常ログを中心にした標本なので、出現数は一般的な取得成功率ではない。

| 候補 | 今回確定したこと | 残った境界／利用判定 |
| --- | --- | --- |
| 1. 非充電時間・使用量 | Unix秒の差、残量差×容量、送信条件、端数持ち越し | 日境界で分割されない。Wh・その日だけの稼働時間として表示しない |
| 2. 高残量滞在 | LifetimeDataの可変長u32列、bin別last、SMCのBLTP経路、Apple内部の重み付き利用 | 各binの残量／温度境界、時間スケール、初期化条件は未確定。番号・元値を詳細表示する範囲 |
| 3. 遅い充電の理由 | SMCのCHSW由来。Appleの温度制限判定がbit 0/3を検査 | 8は温度制限判定に該当。16の原因名と全ビット表は未確定 |
| 4. 時間帯別残量・温度 | 既定900秒、HHmm、現在の保存済み電池値、Temperature÷100後の整数化、欠損用既定値 | 実在はWatchのみ。1秒履歴・区間平均ではない。時差／DSTの完全復元不可 |
| 5. 温度×残量分布 | 12×25のビン表、分単位の値、SMC読出し→ゼロ化→OS保管庫へ加算 | APIは保管済み累計を返す。Analyticsのsumを当日の分数に変換不可 |
| 6. シャットダウン診断 | 電池パック別の過去状態、時刻による重複抑止、DataErrorとUISOCによるUPOCount条件 | Countはクラッシュ回数ではない。独自フラグやRa/DLOGの物理仕様は未確定 |
| 7. 充電最適化 | PowerUIの充電セッション由来、Durationは秒、Engaged判定、OS設定保存のLifetime累計 | モデル評価と実測を分ける。Lifetimeは電池製造以来を保証しない |
| 8. 低電圧滞在・電池接続 | 27カウンターの0.01秒単位、3V未満の選択マスク、Analyticsへの2有効数字化。電池接続は累計値 | 全27binの境界、機種共通性、ハード側初期化条件は未確定。負数／番兵値を時間にしない |

定義・アドレス・ラベル・残課題は[機械可読台帳](research/analytics-candidate-evidence-27.2.json)にも保存した。
「未確定」は未調査という意味ではなく、その欄に記した上流の仕様・機種差まで今回の資料で証明できなかった部分。

## 1. 非充電中の時間・使用量

`-[PLAggregateDictionaryService updateAggregateStateWithEntry:]`（0x29f94b230）から
`com.apple.power.state.t_unplugged`へ送る。

| 項目 | 生成処理 |
| --- | --- |
| RawLevel | `AppleRawCurrentCapacity / AppleRawMaxCapacity × 100`。最大容量が欠損／0なら作れない（0x29f9735c0） |
| 接続状態 | `AdapterInfo`の数値が0か非0か。IsChargingや画面オンとは別の判定 |
| Duration | `entryDate.timeIntervalSince1970`の差。**秒**（0x29f94b2b4–2c0、370） |
| Energy | `(前RawLevel − 今RawLevel) / 100 × 容量`。NominalChargeCapacityを優先し、なければAppleRawMaxCapacity |
| unplugged_count | 未接続→接続の遷移で1を加える。充電サイクル数ではない |
| Count | CoreAnalyticsへ届いたイベントの件数。上記カウンターとは別 |

前状態が未設定の最初の更新は基準を置く。未接続が続く場合、RawLevelの差の絶対値が1を超えると送信する。
差が小さい間は基準を維持し、未接続→接続でも区間を送る。単純な1秒間隔の積算ではない。
`modfl`で整数と小数を分け、端数を持ち越す。通常の四捨五入とは異なり、保持端数の絶対値が
**1を超えた**ときに整数部を繰り上げる分岐もある。

電圧を掛けていないのでWhではない。容量のスケールがmAhならmAh相当の推定電荷量であり、
電流センサーを積分した実測電力量ではない。残量補正でRawLevelが増えた場合、差の符号は負になり得る。
絶対値に直して常に消費と扱わない。

この生成関数に0時で区間を切る処理はない。日をまたいでから送られた区間は、到着側の集計窓に入る。
Durationが86,400を超えても、それだけで破損と判断できない。
最初の基準より前の時間・停止中の未観測分を完全復元する機構ではない。

## 2. 高残量域の滞在

`BatteryData.LifetimeData.TimeAtHighSoc` → `parseTimeAtHighSoc:`（0x29fcb9068）
→ `com.apple.power.battery.TimeAtHighSoc` → `BatteryTimeAtHighSocLast`。
データ長÷4個のlittle-endian u32を読む。10個に固定しておらず、余りの1〜3バイトはループ対象外。
CoreAnalyticsはbinごとの**最後の値**を保持する。

AppleSmartBatteryManagerEmbeddedでは同名キーのSMC記述子が`BLTP`を指す。
汎用SMC読み取り側にもBLTPの長いデータを扱う分岐があり、4バイト単位の列をOSが時間に変換しているわけではない。

別の利用側も確認した。BatteryAlgorithmsの
`BACore::CommonSerialization::convertTeqIntoScalar(NSData*, const double*, double)`
（0x25a0747d4）は、各4バイト値と**呼出元から渡された係数**を掛けて合計し、
さらに呼出元のスケールで割る。ここはsigned int32として読む。
つまりApple内部にも、単にbin番号×10を残量%とする処理の根拠はない。

[Apple公開メタデータ](https://github.com/apple-oss-distributions/PowerManagement/blob/d415e45501842834a280930c3eed9186544a67f0/pmconfigd/Resources/com.apple.bdc.metadata.plist)
のTimeAtHighSocのunit.symbolも空欄で、時間単位は規定されていない。
BDC_Dailyという保存カテゴリ名を日次増分や秒の根拠にしない。

**終点:** 取得・バイト配列・集計・内部利用式までは確認できたが、係数の物理的な意味、
各ゲージのbin表、製造／交換／校正／更新時の初期化条件は未確定。
「80%以上で○時間」への変換にはまだ使えない。

## 3. 遅い充電の理由

`ChargerData.SlowChargingReason` → `logSlowChargingReasonToCA:`（0x29fcbbf44）
→ `SlowChargingReason.slow_charging_reason`。数値0も送信でき、欠損とは区別される。
カーネルのSMC記述子では`CHSW`（0xfffffff0077199c0）から読み取る。

**名前だけの推測ではなく、Apple自身の利用コードが見つかった。**
ComputeSafeguardsの`-[CSPowerlogDBReader isThermalLimitedCharging:]`（0x23fc1ca98）は、
外部電源接続中に、NotChargingReasonによる別の条件判定に続いてSlowChargingReasonの
64ビットを走査し、**bit 0またはbit 3が立っていれば温度制限あり**を返す。

| 値 | 今回いえること |
| --- | --- |
| 0 | このSlowChargingReasonによる温度制限ビットは立っていない。全ての充電条件が正常という意味ではない |
| 1 / 8 / 9、その他の組合せ | bit 0/3が含まれるので、外部接続中ならこのAppleの温度制限判定に該当 |
| 16 | bit 4。今回の温度制限チェックには該当しないが、具体的な原因名は判別できない |

8を「弱い充電器」と呼ぶ根拠はなく、Appleの判定は温度制限側だった。
ただしbit 0と3それぞれの部品・高温／低温の区別までは証明していない。
Countはそのコードの入力件数であり、遅い充電の回数・分数ではない。

## 4. 時間帯別の残量・充電・温度

`PLAggregateUsageService` → `PLIntervalData` →
`intervalUsageChargingParamsHistogramView_withTimeInterval`。
`+[PLAggregateUsageService defaults]`（0x29fc1b0b0）のIntervalDurationは**900秒**。
設定取得経路を通るので、全機種・全設定で15分固定というAPI仕様にはしない。

| フィールド | 取得元・意味 |
| --- | --- |
| TimeInterval | NSDateFormatterの`HHmm`を整数化。100は01:00、2345は23:45 |
| BatteryLevel | 最後のPLBatteryAgent電池エントリーのLevel |
| BatteryTemperature | 同エントリーのTemperatureをintValue。元のroot Temperatureを÷100して保存する経路を確認 |
| ChargerCurrent | IsChargingのときだけ、電池エントリーのAmperage。ACコンセント側電流とは異なる |
| ChargerVoltage | IsChargingのときだけAdapterVoltageを渡す呼出し。電池セル電圧とは異なる |
| ChargingState / ConnectedState | それぞれ別の指標。接続と充電を同一視しない |

Temperatureの元値をcenti CとするApple公開メタデータと、÷100する27.2のコードが一致する。
この経路の整数温度をLifetimeDataの温度と同じ倍率で再度割ってはいけない。
AmperageのmAという公開メタデータはあるが、全Watchの電流・AdapterVoltageの変換まで確認したことにはならない。

初期化・大きな時間飛びでは`floor(Unix秒 / interval) * interval + interval`をcurrentIntervalへ設定。
それをHHmmでラベルにし、送信後に次区間へ進めるため、この経路のラベルは区切りの終了側を指す。
Formatterはen_US、明示的なタイムゾーン設定は見つからず、UTC固定とは扱えない。
最終ファイルにはHHmmしかないため、時差変更・DSTで重なる時刻の元UTC時刻を復元できない。

`submitMetricsToAggd`は複数区間を埋める際、**最新区間だけ**updateSampledMetricsを呼ぶ。
古い穴埋め区間を、それぞれ独立した実測温度として描画しない。
初期既定値はBatteryLevel=127、BatteryTemperature=1000。1000°C等として表示しない。
集計はlastで、平均・最高・最低・全サンプルではない。

**機種差:** 解析したiPhone側のinstantiateMetricsにはChargerVoltageの生成が見つからない一方、
Watch実ログには同項目がある。同じクラス名があるだけでWatchの全仕様が同じとはできない。
実ログでこのイベントがあったのは30件全てWatch。iPhone/iPadの1秒温度グラフは得られない。

## 5. 温度×残量ヒートマップ

経路は電池／SMC → powerd → IOKitのIOPMCopyBatteryHeatMap
→ PLBatteryAgent → CoreAnalytics。
IOKitの関数はpowerdのXPCへ`batteryHeatMapData`を問い合わせるラッパーで、
そのXPCは`com.apple.private.iokit.batterydata`権限を確認する。
一般アプリから直接呼べる公開APIを見つけたという意味ではない。

### 形式とビン表

`PLBatteryAgent`内の定数配列を復元した。
SoC=0…24は次の表示ラベルに対応し、4%刻みではない。

```
0_1, 1_2, 2_3, 3_4, 4_5, 5_6, 6_8, 8_10,
10_15, 15_20, 20_25, 25_30, 30_40, 40_50, 50_60,
60_70, 70_80, 80_85, 85_90, 90_92, 92_94, 94_96,
96_98, 98_99, 99_100
```

| 温度bin | 元辞書のキー | OS内部の表示ラベル |
| --- | --- | --- |
| 0 | [−∞, 0] | -10_0C |
| 1 | [1, 10] | 0_10C |
| 2 | [11, 15] | 10_15C |
| 3 | [16, 20] | 15_20C |
| 4 | [21, 25] | 20_25C |
| 5 | [26, 30] | 25_30C |
| 6 | [31, 35] | 30_35C |
| 7 | [36, 40] | 35_40C |
| 8 | [41, 45] | 40_45C |
| 9 | [46, 50] | 45_50C |
| 10 | [51, 60] | 50_60C |
| 11 | [61, 70] | 60_70C |

最初の辞書キーは−∞を含むが、表示ラベルは-10_0Cであり、一致していない。
表示ラベルだけで外れ値を切り捨てない。SoCの厳密な端点の包含、70°C超のゲージ側処理は未確定。
HeatMapType=1のときSoC、それ以外の経路では電圧側の別ビン表を使う。
Analyticsイベントに付くversion=1と、powerd保管庫のFormat Version=4は**別のバージョン**。

action=0/1/2はPowerlogではcharging_a / charging_b / discharging。
解析したiPhoneのpowerdでは同番号の保存先がwired / wireless / discharging。
Watch実ログへの有線／無線という説明の転用は未検証なので、actionの元名を保つ。

### 蓄積・クリア・時間の注意

powerdの0x10001c978は12行×25バイトをSMCキーBHT0…BHT9、BHTA、BHTBから読み、
既存のOS保管値へ加える。その後、SMCの当該行をゼロで書き戻す。
OS保管庫はCFPreferencesへ保存・同期し、シリアル不一致や旧形式等では作り直す。
取得APIの応答処理（0x100030ec4）は**OS保管済み辞書を返す**。ここでは保管値を消さない。
PLBatteryAgentもその整数をそのままTimeInMinutesおよびtimeSpentへ送り、差分を引いていない。

したがって、二層あることに注意する。

- SMC側: 前回の回収以降のカウンターを読み、その後クリアする。
- OS側: 回収分を蓄積し、問い合わせ時にその保管値を返す。

これをCoreAnalyticsがsumした値は、安易に「今日この温度で過ごした分数」にはできない。
SMCのクリアに失敗した場合はエラーログに進み、次の回収で重複加算の可能性もある。
電源断／保存失敗とクリアの完全なトランザクションはこの経路では保証されない。
これらの失敗時の影響は制御フローからの推論であり、実機で二重加算や消失を再現した報告ではない。

HeatMapInterval設定値は分からナノ秒へ変換してタイマーに使う。
設定辞書自体がnilの場合の定数は1,800秒、辞書に有効な数値がない分岐の定数は108,000秒。
両者を取り違えて「必ず30分ごと」と説明しない。実機の設定値を検証したわけでもない。

**利用判定:** 条件ごとの分布候補にはなるが、当日滞在グラフとしての実装は保留。
Watchの同じbin表・リセット処理の現物確認も必要。

## 6. シャットダウン前後の電池情報

`getBatteryShutdownData` → IOPMPowerSourceの状態 →
`logEventPointBatteryShutdownWithRawData:packID:systemShutdownData:`
（0x29fcbc6dc）→ `logBatteryShutdownToCA:forBatteryPack:`（0x29fcba380）。
BatteryPackCountがある場合の複数パック処理もあり、BatteryPackIDを無視して合算しない。

ShutDownTimestampを前回保存したパック別のLastShutdownSystemTimestamp等と比較し、
同値なら再記録を避ける（0x29fcbc8c8）。電池側の最後の停止状態を後で読む構造であり、
Analyticsのファイル生成日が停止日とは限らない。

| 項目 | 判別できた内容 |
| --- | --- |
| Count | 入力されたシャットダウン診断イベント件数。DataError付きの経路も別扱いに注意 |
| daily_total_UPOCount | このCA送信関数ではDataErrorなし／0、かつUISOCのintValueが11以上なら1を設定 |
| isUPOEntry: | 別用途の判定。通常はUISOC>10 **かつTemperature>0**。UPO_Debugによる強制経路もある |
| ShutdownSoc / UISOC | 元辞書の別キーから移す別項目。全て同じ残量と決めない |
| UpoReboot | ShutDownUpoRebootを移す。これだけでユーザー操作の再起動／OSクラッシュを区別しない |
| LifetimeUPOCount等 | 電池側の累計情報。日次イベント件数とは別 |
| Voltage、Current、Capacity群 | 停止前後の状態候補。Previousを現在値として混ぜない |

標本ではdaily_total_UPOCountの非null値を観測していない。
名前にShutdownがある行の数から「突然落ちた回数」を作る根拠にはならない。
DLOG、RaTable、CriticalFlags、SOCAlarm等の全物理仕様とゲージ固有の倍率は今回のOS処理だけでは決まらない。
エンドユーザー向け故障診断より、元名を保持する詳細情報向け。

## 7. 充電最適化

生成元はdasd本体ではなく、**PowerUI.frameworkのPowerUISmartChargeManager**。
`recordAnalytics`（0x29f81958c）が充電セッションのイベントを集め、
`constructAnalyticsStatusFromEvents:`（0x29f814b88）を経て
`com.apple.das.smartcharging.status`を送る。

| 項目 | 計算・意味 |
| --- | --- |
| PluginDuration | プラグを抜いた側の日時−接続開始日時。NSDateの差なので秒 |
| TotalEligibleDuration | EligibleForIdleになった時点から終了までの秒数 |
| EstimatedUsableEligibleDuration | `max(0, TotalEligibleDuration − 予測満充電所要秒数)` |
| ActualUsableEligibleDuration | TopOffなど実イベントの時刻を考慮する分岐。上の推定値と同一ではない |
| IdleDuration | 充電抑制の開始・TopOff開始・一時無効化・終了時刻の差から選ぶ秒数。端末の画面オフ時間ではない |
| Engaged | IdleDuration>0から生成されるフラグ |
| UnderChargedAvoidable / Unavoidable | 満充電モデル、接続終了時の残量、利用可能だった時間等による内部分類。故障・充電器の良否ではない |
| DecisionMaker / ModelVersion / TrackingID | モデル・実験・集計の分類用。ユーザーに有用な直接の計測量ではない |

JITChargingの設定はDurationをsumし、UnderCharged系もsumする。
Countは入力件数であり、全充電回数を無条件に網羅する分母ではない。
セッションが日をまたぐ場合も「当日の時間」として単純配分できない。
BadSessionや欠損を0として補完すると、最適化していない時間と区別できなくなる。

### Lifetime統計の実体

`reportBatteryHealthMetrics`（0x29f813f78）はOSの設定保存領域から
`countChargeSessionsEngaged` / `countMinutesIdled`を読み、
LifetimeEngagements / LifetimeIdleDurationMinsとして送る。分への変換・累計更新もrecordAnalyticsで確認した。
Engagementの累計加算側にはIdleDuration>=60秒の条件があり、Engagedフラグの>0条件とは異なる。

これらは**OSの最適化処理が保存している累計**で、電池ゲージから製造以来の値を取得する経路ではない。
設定の初期化・復元・OS変更時の保存継続を保証する公開仕様は見つからない。
欠損を0へ置き換える送信側の分岐もあるので、0を「一度も最適化されていない」と断定できない。
日次ファイルのlast値を毎日足すことも誤り。

## 8. 低電圧滞在・電池セル接続

### LowVoltageResidencyCounters

`BatteryData.LifetimeData.LowVoltageResidencyCounters` → `parseLowVoltageResidencyCounters:`
（0x29fcb9288）→ bin別last。
Powerlogだけでは単位は不明だったが、別の利用側から確認できた。

BatteryAlgorithmsのLowVoltageResidency::Deserialization::setSMCKeyDataFromDictionary
（0x25a0664e8）はデータ長108バイト＝27個を検査。
`GaugeLVRTable::DataField::TotalSeconds()`（0x25a065b08）は3×3×3のu32を列挙し、
**各値×0.01を加算して秒を返す**。
`TotalSecondsBelow3V()`（0x25a065a20）は同じ列に重みを掛け、先頭18個を採用、残り9個を除外する。
これで、この27bin形式では3V未満の小計を作る具体的な根拠が得られた。
他の軸の温度／負荷境界や、残りの正確な電圧境界までは確認できていない。

ただしAnalyticsには原本がそのまま入らない。
Powerlogは**各値を2有効数字に丸めてから**numberWithLongで送る。
たとえば合成値1234は概ね1200相当となり、小さな日次差分が消えたり、まとめて増えたりする。
丸めは各bin単位なので、元の総時間を正確に逆算できない。
さらに丸め関数の引数はsigned int32変換だった。負数・全ビット1等を、そのまま負の滞在秒にしない。
Appleの別利用側にも全ビット1の無効値を除外する処理がある。

**利用判定:** 対象OS・27bin形式に限る概算の詳細情報として検討可能。
当日増分、個々の短い低電圧発生時間、健康度%としては使わない。
ハード側の起点、交換／再校正時の初期化、他ゲージの形式差は未確定。

### BatteryCellDisconnectCount

PLBatteryAgentは現在のカウンターをイベントvalueへ渡し、前回値のオブジェクトも保持する。
差分にして送る処理ではない。設定はlast(value)とCountを別々に集計する。

[Apple公開ソースのcheckCellDisconnectCount](https://github.com/apple-oss-distributions/PowerManagement/blob/d415e45501842834a280930c3eed9186544a67f0/pmconfigd/BatteryTimeRemaining.m#L3123)
ではSMC対応端末の電池ヘルス判定に用いる。USBケーブルの接続回数ではない。
同ソースの閾値10を、全iPhone共通の「故障確定」へ転用することもしない。
物理的な切断検出の詳細とゲージ側リセット条件は公開されておらず、
表示するなら「電池セル接続に関するカウンター（詳細）」程度にとどめる。

## 検証範囲・再現資料・残った調査条件

- Apple CDNの既存IPSWに加え、同版のシステム／ルートコンポーネントとカーネルを読み取り専用で解析。
  改変したファームウェアの実行、SMCへの書込み、故意の電池切断・異常充電は行っていない。
- PowerlogLiteOperators、PowerlogCore、PowerUI、IOKit、ComputeSafeguards、BatteryAlgorithms、powerd、
  AppleSmartBatteryManagerEmbeddedを照合。アドレス・抽出物ハッシュを台帳に記録した。
- 単位やビン表は文字列だけで決めず、呼出し・引数・定数・集計式と照合。
  ADRP参照の探索結果だけで生成元と断定しない。生データ列と同名のAppleの利用側も確認した。
- Apple公開PowerManagementはコミット`d415e45501842834a280930c3eed9186544a67f0`へ固定。
  macOS系公開コードとiPhone用非公開バイナリの違いを残し、公開コードだけで全機種へ一般化しない。
- 既存91件はフィールドの存在・型・欠損と照合。原本、端末ID、測定値、IPSW本体、AppleバイナリはGitに追加しない。
- Watch 24S118のOTA照会も試したが、今回の照会では該当資産を得られなかった。
  Watchの実ファイルがあることと、Watch用生成コードの裏付けがあることは別。

残課題を確定するには、正確なWatchファームウェア、ゲージ型別のbin／フラグ仕様、
または時刻・接続・温度を管理した継続観測が必要。
その証拠がない部分を「多分10%刻み」「多分時間」「多分毎日リセット」で埋めない。
今回分かった式やラベルだけを後の実装判断の根拠にする。

資料の検査では、8候補の全イベントが既存カタログにあること、12/25ビン表の個数、
3V未満マスク、未確定単位のnull保持、相互リンク、JSON構文を確認した。
既存の研究用テストはBatteryFieldCatalogResearchTestsの5件とAnalyticsReportResearchTestsの2件が成功。
これは資料・抽出補助コードの検査であり、ゲージの物理仕様やWatch実機での再現を証明するテストではない。
今回だけ使用したディスクイメージ・全体シンボルキャッシュ等は解析後に削除し、約26.65GiBを回収した。
後の検証に必要な小さい対象バイナリ・ハッシュ・メソッドダンプは非公開のBuild下へ保持した。
