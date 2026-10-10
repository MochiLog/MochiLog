# 端末内取得の進捗とバックグラウンド継続

2026-10-10 / 4.0.0 beta 1046。iPhoneとiPadで同じ実装を使用する。

## 処理

- `LocalDiagnosticsTransport.logs` は接続、一覧、ファイル読み取り、取り込み準備を通知する。ファイル数、AFCのサイズ情報、読み取り済みバイト数を使う。未知のサイズは無理に百分率にしない。
- 全画面共通の上部に1行の状態表示を置き、タップで詳細を同じ領域に展開する。設定内の重複カードと追加モーダルを使わず、TabViewの外側のVStackで実際の高さを確保し、ナビゲーション／iPadの上部タブと重ならないようにする。safeAreaInsetだけではネイティブのナビゲーションバーが移動しなかったため、使用しない。詳細で経過時間と進捗を表示。一時停止は次のネイティブ読み取り境界で効く。FFIのクライアントを別スレッドから解放しない。
- 完了したファイルごとに、形式・電池項目・OS種別を確認して保護された一時領域へatomic保存する。サイズが得られた場合はEOF時に一致を確認する。途中のファイルは公開しない。
- 再開時は完成済みファイルを再取得しない。既存の個体ID・ハッシュ・共有取り込みキューを使う。成功した記録のみ受領済みにし、生ファイルを削除する。失敗・中断したファイルは再試行する。
- Censusとsessionは電池ログ候補から除外する。既存の短いファイル・電池項目・OS判定も維持する。

## OSの時間予算

手動操作にはiOS/iPadOS 26以降の `BGContinuedProcessingTask` を使用する。27では非同期提出、26では従来の提出API。Info.plistの許可されたワイルドカードに属する一意なIDを要求ごとに発行し、完成したIDをハンドラー登録と要求の両方に使用する。ワイルドカード文字列そのもののハンドラー登録は実機で失敗したため使用しない。遅れて届いた旧タスクを現在の収集へ結び付けない。即時開始できない場合は短時間の `UIApplication.beginBackgroundTask` にフォールバックする。

自動収集と17〜25では短時間のバックグラウンド予算を使用する。BGContinuedProcessingTaskの提出はユーザー操作に限定する。システムのキャンセル・期限切れはトークンへ伝播し、完了ファイルを保持する。アプリの強制終了後に同じ処理が動き続けることは保証しない。VPN・OS診断サービス・ファイル保護も継続の条件になる。

現在のバッテリー情報取得は引き続き別ループ。バックグラウンド移行時にそのループを止め、進行中のログ取得のみ予算内で続ける。

## 検証

- Swiftの進捗計算とスレッド安全なキャンセルを `scripts/test-local-pairing.sh` で検証する。
- ネイティブTLS/AFCフィクスチャで段階通知、逐次ファイル公開、接続前キャンセル、読み取り中キャンセル時の未公開、完成済みファイルのキャンセル後保持を検証する。
- iPhone/iPadのUIテストで8言語のバナー・一時停止・再開・前面復帰を確認する。UIフィクスチャはDEBUGシミュレーター限定で、OSの背景時間予算そのものの成功を証明するものではない。
- 10月10日のiPad実機では設定変更・履歴追加を行わない読み取り専用試験で、電池情報6主要項目/363詳細項目、既存の本体電池ログ4件を取得。約38秒を要した。今日の生成は解析共有がオフだったため確認できていない。

公式仕様: [長時間タスク](https://developer.apple.com/documentation/BackgroundTasks/performing-long-running-tasks-on-ios-and-ipados)、[要求](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest)。

## iPad実機での継続確認（1045）

16:12:31に一意なIDを完全一致で登録した継続タスクをOSが受理。16:12:50にSafariへ切り替えてMochiLogを背景へ移し、16:13:04に本体電池ログ4件の読み取りが完了した。WatchはiPadにないため0件。試験はDEBUGの読み取り専用プローブで、完成ファイルは検証専用一時領域へ保存後に削除し、解析・記録は実行していない。受領済み一覧と3つの設定の前後ダイジェストは一致。構成済み端末での試験で、PCペアリング・端末内OSペアリングを書き換える経路は使用していない。Keychain全体のダイジェスト比較は行っていない。通常起動へ戻した。

この結果はiPadOS 27.2の継続APIと短時間の背景通信の確認。iPhone実機および17系実機の同じ条件、長時間ロック中、強制終了後の自動継続まで成功したことを意味しない。

## 1046の画面修正

1045のUI試験で、親VStackのaccessibilityIdentifierが子ボタンにも伝わり識別子を上書きすること、外側のsafeAreaInsetがTabView内部のナビゲーションバーを移動させないことを確認。進捗IDをProgressViewだけに付け、タブ画面を状態表示と縦に並べた。同じ配置だった個体情報の競合と完全重複の通知も領域を確保する。ナビゲーションと状態表示・進捗・一時停止のframe交差がないことをiPhone／iPad・8言語で検証する。1045は配布せず1046に置き換える。

### 1046のiPad実機確認

16:55:34に主要電池情報6項目／詳細363項目を読み取り、16:56:08に本体電池ログ4件の検証用チェックポイント保存が完了。16:56:09に通常収集へ戻り、履歴追加のない読み取り専用プローブを終了した。実機スクリーンショットでは、1行の状態表示がナビゲーション／追加ボタン／サイドバーと縦に並ぶ配置を確認。OSが表示する継続タスクの一時的な進捗通知はOS標準の表示。アプリは同じタイトルの詳細見出しと重複カードを取り除いた。通常起動へ戻している。

### 1046のiPhone／iPad自動検証

[UI検証 #15](https://github.com/MochiLog/MochiLog/actions/runs/38035951851) は成功。両端末で3つのUIテスト（8言語の自動ログ収集設定、8言語の進捗・一時停止・再開・前面復帰、現在の電池タブ切り替え）が全て成功した。進捗の折り畳み／展開／再開のスクリーンショットを各端末24枚保存し、日本語とドイツ語の配置も目視確認。状態表示・進捗・一時停止とナビゲーションが交差しないことをframeで確認した。

両端末のネイティブTLS/AFCフィクスチャは23項目が全て成功。段階通知、完成ファイルの逐次公開、読み取り前・途中のキャンセル、完成済みチェックポイントの保持、不正な信頼情報の拒否、同一ログの再取り込み抑止を含む。シミュレーターはiOS/iPadOS 27.0。17系ランタイムはCIにないため明示的にスキップし、17系実機のOSサービスや背景時間予算の証明とはしない。

[署名・アップロード](https://github.com/MochiLog/MochiLog/actions/runs/38035953865) と [Apple側の処理確認](https://github.com/MochiLog/MochiLog/actions/runs/38036809071) も成功し、4.0.0（1046）はVALID。検証・提出元は `78a4e1c`。以後の変更は開発メモのみ。

17:46に [TestFlight配布](https://github.com/MochiLog/MochiLog/actions/runs/38039050738) が成功。日本語・英語のノートを保存し、既存の内部2グループと外部 `main` グループへ設定。外部の状態は `IN_BETA_TESTING`、自動通知は有効。[GitHub beta 1046](https://github.com/MochiLog/MochiLog/releases/tag/v4.0.0-beta.1046) も公開した。iPad実機は1046、iPhoneはTestFlight環境を維持して配布対象へ更新した。iPhone実機の同じ背景試験が済んだという扱いにはしない。

## アプリを表示していない時の定期取得の調査（2026-10-10）

1046では、前面の5分ループと、前面で開始した収集の背景継続のみ実装済み。`updateActivity()` は前面のsceneを必要とし、背景移行後は現在の収集が終わればループが止まる。`BGAppRefreshTask`／`BGProcessingTask` でOSから起動して新たに収集する経路は未実装。前述のiPad実機試験は、OSによる定期起動を証明するものではない。

OSに背景実行の機会を要求する方式は追加候補になる。ただし[earliestBeginDate](https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate)は開始可能な最早時刻であり、時刻や間隔の保証ではない。[BGAppRefreshTask](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)は最大30秒の短い更新、[BGProcessingTask](https://developer.apple.com/documentation/backgroundtasks/bgprocessingtask)は端末がidleの時に行う処理。今回の実機取得は約38秒だったため、短い更新だけで全ファイルを取り切れるとは扱わない。完成ファイルごとのチェックポイントと次回再試行を使う必要がある。

別アプリのVPNは診断サービスまでの通信経路を提供する。VPNが動いていることはMochiLogプロセスの常時実行権限を意味しない。MochiLogは自分のPacket Tunnel Providerを持っておらず、別アプリの拡張内で自分の収集コードを実行できない。[Packet Tunnel Providerの公式説明](https://developer.apple.com/documentation/networkextension/nepackettunnelprovider)を参照。継続タスクはユーザー操作から開始するAPIなので、これをタイマーで常時延長する方法にはしない。

現状の資格情報は `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`、完成ファイルは `completeFileProtection`。ロック中のコールド起動では資格情報の読み込みや保存にも制約があり、自動収集のために保護クラスを変更してはいない。さらに[別途のロック中研究](mac-wireless-log-probe.md)では、再起動後に一度解除済みでもAnalytics本文のAFC OPENがPERM_DENIEDになった。これはPC発の研究結果であり、同じ条件の端末内VPN経路での実測ではないが、VPNや背景APIでOSのファイル権限を回避できる根拠にはならない。現在の電池スナップショットの成功と日次ログ本文の成功を区別する。

次の実証対象は「MochiLogを表示せず、端末がロック解除され、VPNが有効で、OSが背景実行を許可した時の取得」。起動・延期・VPN到達・資格情報利用可否・ファイル公開・期限切れ・日次完了による停止を記録し、前面収集と排他、途中ファイルの不採用、既存受領済み一覧を維持する。背景更新オフ・省電力・低頻度利用・強制終了を含めた自然なOS起動は実機の非デバッグ環境で測定する。シミュレーターやデバッガーによる強制起動は、その実行頻度の証明にしない。[Apple DTSの実行制限](https://developer.apple.com/forums/thread/685525)も参照。

結論は「条件が整った時にアプリ非表示でも試行する仕組みには実装の余地がある。ただし5分ごと・9時ちょうど・ロックしたまま毎日取得の保証は現時点では不可」。今回の調査ではランタイムの変更や追加配布は行っていない。
