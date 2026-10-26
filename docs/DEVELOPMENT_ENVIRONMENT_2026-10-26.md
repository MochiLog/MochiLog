# Mac Studioへの開発環境移行確認（2026-10-26）

## 開発機とXcode

- Mac Studio / Apple M5 Max（18コア）/ RAM 64GB / SSD 2TB。
- macOS 27.2（26B118）。確認終了時のデータボリューム空きは約1.4TiB。
- Xcodes CLIでXcode 27.2 RC（27B48）を導入し、初回共通コンポーネントの設定を完了。`xcode-select` と `xcodebuild -version` で既定の切替を確認。
- ユーザー指定により旧Xcode 27.2 Beta 2を削除。Xcode 27.1（27A9275）は保持。
- 通常端末用iOS 27.2 RC（24B114）、Duo用iOS 27.2（24B91016s）、watchOS 27.2 RC（24S116）のランタイムを導入。iOS 27.0とDuo用27.1も再利用用に保持。
- iPhone 17・iPad Pro 13-inch M4・iPhone Duoの専用シミュレーターを作成。追加ランタイムの導入中に通常27.2のマウント・登録が一時的に不整合になったため、元のAppleアセットを保持して再登録し、現在ユーザーのCoreSimulatorを再起動。iPhone・iPadの再起動を確認した。
- 最終確認ではiPhone 17とiPad Pro M4の実機も`devicectl`で接続・詳細取得できた。実機が返したOSは両方27.0.1（24A446）、Developer Modeは有効。27.2 RCでテストしたのはシミュレーターであり、今回実機のOSは変更していない。

以前の低容量Mac向け制限は現在の機体には適用しない。[資源管理方針](LOCAL_DEVELOPMENT_RESOURCES.md)も更新した。今回のXcodeビルドは6〜8ジョブ、Rustは8ジョブを使用した。

## ツール

| 対象 | 確認内容 |
| --- | --- |
| Ruby / Bundler | 4.0.9 / 4.0.23。JWT・OpenSSLの読み込み成功 |
| fastlane | 2.241.1。Homebrewの独立環境で起動可能 |
| Python | コレクターの既存Nuitka環境はHomebrew Python 3.13.18。`pip check`成功 |
| Python既定値 | pyenv 3.13.5。コレクターを再構築するときは既存方針に従いHomebrew版を明示する |
| Node / pnpm | Node 24.13.0。Corepackのpnpmを有効化し、Webリポジトリ指定の10.27.0を使用 |
| Rust | Apple Silicon/iOS/シミュレーター用ターゲットを確認。診断XCFrameworkを再構築 |
| XcodeGen | 2.46.0 |
| GitHub | `gh`認証、mainへのpush dry-runを確認 |
| .NET / Windows | Mac側.NET SDK起動、Windows PCへのSSHと同PCの.NET SDKを確認 |
| Tailscale | このMacで接続中であることを確認 |

## 検証結果

| 対象 | 結果 |
| --- | --- |
| iOSネイティブ診断ライブラリ | 実機arm64・シミュレーターarm64/x86_64のXCFramework生成成功 |
| iOSアプリ / Xcode 27.2 RC | Debugビルド、移行処理の10テストが成功 |
| iPhone 17 / iPad Pro M4、27.2 RC | 現在のバッテリーの表示・横向き・オンオフ、翻訳済み記録の共有画面を各2テスト、計4実行で成功 |
| iPhone Duo、27.2 | 実際のDuoシミュレーターで詳細画面の回転・共有を1テスト実行し成功 |
| App Store署名 | 4.1.0（1064）のReleaseアーカイブ成功。アプリ・共有拡張・Watch同梱版の署名を作成し、アーカイブ全体の`codesign --verify --deep --strict`成功 |
| Macアプリ | Xcode 27.1と27.2 RCでDebugビルド成功 |
| Mac通信 | 既存の暗号化・再送防止・ACK・複数端末・保管庫・診断交換の回帰テスト成功 |
| コンパイル済みコレクター | 既存Nuitka成果物の自己検証成功。pymobiledevice3 11.19.1、TLS・暗号化・型付きplist等を確認 |
| Developer ID | 検証用の小さな実行ファイルで、実際の署名・厳格な検証・実行に成功 |
| Web | 固定依存インストール、型チェック、Wranglerの配布dry-run成功。Chromiumを導入しPlaywright 15テスト成功 |

Windowsのネイティブ回帰テストをMacで実行すると、Windows専用DPAPIの利用箇所で`PlatformNotSupportedException`になる。これはMac上での実行制限であり、Windows向けの保護を変更しない。今回Windows実機上での全ビルド・全テストは再実行していない。

## 移行後に調整したもの

- Macの生成済みローカルXcodeプロジェクトが古く、新しい型を含むファイルが不足していた。既存の`project.yml`から`xcodegen generate --spec project.yml`で再生成して解決。製品ソースの修正は不要だった。
- Webのpnpmがプロジェクト指定版と異なっていたため、Corepackのshimを有効化して指定版を使う状態にした。
- 環境確認用のMacビルドは`.noindex`配下に置く。検証用アプリをLaunch Servicesから解除し、旧検証用DerivedDataを整理した。実際のインストール済みアプリ、ペアリング、保管庫、履歴は保持した。

## このMacにインストールしたMochiLog Mac

`/Applications/MochiLog Mac.app`の1.0.0（38）は、[GitHubの正式配布版v1.0.0](https://github.com/MochiLog/MochiLog-Mac/releases/tag/v1.0.0)と一致していた。公式DMGを取得し、GitHubのSHA-256・公開チェックサム・署名のCDHashの一致、アプリの厳格な署名検証と公証チケット検証を実施した。

実際の配布版を起動。最初の起動ではBonjour登録が`ServiceNotRunning`になったが、OSのBonjour検索自体は動作しており、アプリ再起動後にiPhoneとiPadの現在のバッテリー情報を表示できた。OSのDNS設定や保護機能は変更していない。開発ビルドで置き換えたり、ペアリングし直したりはしていない。

## 計測と残した成果物

この作業中の実行時間は、移行テストを含むiOS Debugビルドが112.82秒、iPhone/iPadのUI確認が137.19秒、署名付きReleaseアーカイブが72.85秒、DuoのUI確認が31.02秒、Xcode 27.2 RCでのMac Debugビルドが15.73秒。依存解決や同じ作業内で生成したキャッシュを使っており、完全なコールドビルドの比較値ではない。

ローカルのログ、xcresult、署名付きアーカイブ、配布物の照合結果はGit管理外の`build/development-environment-2026-10-26/`に保存した。診断情報、実機情報、認証情報は公開リポジトリに含めない。新規公証申請、TestFlight・App Store・GitHub Releaseへの再配布は行っていない。追加依頼による実機アプリの更新は次項に記録する。

## 追加確認：iPhone・iPadへのインストール

ユーザーの追加依頼により、同じmainの製品ソースをXcode 27.2 RCでDebugビルドし、Apple Development署名でiPhone 17とiPad Pro M4へ上書きインストールした。4.0.0（1060）から4.1.0（1064）へ更新し、インストール後のアプリ情報でも両方1064であることを確認。アンインストールや端末OSの更新は行っていない。

更新前にアプリを停止し、App Group内のデータベースとWAL・SHM、およびアプリの設定をローカルの非公開バックアップへコピーした。両端末で起動・プロセスの継続動作を確認し、再度停止して一貫した比較用スナップショットを取得後、通常起動へ戻した。更新前の全recordIDと、iCloud同期・モバイル通信・自動取得・言語・バッテリータブ等の主要設定が保持されていた。10月25日・26日のiPhone・Watch・iPadの新規ログも追加され、両端末のrecordID集合が一致した。

実機向けビルドは18.84秒、インストールはiPhoneが10.53秒、iPadが2.56秒。同じ作業内のキャッシュを使った値。非公開のバックアップ・インストール結果・起動結果・比較結果は`build/development-environment-2026-10-26/device-install/`に保存し、公開しない。
