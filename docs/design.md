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

### Network.framework による近距離直接交換

MultipeerConnectivity は iOS 27 で非推奨になったため、Network.framework を使用する。

#### 交換フロー

1. **探索開始**: 交換画面を開くと、`NWListener` で自分を広告し、`NWBrowser` で近くの相手を探す（どちらも `includePeerToPeer: true`）
2. **一覧表示**: 画面には「近くにいる人」の一覧が表示される。各行は名前と、その人のカードの配色から生成した色の印
3. **招待**: 相手を選ぶと招待が送信され、相手の画面に承認ダイアログが表示される
4. **交換**: 承認されると双方向にカードを送り合い、両方に `Encounter` が保存される
5. **アイコン転送**: アイコン画像もこの接続で一緒に送る（後追いの転送はしない）

#### 技術詳細

- **Bonjour サービスタイプ**: `_meilog._tcp`
- **広告タイミング**: 交換画面を開いている間だけ。バックグラウンドでは広告も探索もしない
- **データフォーマット**: JSON（CardEnvelope を Codable でエンコード）。card-payload.md の仕様に従う
- **暗号化**: 最初は行わない。将来 passcode などを足せるよう、パラメータ生成は1箇所にまとめておく
- **検証**: 受信したデータは必ず検証する（サイズ上限、文字数、件数）。悪意あるデータが来る前提で書く

#### 接続状態の管理

交換画面の状態遷移:

- **探索中**: NWBrowser が近くの相手を探している
- **招待中**: 相手に接続を試みている
- **承認待ち**: 相手の承認を待っている
- **接続中**: 接続が確立され、データ送受信の準備中
- **送受信中**: カードとアイコンを送受信している
- **完了**: 交換が成功した
- **失敗**: タイムアウトまたはエラーが発生した

## モデル（MeishiCore/Model）

ドメインモデルは永続化用に通常のキーで Codable にする。

```swift
import Foundation

public struct Card: Codable, Equatable, Sendable {
    public let id: UUID                  // 安定 ID。再会検出に使う
    public var name: String
    public var title: String?
    public var links: [Link]
    public var style: CardStyle
    public var avatar: Data?             // アイコン画像
}

public struct Link: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case github, x, web }
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

/// 相手1人分の記録。再会したら meetings が増える
public struct Encounter: Codable, Equatable, Sendable {
    public let id: UUID
    public var card: Card                // 最新のスナップショット
    public var meetings: [Meeting]       // 新しい順
    public var note: String
}

/// 交換するデータのラッパー
public struct CardEnvelope: Codable, Equatable, Sendable {
    public var card: Card                // avatar を含む
    public var event: MeetupEvent?
}
```

- `MeetupEvent` は ID 参照ではなく値で持つ。あとからイベント名を編集しても過去の記録は書き換わらない
- 自分のカード（`Card`）と「直近のイベント」（`MeetupEvent?`）もアプリ内に保存する
- `AvatarState` は削除（アイコン画像を交換時に一緒に送るため、状態管理は不要）

## 振る舞い（MeishiCore/Feature）

### イベントの自動割り当て

カード受信時に `Meeting.event` を決める。

1. 交換相手から届いたイベント情報がある → `.assigned(event, confidence: .confirmed)`
2. ない場合 → `.unassigned`

同じ日の判定は不要になった。ユーザーが「あとで整理」で手動で割り当てる。

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
    case assignEvent(meetingIDs: [UUID], event: MeetupEvent)
    case markAsNoEvent(meetingIDs: [UUID])
    case noteUpdated(encounterID: UUID, note: String)
    case deleteRequested(encounterID: UUID)
}

public enum EncounterListEffect: Equatable, Sendable {
    case load
    case persist(Encounter)
    case delete(encounterID: UUID)
}
```

名前や細部は実装時に調整してよい。ただし「reduce は純粋」「副作用はデータ」は崩さない。

### 交換画面の Intent と Effect の例

```swift
public enum ExchangeIntent: Sendable {
    case appeared
    case browsingStarted
    case peerDiscovered(id: String, name: String, paletteID: Int)
    case peerLost(id: String)
    case inviteTapped(peerID: String)
    case invitationReceived(from: String, name: String, paletteID: Int)
    case invitationAccepted
    case invitationDeclined
    case dataReceived(CardEnvelope)
    case exchangeCompleted
    case exchangeFailed(Error)
    case dismissed
}

public enum ExchangeEffect: Equatable, Sendable {
    case startAdvertising(card: Card, event: MeetupEvent?)
    case stopAdvertising
    case startBrowsing
    case stopBrowsing
    case sendInvitation(to: String)
    case sendData(CardEnvelope, to: String)
    case saveEncounter(CardEnvelope)
}
```

### Port（MeishiCore/Port）

```swift
public protocol EncounterRepository: Sendable {
    func load() async throws -> [Encounter]
    func save(_ encounter: Encounter) async throws
    func delete(id: UUID) async throws
}
```

Network.framework の実装は `Infrastructure/` に置き、Core には持ち込まない。

## アーキテクチャ

- 依存は `MeishiApp → MeishiCore` の一方向のみ
- Core を分ける理由: テストがシミュレータなしで回る（`swift test` が macOS で動く）、UI とロジックの混線をビルドで防げる
- Store の形:

```swift
@MainActor @Observable
final class EncounterListStore {
    private(set) var state = EncounterListState()
    private let repository: EncounterRepository

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
- 交換画面では、近くの人の一覧に配色から生成した色の印を表示する
- Liquid Glass はカード面ではなく、ボタンやシート周りの操作系に限定（iOS 26 のみ）
- UI の文言は日本語

## 権限

- ローカルネットワーク（Bonjour サービスの探索と広告）: `NSLocalNetworkUsageDescription` と `NSBonjourServices` が必要
- 連絡先・位置情報・カメラは使わない

## App Store に向けて

- プライバシーポリシー: データは端末内のみ、サーバー送信なし
- アカウントを作らない（アカウント削除機能の要件を避ける）

## 作る順番

1. `MeishiCore/Model` のモデル定義（AvatarState を削除）
2. `CardPayload` の encode / decode。往復テストとゴールデンベクタのテスト（イベントあり・なし）
3. `reduce`: イベント割り当て（1段のみ）、再会検出、あとで整理、検索・絞り込み。テストで固める
4. 自分のカードの作成・表示
5. 交換画面の UI（近くの人の一覧、招待、承認ダイアログ）
6. Network.framework による探索・広告・接続・送受信の実装
7. 一覧・イベント別絞り込み・整理画面・遷移アニメーション
8. TestFlight でもくもく会に配布

1〜3 は UI なし。7 まででアプリとして成立する。

## 保留にしたもの

- Android 対応: 要望が出たら、まず静的な Web ページで参加できるようにする。アプリを作るなら別ネイティブで、この設計書と `reduce` のテストをもとに移植
- ドメインと Universal Link: Web 対応を決めた時点で取る
- NFC タグ、Wallet パス、iCloud 同期: Core に手を入れずに後から足せる
- TCA: 自前 MVI で副作用やテストが辛くなったら検討
- 暗号化: 将来 passcode 入力で暗号化できるよう、パラメータ生成箇所は整理しておく
