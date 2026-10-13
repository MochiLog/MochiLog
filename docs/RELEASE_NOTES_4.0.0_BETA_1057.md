# MochiLog 4.0.0 beta (1057)

## 日本語

MochiLog 4.0.0 ベータ (1057)

PC連携の診断接続先の更新を改善しました。Wi-Fi／Ethernetの現在のLANアドレスを既存の暗号化通信内で知らせ、転送元IPとAppleの診断先がVPNなどで異なる場合にも対応PCが正しい候補を試せるようにします。通知は端末ごとの既存ペアリングと再送防止検査で保護されます。

対応版はMochiLog Mac 0.2.29／MochiLog Windows 0.1.27です。再ペアリングは不要で、片側だけ更新した場合も従来の通信を継続できます。新しい候補通知は両側更新後に利用されます。

PC版では取得失敗・再試行待ち・再確認待ちを完了扱いにせず、件数を表示します。IP変更、候補の由来、認証、待機を動作ログへ記録します。PCの現行のバッテリー表示にも新しい接続先候補を利用します。

ログの解析と記録はスマホ側で行い、PCへパーサーは追加していません。収集中は端末のロック解除が必要です。ログ未生成、解析共有オフ、OSの読み取り制限、切断のすべてを解消する更新ではありません。問題があれば、発生日時を指定して両側の診断ログをサポートへ添付してください。

## English

MochiLog 4.0.0 beta (1057)

PC pairing now sends current Wi-Fi/Ethernet LAN address hints inside the existing encrypted request. Updated companions can try the correct diagnostic endpoint when a VPN or translated connection makes the transfer peer address different from the Apple diagnostic address. Hints remain scoped to the authenticated physical device and protected by replay checks.

Use MochiLog Mac 0.2.29 or MochiLog Windows 0.1.27. Existing pairings do not need to be recreated. Updating only one side preserves previous communication; both sides need the update to use the new address hints.

Companions no longer mark failed downloads, retry waiting or deferred classification as completed acquisition. Waiting counts are displayed, with endpoint provenance, changes, authentication and waiting recorded in activity logs. Current battery queries also use these endpoint candidates.

Parsing and recording remain on mobile; no PC battery-log parser was added. Devices must be unlocked for log collection. This update does not remove missing-log, disabled Analytics sharing, OS access restrictions or connectivity limitations. For issues, select the occurrence date and attach diagnostics from both sides through support.
