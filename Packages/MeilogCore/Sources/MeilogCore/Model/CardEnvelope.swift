import Foundation

/// QR コードで交換する情報のラッパー
public struct CardEnvelope: Equatable, Sendable {
    /// カード本体（avatar は除いてエンコードされる）
    public var card: Card
    /// 現在参加中のイベント（あれば）
    public var event: MeetupEvent?
    /// アイコン画像交換用の rendezvous キー
    public var rendezvous: String?

    public init(card: Card, event: MeetupEvent? = nil, rendezvous: String? = nil) {
        self.card = card
        self.event = event
        self.rendezvous = rendezvous
    }
}
