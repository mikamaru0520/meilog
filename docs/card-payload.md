# 交換フォーマット仕様（card payload v1）

Network.framework で送信するカード情報の仕様。iOS 版の実装はこの文書に従う。将来ほかの実装を作る場合もこの文書が正。

## データフォーマット

- エンコーディング: UTF-8
- フォーマット: JSON
- Content-Type: `application/json`

## JSON 構造

すべてのキーは完全な名前を使用する（短縮形は使わない）。未知のキーは無視する。

```json
{
  "card": {
    "id": "8F1C2A34-5B6D-4E7F-8091-A2B3C4D5E6F7",
    "name": "サンプル太郎",
    "title": "iOSエンジニア",
    "links": [
      {
        "kind": "github",
        "value": "sample-taro"
      },
      {
        "kind": "x",
        "value": "sample_taro"
      }
    ],
    "style": {
      "paletteID": 3,
      "patternID": 7
    },
    "avatar": null
  },
  "event": {
    "id": "0B7E4C21-9A3F-4D5E-8C6B-1F2A3B4C5D6E",
    "name": "iOSDC Japan 2026",
    "date": 1789743600,
    "venue": "早稲田大学"
  }
}
```

### card: カード（必須）

| フィールド | 型 | 必須 | 制約 |
|---|---|---|---|
| `id` | string | ○ | UUID の文字列 |
| `name` | string | ○ | 1〜40 文字 |
| `title` | string | | 60 文字まで。省略可 |
| `links` | array | | 4 件まで。省略時は空配列 |
| `style` | object | ○ | paletteID と patternID（0 以上の整数） |
| `avatar` | string | | Base64 エンコードされた画像データ（JPEG/PNG）。省略可 |

#### links の要素

| フィールド | 型 | 必須 | 制約 |
|---|---|---|---|
| `kind` | string | ○ | リンクの種類 |
| `value` | string | ○ | 100 文字まで |

**kind の種類と value の形式:**

| kind | 種類 | value の形式 |
|---|---|---|
| `github` | GitHub | ユーザー名 |
| `x` | X (Twitter) | ユーザー名（`@` なし） |
| `web` | Web | `https://` で始まる URL |

未知の `kind` を持つ要素は読み飛ばす（エラーにしない）。

#### style オブジェクト

| フィールド | 型 | 必須 | 制約 |
|---|---|---|---|
| `paletteID` | number | ○ | 0 以上の整数 |
| `patternID` | number | ○ | 0 以上の整数 |

### event: イベント（任意）

イベント情報は省略可能。送信者が現在参加しているイベント情報を含める場合に指定する。

| フィールド | 型 | 必須 | 制約 |
|---|---|---|---|
| `id` | string | ○ | UUID の文字列 |
| `name` | string | ○ | 1〜60 文字 |
| `date` | number | ○ | Unix 時刻（秒） |
| `venue` | string | | 60 文字まで。省略可 |

## バージョニング

- 現在のバージョン: v1
- バージョン情報は JSON に含めない（プロトコルレベルで管理する）
- 互換性:
  - 任意フィールドの追加は後方互換性を保つ（古いアプリは無視する）
  - 必須フィールドの追加、既存フィールドの意味変更・削除は非互換（バージョンを上げる）

## 検証ルール

### decode 時のエラー

| エラー | 条件 |
|---|---|
| `malformed` | JSON として不正、必須キーの欠落、型の不一致 |
| `constraintViolation` | 文字数・件数などの制約違反 |

### encode 時の制約チェック

`CardPayload.encode()` は以下の制約をチェックし、違反時は `constraintViolation` エラーを throw する:

- card.name: 1〜40 文字
- card.title: 60 文字まで（省略可）
- card.links: 4 件まで
- card.links[].value: 100 文字まで
- event.name: 1〜60 文字
- event.venue: 60 文字まで（省略可）

### サイズ上限

- JSON 全体のサイズ: 最大 1MB（アイコン画像を含む）
- アイコン画像は送信前に 512×512 にリサイズし、JPEG 品質 0.7 で圧縮する
- 受信側は必ずサイズをチェックし、上限を超える場合は拒否する

### セキュリティ

- 悪意あるデータが来る前提で検証する
- 文字列の長さは必ずチェックする
- 配列の要素数は必ずチェックする
- 画像データは必ずデコード可能かチェックする

## 実装メモ

- ドメインモデル（Card, MeetupEvent）は Codable であり、そのまま JSON にエンコードされる
- `JSONEncoder` の出力のキー順は保証されないので、encode 結果のバイト列比較でテストしない
- テストは「往復」と「ゴールデンベクタの decode」で行う
- 日付は `secondsSince1970`。decode は整数・小数どちらも受け付ける
- avatar は Base64 エンコード文字列として扱う（実装では Data として保持）

## ゴールデンベクタ

### イベントなしの最小構成（avatar も省略）

```json
{
  "card": {
    "id": "8F1C2A34-5B6D-4E7F-8091-A2B3C4D5E6F7",
    "name": "サンプル太郎",
    "title": "iOSエンジニア",
    "links": [
      {
        "kind": "github",
        "value": "sample-taro"
      }
    ],
    "style": {
      "paletteID": 3,
      "patternID": 7
    }
  }
}
```

decode すると次になること:

- card: id `8F1C2A34-5B6D-4E7F-8091-A2B3C4D5E6F7`、name `サンプル太郎`、title `iOSエンジニア`、links `[github: sample-taro]`、style paletteID 3 / patternID 7、avatar nil
- event: nil

### イベントありの構成

```json
{
  "card": {
    "id": "8F1C2A34-5B6D-4E7F-8091-A2B3C4D5E6F7",
    "name": "サンプル太郎",
    "title": "iOSエンジニア",
    "links": [
      {
        "kind": "github",
        "value": "sample-taro"
      },
      {
        "kind": "x",
        "value": "sample_taro"
      }
    ],
    "style": {
      "paletteID": 3,
      "patternID": 7
    }
  },
  "event": {
    "id": "0B7E4C21-9A3F-4D5E-8C6B-1F2A3B4C5D6E",
    "name": "iOSDC Japan 2026",
    "date": 1789743600
  }
}
```

decode すると次になること:

- card: id `8F1C2A34-5B6D-4E7F-8091-A2B3C4D5E6F7`、name `サンプル太郎`、title `iOSエンジニア`、links `[github: sample-taro, x: sample_taro]`、style paletteID 3 / patternID 7、avatar nil
- event: id `0B7E4C21-9A3F-4D5E-8C6B-1F2A3B4C5D6E`、name `iOSDC Japan 2026`、date 1789743600（2026-09-19 00:00 JST）、venue nil
