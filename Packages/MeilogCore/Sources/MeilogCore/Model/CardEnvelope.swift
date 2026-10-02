import Foundation

/// Network.framework で交換する情報のラッパー
public struct CardEnvelope: Codable, Equatable, Sendable {
    /// カード本体（avatar を含む）
    public var card: Card
    /// 現在参加中のイベント（あれば）
    public var event: MeetupEvent?

    public init(card: Card, event: MeetupEvent? = nil) {
        self.card = card
        self.event = event
    }
}
