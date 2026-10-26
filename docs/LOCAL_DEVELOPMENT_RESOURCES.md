# ローカル開発時の容量管理

2026-10-26からの開発機はMac Studio（M5 Max、RAM 64GB、SSD 2TB）。旧Mac向けの同時起動制限は適用しない。iPhone・iPad・Duoのシミュレーターを併用でき、ビルドは6〜8ジョブを目安に、実際のメモリプレッシャーと空き容量を見て調整する。通常の開発・環境確認に使う端末とランタイムは再利用する。

以下は撮影スクリプトと一時生成物の整理方針。新Macでも、他の作業のシミュレーター、実機データ、署名済み配布物をまとめて削除しない。

`scripts/capture-store-screenshots.py` は空き24GiB以上を確認し、スクリーンショット撮影後に `MochiLog Store ` 名の専用シミュレーターを削除する。iPad・Duoは撮影した段階で片付ける。Watchの撮影に必要なiPhoneだけは最後まで保持する。例外で終了したときにも終了処理で整理する。

作業開始前から起動済みだったシミュレーターは借用扱いとし、終了処理で削除・停止しない。`--keep-simulators` を明示した場合は停止だけ行い、追加撮影のために端末を残せる。保存した画像・撮影メタデータは削除しない。

実機向けDerivedDataと `Build/LocalDiagnostics/idevice.xcframework` は再利用する。完成済みライブラリ、配布ビルドのdSYM、端末の記録・ペアリング、診断履歴を容量整理の対象にしない。古い専用ビルド中間物や配布済みインストーラーの複製は、必要な検証結果を残して整理する。

詳細な運用方針は [Macリポジトリの開発資源メモ](https://github.com/MochiLog/MochiLog-Mac/blob/main/docs/LOCAL_DEVELOPMENT_RESOURCES.md) に記載する。
