# Meilog — 勉強会で会った人を記録する名刺交換アプリ

iOS ネイティブ（SwiftUI）、自前 MVI、サーバーなし。AirDrop でカードを交換する。
設計の全体像は下の design.md に書いてある。判断に迷ったら必ずそこに戻ること。

@docs/design.md

交換フォーマットの仕様は `docs/card-payload.md`。`Payload/` 配下を触る前に必ず読むこと。

## コマンド

- 初回セットアップ: `./scripts/bootstrap.sh`（XcodeGen の導入、プロジェクト生成、Core のテスト）
- Xcode プロジェクト生成: `make generate`
- Core のテスト（シミュレータ不要・最優先で回す）: `make test-core`
- アプリのビルド確認: `make build`

## Xcode プロジェクトは生成物

- `Meishi.xcodeproj` は XcodeGen の生成物で git 管理外。**直接編集しない**
- ビルド設定、Info.plist のキー、ターゲットやパッケージの追加は `project.yml` を編集してから `make generate`
- アプリ側に新しいファイルやフォルダを追加したら `make generate` を実行する
- 空のフォルダや `.gitkeep` は作らない（XcodeGen がリソースとして取り込んでしまう）

## ファイルの置き場所

```
MeilogApp/                  アプリターゲット（Swift 6 言語モード）
├── Views/                  SwiftUI の View
├── Stores/                 @MainActor @Observable の Store。Effect の実行
├── Infrastructure/         SwiftData の実装
├── Transfer/               AirDrop 送受信、カスタム UTType
├── DesignSystem/           デザイントークン（Space, Typography, Colors, Palette, Radius, Shadow）
└── Assets.xcassets/        カラーセット、AppIcon
Packages/MeilogCore/        Swift Package（Swift 6 言語モード）
└── Sources/MeilogCore/
    ├── Model/              Card, CardStyle, MeetupEvent, Meeting, Encounter ...
    ├── Feature/            State / Intent / Effect / reduce
    ├── Port/               Repository などの protocol
    └── Payload/            CardPayload（encode / decode）
docs/                       design.md, card-payload.md, design-system.md
```

## MeishiCore の絶対ルール

- `import Foundation` 以外を書かない（SwiftUI, UIKit, SwiftData, Combine 等は禁止）
- `Package.swift` の `dependencies` は空のまま。外部ライブラリを足さない
- `Color` や `Image` を持たない。色や模様は `paletteID` のような数値で持ち、描画への変換はアプリ側
- 永続化は `Port/` の protocol として定義し、実装はアプリ側 `Infrastructure/`
- `public` は必要最小限。内部実装は `internal`

## MVI の規約

- 機能ごとに `XxxState` / `XxxIntent` / `XxxEffect` と `reduce(_:_:) -> (XxxState, [XxxEffect])` を Core に置く
- `reduce` は純粋関数。`async`、`throws`、`Date()`、`UUID()`、乱数を中で呼ばない
  - 現在時刻と新しい ID は Intent の引数で渡す（例: `.cardReceived(envelope, now: Date, newID: UUID)`）
- 副作用は Effect の enum（データ）として返すだけ。実行はアプリ側の Store
- Store は `XxxStore`、入口は `send(_ intent:)` ひとつ。`state` は `private(set)`
- フォーム中心の画面（自分のカード編集、デザイン調整、設定）は素直な `@Observable` + Binding でよい。ただしビジネスロジックは Core の関数を呼ぶ

## テスト

- Swift Testing（`import Testing`、`@Test`、`#expect`）を使う
- `reduce` のテストは振る舞いの仕様書として書く。テスト名は日本語で振る舞いを表す（例: `同じ人を再度読んだら再会として記録される`）
- Intent を追加したら、最低1つテストを追加する
- `CardPayload` は往復テストと、`docs/card-payload.md` のゴールデンベクタの decode テストを必ず持つ
- Core を変更したら `make test-core` が通ることを確認してから完了とする

## デザインシステムの規約

詳細は `docs/design-system.md` を参照。

- **View 内で数値リテラルを直接書かない**。スペーシングは `Space` enum、角丸は `Radius` enum を使う
- **16進数や `Color(red:green:blue:)` を直接書かない**。`Colors` enum か Assets.xcassets のカラーセットを使う
- **固定サイズのフォントを使わない**。`Typography` enum で定義された Dynamic Type 対応のフォントを使う
- **カード配色は `Palette` に集約する**。未知の paletteID は 0 番にフォールバック
- **画面の左右マージンは `Space.md`（16pt）に統一する**
- **タップ領域は最小 44×44pt を確保する**。アイコンのみのボタンには `accessibilityLabel` を必ず付ける
- **文字と背景のコントラストは 4.5:1 以上を満たす**こと

## 作業の進め方

- design.md の「作る順番」に沿って、1ステップずつ進める。各ステップの終わりで止まって、何をしたかと次にやることを報告する
- ステップ 1〜3 は UI なしで完結させる。テストが通るまで次に進まない
- 設計を変えたくなったら、実装する前に提案して確認を取る。合意したら design.md も更新する

## やらないこと

- 外部ライブラリの追加（TCA、KMP を含む）
- サーバー、ドメイン、Universal Link、Web ページ
- 特別な権限の要求（カメラ、連絡先、位置情報、ローカルネットワークなど）
- `Meishi.xcodeproj` の直接編集
- Concurrency の警告を `@preconcurrency` や `nonisolated(unsafe)` で黙らせること（直せないときは相談する）

## 未設定の項目（人間が埋める）

- `project.yml` の `PRODUCT_BUNDLE_IDENTIFIER` と `DEVELOPMENT_TEAM`（TODO コメントあり）。本番の値を最初から使う方針
