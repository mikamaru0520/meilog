# Meilog

勉強会やもくもく会で会った人を記録する名刺交換アプリ（iOS）

**開発中です。** 現在、モデル定義とQR交換フォーマットの実装が完了しています。

<!-- スクリーンショットを後で追加 -->

## できること

- **QRコードで交換（オフライン）** — サーバー不要。QRコードを読み取るだけで名刺を交換できます
- **勉強会の自動記録** — QRにイベント情報を入れておくと、会った記録に自動で紐付きます
- **再会の記録** — 同じ人と何度も会うと、会った履歴が残ります
- **あとで整理** — 同じ日にまとめて受け取った名刺を、後からイベントに割り当てられます
- **アイコン交換** — MultipeerConnectivityで近くの相手とアイコン画像を交換します
- **カードデザイン** — パレットとパターンIDで、全員のカードが違って見えます

## プライバシー

- **データは端末内のみ** — サーバーに送信しません。すべてのデータは端末内で完結します
- **アカウントなし** — ログインやアカウント登録は不要です
- **通信は最小限** — QRコードの読み取りと、ローカルネットワークでのアイコン画像交換のみ
- **必要な権限** — カメラ（QR読み取り）、ローカルネットワーク（画像交換）のみ

ソースコードを公開しているので、実際の動作を確認できます。これが公開している理由のひとつです。

## 動作環境

- iOS 18.0 以降
- 交換相手もこのアプリが必要です

## 開発

### 必要なもの

- Xcode 16 以降
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（Homebrewで導入できます）

### セットアップ

```sh
git clone https://github.com/<your-account>/meilog.git
cd meilog
./scripts/bootstrap.sh   # XcodeGenの導入、プロジェクト生成、テスト
```

`Meilog.xcodeproj` は `project.yml` から生成されます（git管理外）。直接編集せず、`project.yml` を編集してから `make generate` してください。

実機でビルドする場合は、`project.yml` の以下を変更してください（秘密情報は不要です）：

- `DEVELOPMENT_TEAM`: Apple DeveloperのTeam ID
- `PRODUCT_BUNDLE_IDENTIFIER`: 本番のバンドルID

### コマンド

| コマンド | 説明 |
|---------|------|
| `make generate` | Xcodeプロジェクトを生成 |
| `make test-core` | MeilogCoreのテスト（シミュレータ不要） |
| `make build` | アプリをビルド |
| `make open` | Xcodeで開く |

### 構成

```
MeilogApp/          SwiftUIのアプリ（Swift 5モード）
Packages/MeilogCore/   ビジネスロジック（Swift 6モード、import Foundationのみ）
  ├── Model/        Card, Encounter, MeetupEvent など
  ├── Payload/      QRのencode/decode
  ├── Feature/      State, Intent, Effect, reduce（予定）
  └── Port/         Repository などのprotocol（予定）
docs/               設計と仕様
```

詳細は以下を参照してください：

- [`docs/design.md`](docs/design.md) — 設計と技術方針
- [`docs/card-payload.md`](docs/card-payload.md) — QR交換フォーマット仕様
- [`CLAUDE.md`](CLAUDE.md) — Claude Code向けの作業ルール

## コントリビュート

IssueやPull Requestを歓迎します。

### Pull Requestの条件

- `make test-core` が通ること
- `MeilogCore` に `import Foundation` 以外を入れないこと
- `reduce` を変更したらテストを追加すること
- テストデータに実在の人の情報を使わないこと
- 秘密情報（Team IDやバンドルIDなど）をコミットしないこと
- 大きな変更は先にIssueで相談してください

送られたコードはMITライセンスで公開されます。開発には [`CLAUDE.md`](CLAUDE.md) を参照してください。

## セキュリティ

- QRコードの仕様（[`docs/card-payload.md`](docs/card-payload.md)）は公開されているため、誰でもQRコードを作成できます
- `CardPayload.decode` はサイズ・文字数・型をすべて検証し、不正なデータを受け付けません

脆弱性を発見した場合は、公開Issueではなく、GitHubの **Private vulnerability reporting** から報告してください。

## ライセンス

コードはMITライセンスです。著作権表示を残せば、商用利用・改変・再配布を含めて自由に使えます。

ただし、以下はライセンスの対象外です：

- アプリ名「Meilog」
- アイコン
- ロゴ

フォークして公開する場合は、別の名前とアイコンを使用してください。

詳細は [`LICENSE`](LICENSE) を参照してください。
