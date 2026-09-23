import Foundation

/// アイコン画像の受信状態
public enum AvatarState: Codable, Equatable, Hashable, Sendable {
    /// まだ受信していない
    case notReceived
    /// 受信済み
    case received
    /// 受信不可（タイムアウトなど）
    case unavailable
}

/// 相手1人分の記録。再会したら meetings が増える
public struct Encounter: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: UUID
    /// 最新のカード情報（再会時に更新される）
    public var card: Card
    /// 会った記録（新しい順）
    public var meetings: [Meeting]
    /// メモ
    public var note: String
    /// アイコン画像の受信状態
    public var avatarState: AvatarState

    public init(
        id: UUID,
        card: Card,
        meetings: [Meeting],
        note: String = "",
        avatarState: AvatarState = .notReceived
    ) {
        self.id = id
        self.card = card
        self.meetings = meetings
        self.note = note
        self.avatarState = avatarState
    }

    /// 最後に会った日時
    public var lastMetAt: Date? {
        meetings.first?.at
    }
}
