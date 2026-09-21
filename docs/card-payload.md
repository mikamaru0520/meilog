# 交換フォーマット仕様（card payload v1）

QR コードに入れるデータの仕様。iOS 版の実装はこの文書に従う。将来ほかの実装を作る場合もこの文書が正。

## URL

```
meishi://v1/card?d=<DATA>
```

- scheme: `meishi`
- host: バージョン（v1 は `v1`）
- path: `/card`
- query `d`: JSON を UTF-8 でエンコードし、base64url（RFC 4648 §5、パディング `=` なし）にしたもの
- URL 全体で 800 バイトを超える場合、encode はエラー（`tooLarge`）。通常は 300〜400 バイト程度

## JSON

キーは短縮形。未知のキーは無視する。

```json
{
  "c": {
    "i": "8F1C2A34-5B6D-4E7F-8091-A2B3C4D5E6F7",
    "n": "Mika",
    "t": "iOS Engineer",
    "l": [{ "k": "gh", "v": "mika" }],
    "s": { "p": 3, "a": 7 }
  },
  "e": {
    "i": "0B7E4C21-9A3F-4D5E-8C6B-1F2A3B4C5D6E",
    "n": "iOSDC Japan 2026",
    "d": 1789743600,
    "v": "会場名"
  },
  "r": "a1B2c3D4"
}
```

### c: カード（必須）

| キー | 型 | 必須 | 対応するフィールド | 制約 |
|---|---|---|---|---|
| `i` | string | ○ | `Card.id` | UUID の文字列 |
| `n` | string | ○ | `Card.name` | 1〜40 文字 |
| `t` | string | | `Card.title` | 60 文字まで |
| `l` | array | | `Card.links` | 5 件まで。省略時は空 |
| `s` | object | ○ | `Card.style` | `p` = paletteID、`a` = patternID（0 以上の整数） |

`l` の要素: `k` = 種類、`v` = 値（100 文字まで）

| `k` | 種類 | `v` の形式 |
|---|---|---|
| `gh` | github | ユーザー名 |
| `x` | x | ユーザー名（`@` なし） |
| `bs` | bluesky | ハンドル（例: `mika.bsky.social`） |
| `md` | mastodon | `@user@host` |
| `web` | web | `https://` で始まる URL |

未知の `k` を持つ要素は読み飛ばす（エラーにしない）。

`avatar` は絶対に入れない。

### e: イベント（任意）

| キー | 型 | 必須 | 対応するフィールド | 制約 |
|---|---|---|---|---|
| `i` | string | ○ | `MeetupEvent.id` | UUID の文字列 |
| `n` | string | ○ | `MeetupEvent.name` | 1〜60 文字 |
| `d` | number | ○ | `MeetupEvent.date` | Unix 時刻（秒） |
| `v` | string | | `MeetupEvent.venue` | 60 文字まで |

### r: rendezvous（任意）

MultipeerConnectivity で画像を受け取るための一時的な値。英数字 8 文字。カード表示のたびに再生成する。

## decode のエラー

| エラー | 条件 |
|---|---|
| `unsupportedScheme` | scheme が `meishi` 以外 |
| `unsupportedVersion` | host が `v1` 以外。UI では「アプリを更新してください」と出す |
| `malformed` | path が違う、`d` がない、base64url / JSON として不正、必須キーの欠落、型の不一致 |
| `constraintViolation` | 文字数・件数などの制約違反 |

## 実装メモ

- 短いキーの DTO は `Payload/` 内の `internal` な型として定義し、ドメインモデルと相互変換する
- `JSONEncoder` の出力のキー順は保証されないので、encode 結果のバイト列比較でテストしない。テストは「往復」と「ゴールデンベクタの decode」で行う
- 日付は `secondsSince1970`。decode は整数・小数どちらも受け付ける

## 互換性ルール

- 任意キーの追加は v1 のまま行ってよい（古いアプリは無視する）
- 必須キーの追加、既存キーの意味変更・削除は v2 にする
- 将来 `https://<host>/c#<DATA>` 形式を足す場合も、`<DATA>` の中身はこの JSON と同じにする

## ゴールデンベクタ

上の JSON 例から `e.v` を除いたものをコンパクトに直列化した URL（323 バイト）:

```
meishi://v1/card?d=eyJjIjp7ImkiOiI4RjFDMkEzNC01QjZELTRFN0YtODA5MS1BMkIzQzRENUU2RjciLCJuIjoiTWlrYSIsInQiOiJpT1MgRW5naW5lZXIiLCJsIjpbeyJrIjoiZ2giLCJ2IjoibWlrYSJ9XSwicyI6eyJwIjozLCJhIjo3fX0sImUiOnsiaSI6IjBCN0U0QzIxLTlBM0YtNEQ1RS04QzZCLTFGMkEzQjRDNUQ2RSIsIm4iOiJpT1NEQyBKYXBhbiAyMDI2IiwiZCI6MTc4OTc0MzYwMH0sInIiOiJhMUIyYzNENCJ9
```

decode すると次になること:

- card: id `8F1C2A34-5B6D-4E7F-8091-A2B3C4D5E6F7`、name `Mika`、title `iOS Engineer`、links `[github: mika]`、style paletteID 3 / patternID 7、avatar nil
- event: id `0B7E4C21-9A3F-4D5E-8C6B-1F2A3B4C5D6E`、name `iOSDC Japan 2026`、date 1789743600（2026-09-19 00:00 JST）、venue nil
- rendezvous: `a1B2c3D4`
