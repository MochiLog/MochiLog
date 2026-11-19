# 既存バッテリー項目の意味・単位・期間の台帳

調査日: 2026-11-19。MochiLog main `99773ca` のコードと、Apple配布の
iPhone14,4 / 27.2 (24B119) のPowerlogLiteOperators・CoreAnalytics設定を照合した。
これはAppleが保証する公開API仕様ではなく、特定ビルドの静的解析とコード監査の記録。
製品の表示・計算・保存データは今回変更していない。

追加候補の単位・期間・ビン・理由コードをさらに追った結果は
[8候補の詳細監査](ANALYTICS_CANDIDATE_DEEP_DIVE_2026-11-19.md)を参照。
特に時間帯別Temperatureの÷100経路は、LifetimeDataの温度と区別する。

## 範囲と確度

- `LogParser.BatteryJSON.Message` の電池フィールド宣言 **15個すべて**を対象にした。
- 関連する3 transformは73・106・87 measuresを持ち、measure名の和集合は110個。
  dimensionsとパーサーだけの宣言も合わせた**120項目**を、末尾とJSONに全件収録した。
  120個すべての意味が解明された、という意味ではない。
- [機械可読台帳](research/battery-field-catalog-27.2.json)には、項目ごとの入力名・型・集計関数・
  利用中か・説明・単位・期間・確度・根拠を保持する。
  [解釈メモ](research/battery-field-notes-2026-11-19.json)を分離し、OS定義と人間の解釈を混ぜない。
- 現在値APIの全フィールドは機種・OS・状態で増減する。以前観測した323項目を固定仕様とは扱わない。
  今回の現在値照会はエラー応答で、値を含まない完全な実機スキーマの再採取はできていない。
  したがって「全323項目を新たに実測して解説済み」とはしない。

確度は `verified-configuration`（設定の操作を確認）、`verified-implementation`
（アプリの実装を確認）、`partial`（由来等の一部を確認）、`inferred-name`
（名前や一般的知識による推測）、`unknown`（解釈未確定）に分けた。
確度は項目全体の万能な保証ではない。例えば取得元が確認できても単位やリセット条件は未確定であり得る。

## 日次ファイルと日次の値は別

```text
電池ゲージの現在値・学習値・LifetimeData
                    ↓ Powerlogが値を保持／イベント送信
CoreAnalyticsがイベントを集計（多くの電池項目はlast）
                    ↓
DailyのAnalyticsファイルへ保存
```

`last_value_` は、その集計入力で最後に採用した値という意味。
項目名にMaximum／Averageがあっても、Analyticsが当日の全サンプルからmax／averageを計算したとは限らない。
ファイルの日付、ゲージ値の更新日時、元の統計の起点を別々に扱う。
期間解決と6時間タイマーの詳細は[生成条件調査](ANALYTICS_GENERATION_CAUSES_2026-11-19.md)を参照。

## 現在記録に使う電池項目

以下の単位欄は、現行アプリの変換と、裏付けの限界も併記している。
未確認の内部単位を、既存UIに書かれているという理由だけで仕様と認定しない。

| 入力（`last_value_`を省略） | 現行の扱い | 意味・時間軸と注意 |
| --- | --- | --- |
| CycleCount | 充放電回数 | 積算サイクルの最後の値。接続回数でも、その日の充電回数でもない |
| DesignCapacity | デコード宣言・容量差検証 | 今回の3 transformには定義なし。現在の`result.designCapacity`は機種カタログから設定され、ログの値を結果へ代入するフォールバックは実装されていない |
| NominalChargeCapacity | 公称容量、mAh表示 | 取得元raw辞書直下のゲージ値。新品の仕様容量や直接放電測定値と同一視しない。学習・温度補正等の内訳は未確定 |
| AppleRawMaxCapacity | 実測容量、mAh表示 | 同じくraw辞書直下。APIの報告値であり、MochiLogが実測試験をしたわけではない。内部スケールの全機種検証は未実施 |
| MinimumQmax | 低レート容量、mAh表示 | **LifetimeData由来**。Qmax関連の履歴最小値と考えられる。「低レート放電容量」という意味の証拠は未取得 |
| MaximumCapacityPercent | 設定上の最大容量% | PLBatteryAgent側で得る値。設定アプリとの一致、丸め・上限・更新タイミングまでは未確認 |
| AverageTemperature | 原値を°C表示 | **LifetimeDataの平均**。当日平均ではない。時間加重かサンプル加重か、起点・リセット条件は未確定 |
| MaximumTemperature | 原値÷10を°C表示 | **LifetimeDataの最大**。当日の最高温度ではない。÷10は現行実装で、全ゲージの仕様確認ではない |
| MinimumTemperature | 原値÷10を°C表示 | **LifetimeDataの最小**。当日の最低温度ではない。同じ単位上の留保あり |
| MaximumPackVoltage | 原値をmV表示 | **LifetimeDataのパック最大電圧**。日次最大・セル別電圧と混同しない |
| MinimumPackVoltage | 原値をmV表示 | **LifetimeDataのパック最小電圧**。日次最小ではない。0や番兵値の意味も個別確認が必要 |
| DailyMaxSoc | 最大残量% | `BatteryData`直下。日次最大を示す名前だが、ゲージのリセット境界が端末の0時／UTC0時／ログ時刻のどれかは未確定。Analyticsの集計関数自体はlast |
| DailyMinSoc | 最小残量% | 同様。DailyMaxSocとの差を一日の総消費量にはしない。途中の充電・複数回の放電を表せない |
| DOFU | 初使用日、UNIX秒として変換 | `BatteryData.DateOfFirstUse`を扱う生成経路を確認。購入日ではない。元入力の基準・変換・ゲージ交換時の扱いは引き続き確認が必要。0・欠損を1970年の有効日付にしない |
| TotalOperatingTime | デコード宣言のみ | **LifetimeData由来**。現行`ParseResult`に代入せず記録にも保存しない。端末購入後の利用時間・画面オン時間として使わない。時間単位・製造時からの起点やリセットは未確定 |

Appleは充放電サイクルを、複数回に分かれていても容量の合計100%を使う単位として説明している。
この一般的な意味と、ゲージ内部の補正・交換時のカウンター挙動は別の確認事項。
[Appleの充電サイクル説明](https://support.apple.com/en-ge/guide/iphone/iph63eecc618/27/ios/27)

Qmaxについて、TIは電池ゲージが学習する化学容量として説明している。
これは「Qmaxを低レート放電容量と断定しない」ための一般的な裏付けであり、Appleの
`MinimumQmax`のスケール・履歴更新条件や、全Apple製品が同じチップを使う証明ではない。
[TI SLUA997](https://www.ti.com/lit/an/slua997/slua997.pdf)

## アプリが計算する値・付与する情報

| 項目 | 計算／取得 | 解釈の限界 |
| --- | --- | --- |
| nominalRatio | NominalChargeCapacity / カタログ設計容量 ×100 | アプリ計算の比率。OSの健康度%と同一ではない |
| rawRatio | AppleRawMaxCapacity / カタログ設計容量 ×100 | 同上。分母の機種・地域・電池交換との差に影響される |
| lowRateRatio | MinimumQmax / カタログ設計容量 ×100 | 元のMinimumQmaxの意味を引き継ぐ。低レート試験の結果とは認定できない |
| deflator | NominalChargeCapacity / AppleRawMaxCapacity ×100 | **アプリが算出した2値の比**。Apple内部の補正係数を直接取得した値ではない |
| diagnosticResult | rawRatioが80%未満／90%未満／それ以外で区分 | アプリ独自の簡易判定。Appleの診断試験・安全性・交換必要性の確定診断ではない |
| logDate | ヘッダーtimestampをDateへ変換 | そのファイルの日時。全項目の最終測定時刻ではない |
| osVersion | ヘッダーos_version | ログを出したOS。Watchログを取得したiPhoneのOSとは区別する |
| deviceModelCode / detectedIdentifier | 電池行hardwareModel等と機種解決処理 | 機種識別子。同機種の別個体を識別するIDではない |
| detectedBoardId | 識別子の検出・解決用 | 基板識別情報。個体UUIDではない。パーサー結果には宣言があるが、この`LogParser.parse`内では直接代入しない |
| storage / ram | メタデータdeviceCapacity / dramSizeをGB表記 | 空き容量・現在使用中RAMではない。報告値の丸めや予約領域があり得る |
| productSku | メタデータの地域等の区分 | 地域別容量選択等に使う。個体IDではない |
| physicalDeviceID | MochiLogの個体管理・取込元により付与 | Appleの解析ログから取得した共通UUIDではない。旧記録はnilの場合がある |
| manufactureDate | モデルにはあるが通常のログ取込ではnil | `WeekMfd`から正しい年月を現在自動算出しているわけではない。一般のManufactureDateのビット形式をそのまま転用しない |
| createdAt / id | アプリが付与 | 記録作成日時と記録ID。電池の製造日時・個体IDとは別 |

保存値が0でも、元フィールドの0か、現行コードが欠損を0へ置き換えたのかを区別する必要がある。
特に任意項目のMinimumQmaxは`?? 0`となるため、0を有効な化学容量と解釈しない。

## 現在のバッテリーAPI

PC側`BatterySnapshot.read_registry`はpymobiledevice3の`DiagnosticsService.get_battery()`を使用する。
現在値は通常の日次ファイルとは別。ブリッジは型を保持するplistを渡し、Swift／C#が表示を分類する。
スマホの端末内取得も、取得結果をネイティブ側で分類する。
[pymobiledevice3の実装](https://github.com/doronz88/pymobiledevice3/blob/master/pymobiledevice3/services/diagnostics.py)

### 通常表示の既知パス

同名でもrootと`BatteryData`内を区別する。追加表は型・範囲の検証を通った項目だけ表示する。

| パス（root直下） | 内容・表示 | 留保 |
| --- | --- | --- |
| CycleCount | サイクル数 | 日次増分ではない |
| DesignCapacity | 設計容量、mAh | rootを確認した値を採用。別の入れ子を無条件に代用しない |
| IsCharging | 充電中か | 電源接続中と同じではない |
| ExternalConnected | 外部電源の接続状態 | 接続していても充電していないことがある |
| ExternalChargeCapable | 外部電源から充電可能か | 実際に充電が進んでいる状態と別 |
| FullyCharged | 満充電状態のフラグ | CurrentCapacityとの数学的同値を保証しない |
| AppleRawExternalConnected | 生の外部接続状態 | 上位のExternalConnectedと差が出る条件は未解明 |
| BatteryInstalled | 電池の存在 | 電池の純正品認証ではない |
| AtCriticalLevel | 危険な残量域のフラグ | 故障・発火危険のフラグとは扱わない |
| Voltage | mV | パックとセル別電圧の混同に注意 |
| Amperage | mA | 電流の符号・平均化窓は機種ごとの確認が必要 |
| InstantAmperage | mA表示 | 瞬時寄りの別値。Amperageの窓との厳密な差は未確定 |
| Serial | シリアル文字列 | 端末の製品シリアルとは限らない。公開台帳には実値を入れない |

Appleの公開IOPMPowerSource定義は、電圧mV・電流mA・サイクル・基本的な充電フラグの意味を説明する。
ただし同じ資料のCurrentCapacityはmAhであり、現在のiOS診断データの同名キーを無条件に%とする根拠にはならない。
AppleRawExternalConnectedやInstantAmperageなどの全内部拡張仕様を保証する資料でもない。
[Apple公開ヘッダー](https://github.com/apple-oss-distributions/xnu/blob/main/iokit/IOKit/pwr_mgt/IOPMPowerSource.h)

### 既に詳細情報へ渡している項目群

| 群・例 | 分かっていること | 解明が残ること |
| --- | --- | --- |
| 容量: NominalChargeCapacity、AppleRawMaxCapacity、FullChargeCapacity、CurrentCapacity等 | 元のパス・型・値を保持している | 各スケール、補正、更新条件。同名の入れ子とrootが等しい保証なし |
| BatteryData / LifetimeData | 現在値・ゲージの内部学習値・寿命中の統計が混在する | 全キーの単位・リセット起点・ファームウェア依存性 |
| ChargerData / AdapterDetails | 充電器・充電状態に関する内部値を含み得る | コード表、電圧電流の対象点、許容値と実測値の区別 |
| PowerTelemetryData | 電力系の瞬時値・積算値らしいキーを含み得る | スケール・積算周期・リセット条件。式を確認せずW／Wh換算しない |
| IOReportLegend等 | チャンネルの説明・単位コードなどのメタデータ | チャンネル名があることと、その時点の温度・電力を取得したことは別 |
| InductiveData / KioskMode / CarrierMode / DeadBatteryBootData等 | 無線充電・特殊モード・起動関連の内部値を含み得る | 端末への存在と意味を個別確認。一般利用の統計へ無条件に混ぜない |
| byte配列・内部Flags・未知の辞書 | 欠落させず詳細表示へ渡す | エンディアン・版・ビット割当の根拠なしにデコードしない |

これらは各端末で全て得られるという保証ではない。
Appium側にも類似の型宣言があるが、**型宣言は単位の仕様書でも実機の存在証明でもない**。
[Appiumの参照型](https://github.com/appium/appium-xcuitest-driver/blob/master/lib/commands/advanced-battery-types.ts)

現在値の実値を履歴・iCloud・サポートログや今回のGit成果物へ保存しない方針は維持した。
完全スキーマの追加採取では、メモリ上で応答を解析し、**パスと型だけ**を残す。
シリアル・日時・容量等の実値も不要。通信エラーが返った場合、件数0の正常スキーマとして扱わない。

## IPSWで確認した取得元

アドレスは24B119専用。アセンブリ・バイナリ本体は公開リポジトリへ入れず、再解析用の対象と位置を記す。

| 確認内容 | PowerlogLiteOperatorsの位置 |
| --- | --- |
| raw入力→BatteryData→LifetimeData→x21を保持 | `logEventNoneBatteryConfigWithRawData:`、`0x29fcbde38–0x29fcbdebc` |
| NominalChargeCapacity / AppleRawMaxCapacityはraw入力直下 | `0x29fcbdf2c–0x29fcbdf84` |
| TotalOperatingTime / AverageTemperatureはx21から取得 | `0x29fcbdf8c–0x29fcbdfe4` |
| 最大／最小パック電圧はx21から取得 | `0x29fcbe16c–0x29fcbe1c4` |
| MinimumQmaxはx21から取得 | `0x29fcbe1fc–0x29fcbe224` |
| 最大／最小温度はx21から取得 | `0x29fcbe28c`以降／`0x29fcbe2bc`以降 |
| MaximumCapacityPercentはagent側の取得・分岐を経る | `0x29fcbed94–0x29fcbede8` |
| DateOfFirstUse→DOFUの生成 | `0x29fcbf35c–0x29fcbf454` |
| DailyMaxSoc / DailyMinSocはBatteryData直下 | `0x29fcbf684–0x29fcbf708` |

ファームウェアのURL・ハッシュ・ツール版は[最初の調査](ANALYTICS_GENERATION_2026-11-19.md)に記録した。
LifetimeDataの名称と上記のデータ流は確認できたが、「電池製造時から絶対に不変の起点」とまでは証明していない。
交換、修理、ゲージの初期化、再学習で変わる可能性は残る。

## 表示・説明の見直しが必要な点

1. 現在の`temperature_daily`と`BatteryRecord`の「環境データ(日次)」は取得元と合わない。
   生涯側の統計と日次SoCを同じ日次データとして説明しない。
2. MinimumQmaxを「低レート放電容量」と断定する説明は再検討する。
3. 「実測」「設定上の表示」「デフレータ」「診断」も、ゲージの報告値・アプリ計算・独自判定と分かる説明にする。
4. 欠損と0、ファイル日時と値の鮮度、統計の範囲を区別する。
5. これらの意味付け変更を、値の単純な一括マイグレーションとして実行しない。
   数値を変える場合は対象キー・元定義・OS・既存レコードの根拠を先に確定する。

本調査では上記を課題として記録した。表示修正・データ移行・ストア配信は含めていない。

## 台帳の再生成

```sh
python3 scripts/research/catalog-battery-fields.py /path/to/extracted/CoreAnalyticsConfig/defaultConfig.json \
  --parser MochiLog/Services/LogParser.swift \
  --notes docs/research/battery-field-notes-2026-11-19.json \
  --firmware 'iPhone14,4 / 27.2 / 24B119' \
  --output docs/research/battery-field-catalog-27.2.json
python3 Tests/BatteryFieldCatalogResearchTests.py
```

入力は最大128MiB・1行4MiB、通常ファイルのみ。取得中の変更や非JSON数値を拒否する。
出力は選択した定義の要約と解釈だけで、端末値・原本の内容は含めない。

## 全120項目の索引

以下はJSON台帳から生成した索引。各項目の単位・期間・根拠と複数transformでの定義はJSONを参照する。
`last_value_`の有無を保ち、同じ語のdimensionとmeasureを勝手に統合しない。

<!-- FIELD_INDEX -->

| 元の項目名 | パーサー宣言 | 意味・留保 | 確度 |
| --- | --- | --- | --- |
| `AlgoChemID` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `BatteryPackID` | なし | 送信側が付けるパック区分。255を渡す経路がある。個体UUIDではない。 | partial |
| `BatterySerialChanged` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `ChemID` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `Count` | なし | 集計に入ったイベント件数。充放電回数・測定秒数ではない。 | verified-configuration |
| `Flags` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `GasGaugeFirmwareVersion` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `OriginalBattery` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `WeekMfd` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `Wom_1` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_AlgoChemID` | なし | 推定アルゴリズム用の化学特性IDと考えられる。 | inferred-name |
| `last_value_AppleRawMaxCapacity` | あり | ゲージが報告するAppleRawMaxCapacity。生の診断値という位置付けで、独立した実測試験ではない。 | partial |
| `last_value_AverageTemperature` | あり | LifetimeDataの平均温度。平均の重み付け・対象期間の開始点は未確定。 | partial |
| `last_value_BatteryHealthMetric` | なし | 内部の健康度指標。単位・閾値不明。Appleの最大容量%とは別。 | inferred-name |
| `last_value_BatterySerialChanged` | なし | シリアル変更を示す内部値。修理履歴の確定情報として使わない。 | inferred-name |
| `last_value_ChemID` | なし | 電池化学特性の内部IDと考えられる。メーカー名ではない。 | inferred-name |
| `last_value_ChemicalWeightedRa` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_CycleCount` | あり | 充放電サイクル数。充電ケーブルの接続回数ではない。 | partial |
| `last_value_CycleCountLastQmax` | なし | 最後のQmax更新時のサイクル数らしい値。更新条件は未確定。 | inferred-name |
| `last_value_DOFU` | あり | BatteryData.DateOfFirstUseから生成される初使用日の情報。購入日ではない。 | partial |
| `last_value_DailyMaxSoc` | あり | BatteryData直下のDailyMaxSoc。日次最大SoCと読めるが、その日境界・リセット時刻は未確定。 | partial |
| `last_value_DailyMinSoc` | あり | BatteryData直下のDailyMinSoc。日次最小SoCと読めるが、その日境界・リセット時刻は未確定。 | partial |
| `last_value_DesignCapacity` | あり | パーサーの受け入れ宣言あり。ただし今回の3 transformには定義なし。表示・比率の分母は現行コードでは機種カタログから取得する。 | verified-implementation |
| `last_value_Flags` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_FlashWriteCount` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_GGUpdateStatus` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_GasGaugeFirmwareVersion` | なし | 電池ゲージのファームウェア版。iOS版ではない。 | inferred-name |
| `last_value_HighAvgCurrentLastRun` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_ITMiscStatus` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_KioskModeHighSocDays` | なし | キオスクモード高SoC滞在日数らしい内部値。一般利用の経過日数ではない。 | inferred-name |
| `last_value_KioskModeHighSocSeconds` | なし | キオスクモード高SoC滞在秒数らしい内部値。閾値・起点未確認。 | inferred-name |
| `last_value_KioskModeLastHighSocHours` | なし | キオスクモードの高SoC関連時間らしい内部値。意味・起点未確認。 | inferred-name |
| `last_value_LTDataCorruptionOffset` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_LastResetReason` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_LastUPOTimestamp` | なし | 最後のUPO時刻らしい内部値。単位・時刻基準不明。 | inferred-name |
| `last_value_LifetimeUPOCount` | なし | 生涯UPOカウンターらしい値。UPOの判定条件・リセットは未確定。 | inferred-name |
| `last_value_LowAvgCurrentLastRun` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_MaximumCapacityPercent` | あり | PLBatteryAgent側で得た最大容量の百分率。設定アプリの表示と常に一致するという保証は未確認。 | partial |
| `last_value_MaximumChargeCurrent` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_MaximumDeltaVoltage` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_MaximumDischargeCurrent` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_MaximumFCC` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_MaximumOverChargedCapacity` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_MaximumOverDischargedCapacity` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_MaximumPackVoltage` | あり | LifetimeDataの最大パック電圧。今日の最高電圧ではない。 | partial |
| `last_value_MaximumQmax` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_MaximumRa0_8` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_MaximumRa8` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_MaximumTemperature` | あり | LifetimeDataの最大温度。今日の最高温度ではない。 | partial |
| `last_value_MinimumDeltaVoltage` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_MinimumFCC` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_MinimumPackVoltage` | あり | LifetimeDataの最低パック電圧。今日の最低電圧ではない。 | partial |
| `last_value_MinimumQmax` | あり | BatteryData.LifetimeDataのMinimumQmax。Qmaxの最小履歴値である可能性が高い。低レート放電容量と断定する根拠は未取得。 | partial |
| `last_value_MinimumRa0_8` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_MinimumRa8` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_MinimumTemperature` | あり | LifetimeDataの最低温度。今日の最低温度ではない。 | partial |
| `last_value_NCCMax` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_NCCMin` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_NominalChargeCapacity` | あり | ゲージが報告するNominalChargeCapacity。製品仕様の固定容量や直接実測と同一視しない。 | partial |
| `last_value_OriginalBattery` | なし | 元電池を示す内部フラグらしい値。単独で純正品認証と断定しない。 | inferred-name |
| `last_value_QmaxCell0` | なし | セル0のQmaxらしい値。MinimumQmaxや満充電容量と混同しない。 | inferred-name |
| `last_value_QmaxUpdFailCount` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_QmaxUpdSuccessCount` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_RDISCnt` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_RSS` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_RaTable_1` | なし | Raテーブル要素。抵抗モデル関連と推測されるが、係数・スケール・要素の対応は未確定。 | inferred-name |
| `last_value_RaTable_10` | なし | Raテーブル要素。抵抗モデル関連と推測されるが、係数・スケール・要素の対応は未確定。 | inferred-name |
| `last_value_RaTable_11` | なし | Raテーブル要素。抵抗モデル関連と推測されるが、係数・スケール・要素の対応は未確定。 | inferred-name |
| `last_value_RaTable_12` | なし | Raテーブル要素。抵抗モデル関連と推測されるが、係数・スケール・要素の対応は未確定。 | inferred-name |
| `last_value_RaTable_13` | なし | Raテーブル要素。抵抗モデル関連と推測されるが、係数・スケール・要素の対応は未確定。 | inferred-name |
| `last_value_RaTable_14` | なし | Raテーブル要素。抵抗モデル関連と推測されるが、係数・スケール・要素の対応は未確定。 | inferred-name |
| `last_value_RaTable_15` | なし | Raテーブル要素。抵抗モデル関連と推測されるが、係数・スケール・要素の対応は未確定。 | inferred-name |
| `last_value_RaTable_2` | なし | Raテーブル要素。抵抗モデル関連と推測されるが、係数・スケール・要素の対応は未確定。 | inferred-name |
| `last_value_RaTable_3` | なし | Raテーブル要素。抵抗モデル関連と推測されるが、係数・スケール・要素の対応は未確定。 | inferred-name |
| `last_value_RaTable_4` | なし | Raテーブル要素。抵抗モデル関連と推測されるが、係数・スケール・要素の対応は未確定。 | inferred-name |
| `last_value_RaTable_5` | なし | Raテーブル要素。抵抗モデル関連と推測されるが、係数・スケール・要素の対応は未確定。 | inferred-name |
| `last_value_RaTable_6` | なし | Raテーブル要素。抵抗モデル関連と推測されるが、係数・スケール・要素の対応は未確定。 | inferred-name |
| `last_value_RaTable_7` | なし | Raテーブル要素。抵抗モデル関連と推測されるが、係数・スケール・要素の対応は未確定。 | inferred-name |
| `last_value_RaTable_8` | なし | Raテーブル要素。抵抗モデル関連と推測されるが、係数・スケール・要素の対応は未確定。 | inferred-name |
| `last_value_RaTable_9` | なし | Raテーブル要素。抵抗モデル関連と推測されるが、係数・スケール・要素の対応は未確定。 | inferred-name |
| `last_value_ResetCnt` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_ResetDataComms` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_ResetDataCorruption` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_ResetDataFirmware` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_ResetDataHardFault` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_ResetDataHardware` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_ResetDataSoftware` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_ResetDataSwWatchDog` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_ResetDataWatchDog` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_SafetyEvent0` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent1` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent10` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent11` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent12` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent13` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent14` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent15` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent16` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent17` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent18` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent2` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent3` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent4` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent5` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent6` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent7` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent8` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_SafetyEvent9` | なし | 安全イベントの内部項目。番号ごとの故障内容・ビット割当・カウント方式は未確定。 | unknown |
| `last_value_ServiceOption` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_TemperatureSamples` | なし | 平均温度等のサンプル数らしい値。1秒ごとの測定数とは限らない。 | inferred-name |
| `last_value_TimeAbove95Perc` | なし | 95%超の滞在を示すと考えられる値。単位・リセット条件は未確定。 | inferred-name |
| `last_value_TotalOperatingTime` | あり | LifetimeDataの稼働時間。端末購入後の利用時間・画面オン時間とは扱わない。 | partial |
| `last_value_UpdateTime` | なし | 元データの更新時刻らしい内部値。UNIX秒解釈による比較は参考値に留める。 | partial |
| `last_value_WeekMfd` | なし | 製造週らしい内部符号。年週のビット割当・日付変換は未確定。 | inferred-name |
| `last_value_WeightedRa` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_Wom_1` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_Wom_2` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_batteryServiceFlags` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_calibrationFlags` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
| `last_value_xFlags` | なし | 内部項目。名前以外に意味を確定する証拠は未取得。 | unknown |
