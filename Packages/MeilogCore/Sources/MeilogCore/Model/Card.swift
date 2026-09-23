import Foundation

/// 名刺カード。QR コードで交換する
public struct Card: Codable, Equatable, Hashable, Identifiable, Sendable {
    /// 安定 ID。再会検出に使う
    public let id: UUID
    /// 名前
    public var name: String
    /// 肩書き・所属など
    public var title: String?
    /// SNS や Web サイトへのリンク
    public var links: [Link]
    /// カードのデザイン
    public var style: CardStyle
    /// アイコン画像（QR には載せない。MultipeerConnectivity で届く）
    public var avatar: Data?

    public init(
        id: UUID,
        name: String,
        title: String? = nil,
        links: [Link] = [],
        style: CardStyle,
        avatar: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.links = links
        self.style = style
        self.avatar = avatar
    }
}

/// SNS や Web サイトへのリンク
public struct Link: Codable, Equatable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case github
        case x
        case bluesky
        case mastodon
        case web
    }

    public var kind: Kind
    public var value: String

    public init(kind: Kind, value: String) {
        self.kind = kind
        self.value = value
    }
}

/// カードのデザイン（パレットと模様）
public struct CardStyle: Codable, Equatable, Hashable, Sendable {
    /// パレット ID。色の組み合わせを決める
    public var paletteID: Int
    /// パターン ID。模様の種類を決める
    public var patternID: Int

    public init(paletteID: Int, patternID: Int) {
        self.paletteID = paletteID
        self.patternID = patternID
    }
}
