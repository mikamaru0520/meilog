import Foundation

/// 勉強会・もくもく会などのイベント
public struct MeetupEvent: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: UUID
    /// イベント名
    public var name: String
    /// 開催日
    public var date: Date
    /// 会場
    public var venue: String?

    public init(id: UUID, name: String, date: Date, venue: String? = nil) {
        self.id = id
        self.name = name
        self.date = date
        self.venue = venue
    }
}

/// イベント割り当ての確信度
public enum Confidence: Codable, Equatable, Hashable, Sendable {
    /// 推測（自動割り当て）
    case inferred
    /// 確定（ユーザーが明示的に設定）
    case confirmed
}

/// 会った記録（Meeting）とイベントの紐付け
public enum EventAssignment: Codable, Equatable, Hashable, Sendable {
    /// まだ決めていない
    case unassigned
    /// イベントに紐付いている
    case assigned(MeetupEvent, confidence: Confidence)
    /// イベント外で会った、と決めた
    case none

    /// イベント情報を取得（割り当てられている場合のみ）
    public var event: MeetupEvent? {
        if case .assigned(let event, _) = self {
            return event
        }
        return nil
    }

    /// 確信度を取得（割り当てられている場合のみ）
    public var confidence: Confidence? {
        if case .assigned(_, let confidence) = self {
            return confidence
        }
        return nil
    }
}

/// 会った記録（1回分）
public struct Meeting: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: UUID
    /// 会った日時
    public let at: Date
    /// イベントとの紐付け
    public var event: EventAssignment

    public init(id: UUID, at: Date, event: EventAssignment) {
        self.id = id
        self.at = at
        self.event = event
    }
}
