# 4.1.1 配信・取り込み監査（2026-11-18）

## 対象

4.1.1 (1071)をmainから作成し、同じ署名済みIPAをTestFlightとApp Storeへ提出する。
本体・共有拡張・Watchアプリの版とビルド番号を揃える。
新しい修正は[画面復元クラッシュの調査](crash-investigation-2026-11-18.md)を参照。

## 過去の取り込み確認

Apple APIで、正式配布4.1.0および内部・外部TestFlightの最新ビルドはいずれも1070と確認。
その提出元は`a3db7b0`。1070のローカル署名済みIPAと既存の検証記録を照合した。
今回の修正`4a71768`は1070配信後のコミットであり、1070には入っていない。
GitHubへのpushだけでは既存のApp Store/TestFlightバイナリは更新されない。

| 修正・開発内容 | main側コミット | 1070の提出元 | 1071候補 |
| --- | --- | --- | --- |
| PC転送の旧開発ブランチ | c2093b8 | 祖先として統合済み | 含む |
| iOS27・複数取り込みの旧開発ブランチ | 940d324 | 祖先として統合済み | 含む |
| TestFlight運用の旧開発ブランチ | f55a7df | 祖先として統合済み | 含む |
| ペアリング診断・分割ログ添付 | 00dbdb9 | 含む | 含む |
| タイムアウト経路・ZIP・権限設定の記録 | 200604e | 含む | 含む |
| 接続エラー案内 | 3eb81f0 | 含む | 含む |
| サポート書き出し失敗の案内 | dbf79c1 | 含む | 含む |
| 署名付き機種データ更新 | ee56833 | 含む | 含む |
| iPad参照容量の補正・移行 | 8822f80 | 含む | 含む |
| iPad mini A20 Pro | 2f373b5 | 含む | 含む |
| 旧・名前付き画面設定による復元対策（今回の経路には不十分） | ff6af98 | 含む | 維持した上で補完 |
| 古い画面状態を持つ更新後のクラッシュ | 4a71768 | 含まない | 含む |

release/4.0.1とrelease/4.0.2のmain非祖先コミットも確認した。
4.0.2からmainへ取り込んだ実装はrange-diffで対応し、ペアリング修正の
`3a049c3`と`00dbdb9`は文書差分を除いた実装・テストのpatch-idが一致する。
他の不一致は版番号・提出用メタデータ・履歴文書であり、修正実装の取り込み漏れではない。
4.0.2 (1069)はユーザー指示で廃止済み。これを再配布しない。

`archive-icloud-diagnostics-20260919`の`bd8094e`は保存目的の診断WIPで、
完成した修正として配布対象にする指示はない。未完成の診断コードは混入させない。
今回確認した参照・記録以外の未記録作業まで調査済みとは扱わない。

## 配信前チェック

- 実際の解析ログ取り込み、共有、更新後の起動・背景化・復帰を確認。
- 確定したソースコミットから署名付きRelease archiveを作成。
- IPA内の全3バンドルの版・番号、配布署名、Production CloudKit、テスト混入なしを検証。
- IPA本体で新しい起動型が存在することと、dSYMのUUID一致を確認。
- AppleのVALID状態と内部・外部TestFlightの実際の配布状態を確認。
- ストアも同じ1071を選び、日英ノートとiPhone/iPad/Duo内外/Watch画像・ヘッダー・検索画像を検証して提出。

この記録の配信結果は、各処理の完了後に追記する。審査待ちと公開済みを区別する。

## 完了したローカル検証

- 配布元ソース：`f0e490f0b8b744c54e760ee5ee162d56948f46ea`。
- Xcode 27.2 RCで署名付きRelease archiveとIPAを書き出した。本体・共有拡張・Watchとも4.1.1 (1071)。
- IPA：16,372,924 bytes。SHA-256：`b6cedfa3799ce47e8b5f2f1df5052cc55b8092399406218fa4167a1b9636bbe4`。
- deep/strict署名、配布用profile、get-task-allowなし、Production CloudKit、App Group、テストバンドル非混入を確認。3バンドルのdSYM UUIDがIPAの実行ファイルと一致。
- IPAの文字列から`MochiLogApplication`と新しい画面所有方式の診断マーカーを確認。最初の検査に使ったnmでは配布時に除去された非公開シンボルが見えないため、実バイナリの型メタデータ・マーカーと対応dSYMを照合した。
- 取り込みキュー、8ファイル共有インボックス、実パーサー、ペアリング/サポート、署名付きカタログの5スイート成功。
- 4.1.1の実アプリで、iPhone/iPad各2件の合成解析ログをOSのファイルOpen In経路から取り込み、詳細表示と終了・再起動後の1件→2件の保持を確認。in-memoryの記録ではなく、iCloudを無効にした専用シミュレーターのローカルDBを使用。
- iPhone/iPad各3回の背景化・復帰と終了後の再起動も成功。UIテストは計4ケース成功。
- Device Hubで専用iPhoneシミュレーターを表示し、＋からファイル選択画面が開くことを目視確認した。ファイルピッカーのリモート画面は操作結果を追いにくいため、取り込みから保存までの判定は上記XCTestで行った。その後Macが再ロックされ、追加の目視操作は停止。実機データは変更していない。
- ストア4.1.1の両言語に、Duo内側4＋外側4、iPhone/iPad/Watch各4、ヘッダーと検索画像各1を登録し、順序と対象版を読み戻し確認。
- fastlaneのIPAアップロードは11:58 JSTに成功。Apple処理・TestFlightの公開状態とストア提出結果は次節に追記する。

署名済み配布物は上記ソースのままで、後続の追加テスト・配信記録のコミットはアプリ実装を変更しない。

## TestFlightとストア審査

- Apple処理はVALID、expired=false。内部のiOS16・iCloud同期の両グループで1071の配布を確認した。
- 外部mainグループへ同じ1071を割り当て、日英テストノート・自動通知を設定し、ベータ審査を提出した。確認時点はWAITING_FOR_BETA_REVIEWで、外部配布開始とは扱わない。
- 1070のストア／TestFlightにはff6af98の旧対策も含まれていたが、今回の復元経路には不十分だった。1070のIPAには新起動型と診断マーカーがなく、1071にはあることも照合した。
- 今回は内部TestFlight配布済み・実取り込み検証済みの1071で、外部ベータ審査とApp Reviewを並行して進める。提出ヘルパーの既定は従来どおり外部配布待ちのまま維持し、`ALLOW_INTERNAL_TESTFLIGHT_REVIEW=1`を明示したときだけ、同一ビルドの内部配布開始かつ外部ベータ審査提出済みを条件に提出を許可する。
- 未処理、内部配布不可、外部未提出・拒否・期限切れ、選択ビルド相違は引き続き拒否する。提出ガードの8テスト・33アサーションが成功。

## 最終確認

- ストア4.1.1は**WAITING_FOR_REVIEW**、選択ビルドは**1071 / VALID / expired=false**。`releaseType=AFTER_APPROVAL`で、承認後に自動公開する。
- 内部TestFlightは**IN_BETA_TESTING**、外部は**WAITING_FOR_BETA_REVIEW**。ストアもTestFlightも同じApple build IDの1071を使用する。旧ビルドを追加で期限切れにはしていない。
- CIのTestFlight/ストア/画像登録の既定値に古い4.0.1・4.1.0が残っていたため、4.1.1 (1071)へ揃えた。今回の実行は常に対象版・ビルドを明示しており、この既定値による誤送信はない。
- mainへのコミット・pushと配布バイナリ作成は別工程。今後も版・ビルド・ソース・IPA SHA-256・Apple側の選択ビルドと配布状態を照合して完了とする。

## 配信後のブランチ整理

取り込み監査で旧リリース枝の実装がmainにあることを確認し、次の注釈タグをoriginへpushして元の先端を読み戻した。その後、期待する先端を指定したlease付きでoriginの2枝を削除し、ローカルの2枝も削除した。

| 旧ブランチ | 復元用タグ | 保持した先端 |
| --- | --- | --- |
| release/4.0.1 | archive-release-4.0.1-20261118 | a0af4ed |
| release/4.0.2 | archive-release-4.0.2-20261118 | f3a7cc2 |

ローカル・originとも作業ブランチはmainのみ。旧4.0.2の作業ツリーは同じ先端のdetached HEADへ切り替え、既存のファイルを消去していない。既存のiCloud診断WIP保存タグも維持した。

最終のApple応答、署名検証、UI結果、API応答はGit管理外の`Build/release-4.1.1/`へ保管する。公開しているのは匿名化した検証結果だけで、認証情報や実機の生データは含めない。

## 同日追加修正・1073への差し替え

追加調査と利用者の指示により、最終候補を4.1.1 (1073)へ更新した。
1071までの上記履歴を上書きせず、追加分は[同日の追加調査](BUG_INVESTIGATION_2026-11-18.md)へ記録する。

- 1073の配布元は`f2cc4362855a1d479648aad90a2f19391131a374`。本体・共有拡張・Watchをすべて1073へ揃えた。
- 巨大な任意RAM値・Watch表示値によるクラッシュ、アクセシビリティ文字の案内レイアウト、未設定での自動取得有効化とファイル選択の案内を含む。
- iPhone・iPadそれぞれ8言語で警告・取消・設定への遷移・ファイル選択条件のUI試験に成功。iPadは説明行をスクロールして確認し、未生成の画面外行を誤判定しないよう試験を補正した。
- IPAは16,398,599 bytes。SHA-256は`db52a61b64275398774490e1ac6e45caaebbe27923d7450a41eba2e26d33fabc`。署名・Production CloudKit・3バンドルの版・dSYM一致を検証。
- Apple build IDは`ebcd1f30-5adc-457a-975a-6a1af0a22657`。VALID、expired=false。内部TestFlightはIN_BETA_TESTING、外部mainへ割り当て・日英ノート・自動通知を設定し、外部審査はWAITING_FOR_BETA_REVIEW。
- 旧1071のベータ審査が残り、AppleがANOTHER_BUILD_IN_REVIEWで1073を拒否した。APIによる審査削除は許可されなかったため、置き換える1071だけを試験停止して審査を解消した。1070以前や1072をまとめて期限切れにする操作はしていない。
- 1072は追加UI指示前の候補としてアップロードされたが、ストアにも外部審査にも選択していない。1073のストア・TestFlightは同じバイナリである。
- ストア1071の提出を取り下げ、日英ノートと選択ビルドを1073へ更新した。Duo内外・iPhone・iPad・Watch・ヘッダー・検索の全44画像を再照合した。
- 新しいApp Review submissionは`6d1da4d6-f1ac-47b2-8e26-71a25ed5a072`。ストアはWAITING_FOR_REVIEW、releaseTypeはAFTER_APPROVAL。外部審査待ち・ストア審査待ちを公開済みとは扱わない。
- 今回も新しい作業ブランチは作らずmainへコミット・pushした。既存の無関係な未コミット変更は保持した。

1073の署名・UI結果・Apple応答はGit管理外の`Build/release-4.1.1-1073/`と`Build/bug-investigation-2026-11-18/`へ保存した。


## PC stability and permission guidance — build 1074

The latest replacement is 4.1.1 (1074), built from `702cf833a4cc699b0d90911fc179541b7ca22cd4` with Xcode 27.2 RC. It includes the PC recovery and permission guidance in [the stability investigation](PC_LINK_STABILITY_2026-11-18.md). The app, share extension and Watch app all report 1074. Release signature, Production CloudKit, non-debuggable distribution profiles, eight-language permission strings, dSYM UUIDs and absence of simulator-only fixtures passed. IPA SHA-256: `e655a0aae739855049cad214ff11b3293dcf319675fec15ec791b868e7fa3454` (16,442,514 bytes).

Apple build ID: `626133b8-57d7-4ba1-8a0b-7559a0a864e6`; VALID, expired=false. Internal TestFlight is IN_BETA_TESTING. The same build is assigned to the existing external main group with Japanese/English notes and automatic notification; external review is WAITING_FOR_BETA_REVIEW.

Apple rejected simultaneous beta review because 1073 was still pending. After confirming 1074 was VALID and assigned, only replaced build 1073 was stopped. Other earlier builds were left unchanged. App Review for 1073 was withdrawn, the selected build and localized notes were changed to 1074, and all 44 store images were verified again (including Duo inside/outside, header and search images). Submission `8c67c965-c3de-48f5-9a00-67750339c59e` is WAITING_FOR_REVIEW, release type AFTER_APPROVAL. Neither pending external review nor App Review is described as public distribution.

Private verification and Apple responses are under ignored `Build/release-4.1.1-1074/`. Physical denial/grant of the OS local-network permission was not tested on real devices; permission presentation was tested in the simulator using explicit DEBUG-only states, as documented in the stability investigation.
