# Mac連携ベータ: 個体IDと重複処理

MochiLog Macは[専用リポジトリ](https://github.com/MochiLog/MochiLog-Mac)で管理する。ベータの対象はiOS/iPadOS 27とmacOS 27。MochiLog本体のiOS 16対応は継続する。

- MacはOSの信頼済みUDIDでログの出所を区別し、端末ごとにランダムな`physicalDeviceID`を保持する。UDID自体はiCloud・iPhoneへの転送・エクスポートへ含めない。
- iPhoneはQRでMacの個体IDと共有秘密鍵を受け取り、Keychainへ保存する。再インストール後も同じMacと再ペアリングすると同じ個体IDを回復できる。同期オフ中の履歴消失はこの機能では復旧しない。
- 新しい記録には任意の`physicalDeviceID`を持たせる。旧記録はnilのままとし、機種名だけで既存履歴を一括統合しない。iCloud同期とYAMLエクスポート/インポートはIDを保持する。
- 手動取り込みの出所は機種名だけでは証明できないため、初期設定では個体IDを付けない。利用者が「同じ機種の手動ログをこの端末として記録」をオンにした場合に限り、現在の端末と機種が一致する新規記録にIDを付ける。
- Macから受信したログは、端末IDと日付で既存記録を確認する。同じファイルがIDなし旧記録として保存済みなら、日付・充放電回数・公称容量・生容量の一致で重複扱いにする。同じ機種・同じ日だけの一致は確認待ちとし、別個体の可能性を残す。
- Macは受信確認後に転送済みファイル名を永続化する。iCloud同期とMac転送が競合して完全一致のID付きレコードが二つ入った場合は、SwiftDataの更新時に一方へ収束させる。
- ペアリング済みApple WatchのAnalyticsはiPhoneの`ProxiedDevice-…/Retired`から取得する。iPhone本体の`/Retired`と取得元別に保存し、同日・同名のファイルがあっても衝突させない。ファイル先頭の`os_version`が`Watch OS`のログだけをWatch側に振り分ける。iPhone本体のログにもWatchの機種名が現れるため、本文にWatch名があるだけでは判定しない。
- WatchログにはiPhoneの`physicalDeviceID`を付けない。Watch自体の安定した個体IDとの対応はまだ確認できていないため、誤った紐付けを防ぐ。

初回OSペアリングには端末のデベロッパモードと「ペアリング済みMac」での6桁コード入力が必要。検証機ではペアリング後にデベロッパモードをオフにしてもWi-FiでAnalyticsを取得できた。使用者にPythonやXcodeをインストールさせず、署名済みDMGへ収集ツールを同梱する。

## 残る検証

- クリーンなmacOS 27環境（Xcodeなし）でのOSペアリングとログ収集。
- MacとiPhoneのQRペアリングから暗号化転送、iPhone側の解析・保存までの実機通し試験。
- CloudKitが両端末へ同時に流入したときの重複収束。
- 公証とGatekeeper通過、およびIntel Macでの配布物互換性。
