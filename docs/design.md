# 設計と技術方針

## コンセプト

勉強会やもくもく会で会った人を記録するアプリ。連絡先を渡すこと自体は NameDrop が OS 標準でやっているので、差別化は「どこで・いつ・何回会ったか」を残して、あとから探せることに置く。もくもく会の参加者がそれぞれインストールし、他の勉強会でもアプリを持っている人同士で使う。

## 前提

- iOS ネイティブのみ（SwiftUI）。交換相手も全員アプリを持っている前提
- 最低サポート: iOS 18.0。Liquid Glass など iOS 26 の API は `if #available(iOS 26, *)` で分岐
- サーバーなし。データは端末内で完結。アカウントなし
- 配布は TestFlight → App Store。バンドル ID は最初から本番のもの
- Android は当面作らない（参加者比率 iOS 80% 以上、Android 12%）。KMP も TCA も入れない

## 交換方式

### QR コード

```
meishi://v1/card?d=<base64url(JSON)>
```

- 詳細は `docs/card-payload.md`
- アプリ内スキャナ（AVFoundation）で読み取る。`.onOpenURL` でも同じ decode を通す
- QR 生成は Core Image の `CIQRCodeGenerator`
- QR 中央に自分のアイコンを載せる。載せる場合は誤り訂正を上げる必要があり、同じデータ量でも QR が細かくなる。実機で読み取りテストして、読みにくければアイコンを小さくするか外す
- `CardPayload.decode` は、将来 `https://` 形式を足せるように scheme で分岐する構造にしておく（v1 では `meishi` のみ受け付ける）

### アイコン画像（MultipeerConnectivity）

- サービスタイプ: `meishi`
- 表示側: カード表示中に `MCNearbyServiceAdvertiser` を起動。`discoveryInfo` に rendezvous（8文字のランダム値、カード表示のたびに再生成）を入れる
- 読取側: QR を読んだ時点で交換は成立（Encounter を保存）。その後 `MCNearbyServiceBrowser` で rendezvous が一致する相手だけに接続し、画像を受け取る
- 5秒でタイムアウト。失敗しても交換は壊れない。`avatarState` を取得失敗にして、あとで再取得できるようにする
- 最初は片方向（表示側 → 読取側）のみ
- 送信前に 512×512 程度にリサイズし、JPEG 品質 0.7 前後で圧縮（目安 50KB 以下）
- Info.plist: `NSLocalNetworkUsageDescription`、`NSBonjourServices`（`_meishi._tcp`, `_meishi._udp`）。設定済み
- 初回の権限ダイアログはオンボーディングで説明してから出す

## モデル（MeishiCore/Model）

ドメインモデルは永続化用に通常のキーで Codable にする。QR 用の短いキーは `Payload/` の DTO で変換する（ドメインモデルに短いキーの CodingKeys を持たせない）。

```swift
import Foundation

public struct Card: Codable, Equatable, Sendable {
    public let id: UUID                  // 安定 ID。再会検出に使う
    public var name: String
    public var title: String?
    public var links: [Link]
    public var style: CardStyle
    public var avatar: Data?             // QR には載せない。Multipeer で届く
}

public struct Link: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case github, x, bluesky, mastodon, web }
    public var kind: Kind
    public var value: String
}

public struct CardStyle: Codable, Equatable, Sendable {
    public var paletteID: Int
    public var patternID: Int            // 模様の乱数 seed は Card.id から導出（送らない）
}

public struct MeetupEvent: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var date: Date
    public var venue: String?
}

public enum Confidence: Codable, Equatable, Sendable { case inferred, confirmed }

public enum EventAssignment: Codable, Equatable, Sendable {
    case unassigned                                    // まだ決めていない
    case assigned(MeetupEvent, confidence: Confidence)
    case none                                          // イベント外で会った、と決めた
}

public struct Meeting: Codable, Equatable, Sendable {
    public let id: UUID
    public let at: Date
    public var event: EventAssignment
}

public enum AvatarState: Codable, Equatable, Sendable {
    case notReceived, received, unavailable
}

/// 相手1人分の記録。再会したら meetings が増える
public struct Encounter: Codable, Equatable, Sendable {
    public let id: UUID
    public var card: Card                // 最新のスナップショット
    public var meetings: [Meeting]       // 新しい順
    public var note: String
    public var avatarState: AvatarState
}

/// QR の中身
public struct CardEnvelope: Equatable, Sendable {
    public var card: Card                // avatar は除いてエンコードされる
    public var event: MeetupEvent?
    public var rendezvous: String?
}
```

- `MeetupEvent` は ID 参照ではなく値で持つ。あとからイベント名を編集しても過去の記録は書き換わらない
- 自分のカード（`Card`）と「直近のイベント」（`MeetupEvent?`）もアプリ内に保存する

## 振る舞い（MeishiCore/Feature）

### イベントの自動割り当て（3段フォールバック）

カード受信時に `Meeting.event` を決める。

1. QR にイベントが入っている → `.assigned(event, confidence: .confirmed)`
2. 自分の「直近のイベント」の `date` が受信日と同じ日 → `.assigned(event, confidence: .inferred)`
3. どちらもない → `.unassigned`

同じ日の判定は `Calendar` を引数で受け取る（テストでタイムゾーンを固定するため）。

### 再会検出

- `Card.id` が既存の Encounter と同じ → Encounter は増やさず、先頭に `Meeting` を追加し、`card` を最新に更新する
- 異なる → 新しい Encounter を追加

### あとで整理

- 同じ日に受け取ったものをまとめて、一括でイベントに割り当てられる（`assignEvent(meetingIDs:event:)`、`markAsNoEvent(meetingIDs:)`）
- ユーザーが割り当てたものは `.confirmed`
- `.unassigned` と `.inferred` の件数を State の computed property で出し、一覧にバッジ表示する

### 一覧

- 検索（名前、肩書き、イベント名）とイベント別の絞り込み。どちらも State の computed property として純粋に書く
- 並び順は最後に会った日時の新しい順

### Intent と Effect の例（一覧・受信）

```swift
public enum EncounterListIntent: Sendable {
    case appeared
    case loaded([Encounter], recentEvent: MeetupEvent?)
    case queryChanged(String)
    case cardReceived(CardEnvelope, now: Date, newID: UUID, calendar: Calendar)
    case avatarArrived(encounterID: UUID, data: Data)
    case avatarFailed(encounterID: UUID)
    case assignEvent(meetingIDs: [UUID], event: MeetupEvent)
    case markAsNoEvent(meetingIDs: [UUID])
    case deleteRequested(encounterID: UUID)
}

public enum EncounterListEffect: Equatable, Sendable {
    case load
    case persist(Encounter)
    case delete(encounterID: UUID)
    case requestAvatar(encounterID: UUID, rendezvous: String)
}
```

名前や細部は実装時に調整してよい。ただし「reduce は純粋」「副作用はデータ」は崩さない。

### Port（MeishiCore/Port）

```swift
public protocol EncounterRepository: Sendable {
    func load() async throws -> [Encounter]
    func save(_ encounter: Encounter) async throws
    func delete(id: UUID) async throws
}

public protocol AvatarReceiver: Sendable {
    /// rendezvous が一致する相手から画像を受け取る。失敗・タイムアウト時は nil
    func receive(rendezvous: String, timeout: Duration) async -> Data?
}

public protocol AvatarAdvertiser: Sendable {
    func start(rendezvous: String, avatar: Data) async
    func stop() async
}
```

## アーキテクチャ

- 依存は `MeishiApp → MeishiCore` の一方向のみ
- Core を分ける理由: テストがシミュレータなしで回る（`swift test` が macOS で動く）、UI とロジックの混線をビルドで防げる
- Store の形:

```swift
@MainActor @Observable
final class EncounterListStore {
    private(set) var state = EncounterListState()
    private let repository: EncounterRepository
    private let avatarReceiver: AvatarReceiver

    func send(_ intent: EncounterListIntent) {
        let (next, effects) = reduce(state, intent)
        state = next
        for effect in effects { run(effect) }
    }

    private func run(_ effect: EncounterListEffect) { /* Task を起動し、結果を send で戻す */ }
}
```

- 永続化は SwiftData（`Infrastructure/` で `EncounterRepository` を実装）。SwiftData の型を Core に漏らさない

## デザイン方針

- カードは CardStyle（パレット・パターン）から `MeshGradient` や `Canvas` で描画する。送るデータはほぼゼロで、全員のカードが違って見える
- `paletteID` → 実際の色、`patternID` → 描画コードの対応はアプリ側。未知の ID は 0 番にフォールバック
- アイコンがない相手は、イニシャルとパレットで生成した図形を表示
- 一覧から詳細への遷移に `matchedGeometryEffect`、スクロールに `scrollTransition`
- Liquid Glass はカード面ではなく、ボタンや QR 周りの操作系に限定（iOS 26 のみ）
- UI の文言は日本語

## 権限

- カメラ（QR 読み取り）
- ローカルネットワーク（画像転送）
- 連絡先・位置情報は使わない

## App Store に向けて

- プライバシーポリシー: データは端末内のみ、サーバー送信なし
- アカウントを作らない（アカウント削除機能の要件を避ける）

## 作る順番

1. `MeishiCore/Model` のモデル定義
2. `CardPayload` の encode / decode。往復テストとゴールデンベクタのテスト（イベントあり・なし）
3. `reduce`: 3段フォールバック、再会検出、あとで整理、検索・絞り込み。テストで固める
4. 自分のカードの作成・表示と QR 生成
5. QR 読み取りと受信フロー（Store、SwiftData の Repository）
6. 一覧・イベント別絞り込み・整理画面・遷移アニメーション
7. MultipeerConnectivity で画像転送
8. TestFlight でもくもく会に配布

1〜3 は UI なし。7 は一番不確実なので最後。6 まででアプリとして成立する。

## 保留にしたもの

- Android 対応: 要望が出たら、まず静的な Web ページで参加できるようにする。アプリを作るなら別ネイティブで、この設計書と `reduce` のテストをもとに移植
- ドメインと Universal Link: Web 対応を決めた時点で取る
- NFC タグ、AirDrop、Wallet パス、iCloud 同期: Core に手を入れずに後から足せる
- TCA: 自前 MVI で副作用やテストが辛くなったら検討
- 相互交換（読取側の画像も送り返す）
