import Testing
import Foundation
@testable import MeilogCore

// MARK: - 往復テスト

@Test func CardPayloadはイベントありで往復できる() throws {
    let card = Card(
        id: UUID(),
        name: "山田太郎",
        title: "iOS Engineer",
        links: [
            Link(kind: .github, value: "yamada"),
            Link(kind: .x, value: "yamada_ios")
        ],
        style: CardStyle(paletteID: 2, patternID: 5),
        avatar: Data([0x01, 0x02, 0x03])
    )
    let event = MeetupEvent(
        id: UUID(),
        name: "iOSDC Japan 2026",
        date: Date(timeIntervalSince1970: 1789743600),
        venue: "東京"
    )
    let envelope = CardEnvelope(card: card, event: event)

    let data = try CardPayload.encode(envelope)
    let decoded = try CardPayload.decode(data)

    #expect(decoded.card.id == card.id)
    #expect(decoded.card.name == card.name)
    #expect(decoded.card.title == card.title)
    #expect(decoded.card.links.count == 2)
    #expect(decoded.card.style.paletteID == 2)
    #expect(decoded.card.style.patternID == 5)
    #expect(decoded.card.avatar == Data([0x01, 0x02, 0x03]))
    #expect(decoded.event?.id == event.id)
    #expect(decoded.event?.name == event.name)
    #expect(decoded.event?.date.timeIntervalSince1970 == 1789743600)
}

@Test func CardPayloadはイベントなしで往復できる() throws {
    let card = Card(
        id: UUID(),
        name: "佐藤花子",
        links: [],
        style: CardStyle(paletteID: 0, patternID: 0)
    )
    let envelope = CardEnvelope(card: card, event: nil)

    let data = try CardPayload.encode(envelope)
    let decoded = try CardPayload.decode(data)

    #expect(decoded.card.id == card.id)
    #expect(decoded.card.name == card.name)
    #expect(decoded.card.title == nil)
    #expect(decoded.card.links.isEmpty)
    #expect(decoded.event == nil)
}

// MARK: - エラーケース

@Test func 名前が空だとエラーになる() {
    let card = Card(
        id: UUID(),
        name: "",  // 空
        links: [],
        style: CardStyle(paletteID: 0, patternID: 0)
    )
    let envelope = CardEnvelope(card: card)

    #expect(throws: CardPayloadError.constraintViolation) {
        try CardPayload.encode(envelope)
    }
}

@Test func 名前が40文字を超えるとエラーになる() {
    let card = Card(
        id: UUID(),
        name: String(repeating: "あ", count: 41),
        links: [],
        style: CardStyle(paletteID: 0, patternID: 0)
    )
    let envelope = CardEnvelope(card: card)

    #expect(throws: CardPayloadError.constraintViolation) {
        try CardPayload.encode(envelope)
    }
}

@Test func リンクが5件を超えるとエラーになる() {
    let card = Card(
        id: UUID(),
        name: "名前",
        links: [
            Link(kind: .github, value: "a"),
            Link(kind: .github, value: "b"),
            Link(kind: .github, value: "c"),
            Link(kind: .github, value: "d"),
            Link(kind: .github, value: "e"),
            Link(kind: .github, value: "f")  // 6件目
        ],
        style: CardStyle(paletteID: 0, patternID: 0)
    )
    let envelope = CardEnvelope(card: card)

    #expect(throws: CardPayloadError.constraintViolation) {
        try CardPayload.encode(envelope)
    }
}
