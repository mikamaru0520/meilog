import Foundation

/// CardPayload の JSON 用 DTO（QRサイズ削減のため、JSONは短縮キーを使用）
struct PayloadDTO: Codable {
    /// カード（必須）
    var card: CardDTO
    /// イベント（任意）
    var event: EventDTO?
    /// rendezvous（任意）
    var rendezvous: String?

    enum CodingKeys: String, CodingKey {
        case card = "c"
        case event = "e"
        case rendezvous = "r"
    }
}

/// カードのDTO
struct CardDTO: Codable {
    /// id（UUID文字列）
    var id: String
    /// name
    var name: String
    /// title（任意）
    var title: String?
    /// links（任意、省略時は空）
    var links: [LinkDTO]?
    /// style（必須）
    var style: StyleDTO

    enum CodingKeys: String, CodingKey {
        case id = "i"
        case name = "n"
        case title = "t"
        case links = "l"
        case style = "s"
    }
}

/// リンクのDTO
struct LinkDTO: Codable {
    /// 種類（"gh", "x", "bs", "md", "web"）
    var kind: String
    /// 値
    var value: String

    enum CodingKeys: String, CodingKey {
        case kind = "k"
        case value = "v"
    }
}

/// スタイルのDTO
struct StyleDTO: Codable {
    /// paletteID
    var paletteID: Int
    /// patternID
    var patternID: Int

    enum CodingKeys: String, CodingKey {
        case paletteID = "p"
        case patternID = "a"
    }
}

/// イベントのDTO
struct EventDTO: Codable {
    /// id（UUID文字列）
    var id: String
    /// name
    var name: String
    /// date（Unix秒）
    var date: Double
    /// venue（任意）
    var venue: String?

    enum CodingKeys: String, CodingKey {
        case id = "i"
        case name = "n"
        case date = "d"
        case venue = "v"
    }
}

// MARK: - DTO → ドメインモデル変換

extension CardDTO {
    func toDomain() throws -> Card {
        guard let uuid = UUID(uuidString: id) else {
            throw CardPayloadError.malformed
        }
        guard !name.isEmpty, name.count <= 40 else {
            throw CardPayloadError.constraintViolation
        }
        if let title = title, title.count > 60 {
            throw CardPayloadError.constraintViolation
        }
        let domainLinks = try (links ?? []).compactMap { try $0.toDomain() }
        if domainLinks.count > 5 {
            throw CardPayloadError.constraintViolation
        }

        return Card(
            id: uuid,
            name: name,
            title: title,
            links: domainLinks,
            style: style.toDomain(),
            avatar: nil
        )
    }
}

extension LinkDTO {
    func toDomain() throws -> Link? {
        guard value.count <= 100 else {
            throw CardPayloadError.constraintViolation
        }

        let linkKind: Link.Kind
        switch kind {
        case "gh": linkKind = .github
        case "x": linkKind = .x
        case "bs": linkKind = .bluesky
        case "md": linkKind = .mastodon
        case "web": linkKind = .web
        default: return nil  // 未知のkindは読み飛ばす
        }

        return Link(kind: linkKind, value: value)
    }
}

extension StyleDTO {
    func toDomain() -> CardStyle {
        CardStyle(paletteID: max(0, paletteID), patternID: max(0, patternID))
    }
}

extension EventDTO {
    func toDomain() throws -> MeetupEvent {
        guard let uuid = UUID(uuidString: id) else {
            throw CardPayloadError.malformed
        }
        guard !name.isEmpty, name.count <= 60 else {
            throw CardPayloadError.constraintViolation
        }
        if let venue = venue, venue.count > 60 {
            throw CardPayloadError.constraintViolation
        }

        return MeetupEvent(
            id: uuid,
            name: name,
            date: Date(timeIntervalSince1970: date),
            venue: venue
        )
    }
}

// MARK: - ドメインモデル → DTO 変換

extension Card {
    func toDTO() -> CardDTO {
        CardDTO(
            id: id.uuidString,
            name: name,
            title: title,
            links: links.isEmpty ? nil : links.map { $0.toDTO() },
            style: style.toDTO()
        )
    }
}

extension Link {
    func toDTO() -> LinkDTO {
        let kindString: String
        switch kind {
        case .github: kindString = "gh"
        case .x: kindString = "x"
        case .bluesky: kindString = "bs"
        case .mastodon: kindString = "md"
        case .web: kindString = "web"
        }
        return LinkDTO(kind: kindString, value: value)
    }
}

extension CardStyle {
    func toDTO() -> StyleDTO {
        StyleDTO(paletteID: paletteID, patternID: patternID)
    }
}

extension MeetupEvent {
    func toDTO() -> EventDTO {
        EventDTO(
            id: id.uuidString,
            name: name,
            date: date.timeIntervalSince1970,
            venue: venue
        )
    }
}
