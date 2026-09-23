# デザインシステム

Meilog のデザインシステム定義とガイドライン。

## 概要

デザインシステムは `MeilogApp/DesignSystem/` に配置されている。MeilogCore には一切入れない（Core は Foundation のみ）。

すべての UI コンポーネントは、このデザインシステムのトークンを使用すること。View 内で数値リテラルや16進数カラーを直接書かない。

## 1. スペーシング（8ptグリッド）

`Space` enum で定義されたスペーシングを使用する。

```swift
import Space

VStack(spacing: Space.md) {  // ✅ 正しい
    Text("Hello")
    Text("World")
}

VStack(spacing: 16) {  // ❌ 間違い - 数値リテラルを使わない
    Text("Hello")
}
```

### 定義

| トークン | 値 | 用途 |
|---------|---|------|
| `Space.xxs` | 4pt | アイコンと文字の間など、詰めたい箇所のみ |
| `Space.xs` | 8pt | 小さな要素間 |
| `Space.sm` | 12pt | 関連する要素間 |
| `Space.md` | 16pt | セクション内の要素間、**画面の左右マージン** |
| `Space.lg` | 24pt | セクション間 |
| `Space.xl` | 32pt | 大きなセクション間 |
| `Space.xxl` | 40pt | 画面上部の余白など |

### ガイドライン

- **画面の左右マージンは `.md`（16pt）に統一する**
- 基準は 8pt。4pt はアイコンと文字の間など、詰めたい箇所だけに使う

## 2. タイポグラフィ

`Typography` enum で役割ごとに定義されたフォントを使用する。

```swift
import Typography

Text("カード名")
    .font(Typography.cardName)  // ✅ 正しい

Text("カード名")
    .font(.system(size: 22))  // ❌ 間違い - 固定サイズを使わない
```

### 定義

| トークン | 定義 | 用途 |
|---------|-----|------|
| `Typography.cardName` | `.title2.bold()` | カード上の名前（大） |
| `Typography.cardTitle` | `.subheadline` | カード上の肩書き |
| `Typography.cardLink` | `.caption` | カード上のリンク |
| `Typography.sectionHeader` | `.headline` | セクションヘッダー |
| `Typography.fieldLabel` | `.subheadline` | フィールドラベル |
| `Typography.caption` | `.caption` | キャプション・説明文 |
| `Typography.body` | `.body` | 本文 |
| `Typography.button` | `.headline` | ボタンラベル |

### ガイドライン

- **Dynamic Type に必ず対応する**。固定 size の `.font(.system(size:))` は使わない
- カスタムフォントを使う場合も `.custom(_:size:relativeTo:)` で Dynamic Type に追従させる
- 本文相当は最低 15pt 以上。カード上の小さい文字も 11pt を下限にする

## 3. カラー

`Colors` enum で役割ベースのカラーを使用する。

```swift
import Colors

Text("テキスト")
    .foregroundStyle(Colors.textPrimary)  // ✅ 正しい

Text("テキスト")
    .foregroundStyle(Color(red: 0.1, green: 0.2, blue: 0.3))  // ❌ 間違い
```

### 定義

#### テキスト

- `Colors.textPrimary` - プライマリテキスト
- `Colors.textSecondary` - セカンダリテキスト（説明文など）
- `Colors.textTertiary` - ターシャリテキスト（補助情報）

#### 背景

- `Colors.background` - アプリ全体の背景
- `Colors.backgroundGrouped` - グループ化された背景（設定画面など）
- `Colors.surfaceBackground` - 面の背景（カード、モーダルなど）
- `Colors.surfaceBackgroundSecondary` - セカンダリ面の背景

#### その他

- `Colors.border` - 境界線
- `Colors.accent` - アクセントカラー（ブランドカラー）
- `Colors.destructive` - エラー・削除
- `Colors.success` - 成功
- `Colors.warning` - 警告

### ガイドライン

- **役割で命名する**（背景・面・文字・副次文字・境界・アクセント）。色名（green など）で命名しない
- **可能な範囲で iOS の semantic color を優先**し、ブランド色だけ独自に持つ
- **文字と背景のコントラストは 4.5:1 以上を満たすこと**

### カラーセット（Assets.xcassets）

カスタムカラーは `MeilogApp/Assets.xcassets` にカラーセットを作成し、ライト/ダーク両方を定義する。

- `AccentColor` - アクセントカラー（ブランドカラー）
- `SurfaceBackground` - 面の背景

## 4. カード配色（Palette）

カードの配色は `Palette` enum で定義する。

```swift
import Palette

let colors = Palette.colors(for: card.style.paletteID)
LinearGradient(colors: colors, ...)
```

### 定義

| ID | 名前 | 色 |
|----|-----|---|
| 0 | 朝霧 | ミント → オレンジ |
| 1 | 夕焼け | ピンク → オレンジ |
| 2 | 深海 | ブルー → インディゴ |
| 3 | 新緑 | グリーン → イエロー |
| 4 | 藤色 | パープル → ピンク |
| 5 | 墨 | ブラック → グレー |

### ガイドライン

- **未知の ID は 0 番（朝霧）にフォールバックする**
- カード配色を追加する場合は `Palette` に集約する

## 5. 形と影

### 角丸（Radius）

```swift
import Radius

RoundedRectangle(cornerRadius: Radius.card)  // ✅ 正しい

RoundedRectangle(cornerRadius: 16)  // ❌ 間違い
```

| トークン | 値 | 用途 |
|---------|---|------|
| `Radius.control` | 12pt | コントロール（ボタン、テキストフィールドなど） |
| `Radius.card` | 16pt | カード |
| `Radius.sheet` | 24pt | シート、モーダル |
| pill | 高さの半分 | 完全な角丸（`.clipShape(Capsule())` を使う） |

### 影（Shadow）

カード用の影は1種類だけ定義。多用しない。

```swift
import Shadow

RoundedRectangle(cornerRadius: Radius.card)
    .cardShadow()  // ✅ ヘルパー使用

// または直接指定
RoundedRectangle(cornerRadius: Radius.card)
    .shadow(
        color: Shadow.card.color,
        radius: Shadow.card.radius,
        y: Shadow.card.y
    )
```

## 6. タップ領域とアクセシビリティ

### タップ領域

- **操作要素の最小タップ領域は 44×44pt**
- アイコンのみのボタンには必ず `accessibilityLabel` を付ける

```swift
Button {
    // action
} label: {
    Image(systemName: "xmark")
}
.accessibilityLabel("閉じる")
.frame(minWidth: 44, minHeight: 44)  // タップ領域を確保
```

### 画面下部のボタン

画面下部のボタンは `safeAreaInset(edge: .bottom)` に置く。

```swift
.safeAreaInset(edge: .bottom) {
    Button("保存") {
        // action
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
    .padding(Space.md)
}
```

### 状態表示

**色だけで状態を伝えない**。選択状態は形や文字でも示す。

```swift
// ✅ 正しい - 色と枠線で示す
Circle()
    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 3)

// ❌ 間違い - 色だけで示す
Circle()
    .fill(isSelected ? Color.blue : Color.gray)
```

## 使用例

### カード編集画面

```swift
VStack(spacing: Space.lg) {
    // セクションヘッダー
    Text("プロフィール")
        .font(Typography.sectionHeader)

    // フィールド
    VStack(alignment: .leading, spacing: Space.xxs) {
        Text("名前")
            .font(Typography.fieldLabel)
            .foregroundStyle(Colors.textSecondary)

        TextField("名前を入力", text: $name)
            .textFieldStyle(.roundedBorder)
    }
}
.padding(Space.md)  // 画面の左右マージン
```

### カードプレビュー

```swift
RoundedRectangle(cornerRadius: Radius.card)
    .fill(
        LinearGradient(
            colors: Palette.colors(for: paletteID),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
    .cardShadow()
```

## まとめ

- **数値リテラルを直接書かない** - すべて enum で定義されたトークンを使う
- **Dynamic Type 対応必須** - 固定サイズのフォントは使わない
- **役割ベースの命名** - 色名ではなく、役割で命名する
- **アクセシビリティ優先** - コントラスト比、タップ領域、ラベルを常に意識する
