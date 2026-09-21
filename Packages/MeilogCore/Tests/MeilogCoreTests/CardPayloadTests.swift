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
        style: CardStyle(paletteID: 2, patternID: 5)
    )
    let event = MeetupEvent(
        id: UUID(),
        name: "iOSDC Japan 2026",
        date: Date(timeIntervalSince1970: 1789743600),
        venue: "東京"
    )
    let envelope = CardEnvelope(card: card, event: event, rendezvous: "abc12345")

    let url = try CardPayload.encode(envelope)
    let decoded = try CardPayload.decode(url)

    #expect(decoded.card.id == card.id)
    #expect(decoded.card.name == card.name)
    #expect(decoded.card.title == card.title)
    #expect(decoded.card.links.count == 2)
    #expect(decoded.card.style.paletteID == 2)
    #expect(decoded.card.style.patternID == 5)
    #expect(decoded.card.avatar == nil)
    #expect(decoded.event?.id == event.id)
    #expect(decoded.event?.name == event.name)
    #expect(decoded.event?.date.timeIntervalSince1970 == 1789743600)
    #expect(decoded.rendezvous == "abc12345")
}

@Test func CardPayloadはイベントなしで往復できる() throws {
    let card = Card(
        id: UUID(),
        name: "佐藤花子",
        links: [],
        style: CardStyle(paletteID: 0, patternID: 0)
    )
    let envelope = CardEnvelope(card: card, event: nil, rendezvous: nil)

    let url = try CardPayload.encode(envelope)
    let decoded = try CardPayload.decode(url)

    #expect(decoded.card.id == card.id)
    #expect(decoded.card.name == card.name)
    #expect(decoded.card.title == nil)
    #expect(decoded.card.links.isEmpty)
    #expect(decoded.event == nil)
    #expect(decoded.rendezvous == nil)
}

@Test func CardPayloadはavatarを除いてエンコードする() throws {
    let card = Card(
        id: UUID(),
        name: "田中一郎",
        links: [],
        style: CardStyle(paletteID: 1, patternID: 1),
        avatar: Data([0x01, 0x02, 0x03])  // avatar があっても
    )
    let envelope = CardEnvelope(card: card)

    let url = try CardPayload.encode(envelope)
    let decoded = try CardPayload.decode(url)

    #expect(decoded.card.avatar == nil)  // デコード後は nil
}

// MARK: - ゴールデンベクタ

@Test func ゴールデンベクタをデコードできる() throws {
    let url = "meilog://v1/card?d=eyJjIjp7ImkiOiI4RjFDMkEzNC01QjZELTRFN0YtODA5MS1BMkIzQzRENUU2RjciLCJuIjoiTWlrYSIsInQiOiJpT1MgRW5naW5lZXIiLCJsIjpbeyJrIjoiZ2giLCJ2IjoibWlrYSJ9XSwicyI6eyJwIjozLCJhIjo3fX0sImUiOnsiaSI6IjBCN0U0QzIxLTlBM0YtNEQ1RS04QzZCLTFGMkEzQjRDNUQ2RSIsIm4iOiJpT1NEQyBKYXBhbiAyMDI2IiwiZCI6MTc4OTc0MzYwMH0sInIiOiJhMUIyYzNENCJ9"

    let envelope = try CardPayload.decode(url)

    // card
    #expect(envelope.card.id == UUID(uuidString: "8F1C2A34-5B6D-4E7F-8091-A2B3C4D5E6F7"))
    #expect(envelope.card.name == "Mika")
    #expect(envelope.card.title == "iOS Engineer")
    #expect(envelope.card.links.count == 1)
    #expect(envelope.card.links[0].kind == .github)
    #expect(envelope.card.links[0].value == "mika")
    #expect(envelope.card.style.paletteID == 3)
    #expect(envelope.card.style.patternID == 7)
    #expect(envelope.card.avatar == nil)

    // event
    #expect(envelope.event?.id == UUID(uuidString: "0B7E4C21-9A3F-4D5E-8C6B-1F2A3B4C5D6E"))
    #expect(envelope.event?.name == "iOSDC Japan 2026")
    #expect(envelope.event?.date.timeIntervalSince1970 == 1789743600)
    #expect(envelope.event?.venue == nil)

    // rendezvous
    #expect(envelope.rendezvous == "a1B2c3D4")
}

// MARK: - エラーケース

@Test func 不正なスキームでエラーになる() {
    let url = "https://v1/card?d=eyJjIjp7fX0"
    #expect(throws: CardPayloadError.unsupportedScheme) {
        try CardPayload.decode(url)
    }
}

@Test func 未対応バージョンでエラーになる() {
    let url = "meilog://v2/card?d=eyJjIjp7fX0"
    #expect(throws: CardPayloadError.unsupportedVersion) {
        try CardPayload.decode(url)
    }
}

@Test func 不正なパスでエラーになる() {
    let url = "meilog://v1/unknown?d=eyJjIjp7fX0"
    #expect(throws: CardPayloadError.malformed) {
        try CardPayload.decode(url)
    }
}

@Test func dパラメータがないとエラーになる() {
    let url = "meilog://v1/card?x=abc"
    #expect(throws: CardPayloadError.malformed) {
        try CardPayload.decode(url)
    }
}

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

@Test func 未知のリンク種類は読み飛ばされる() throws {
    // 手動で未知のリンク種類を含むJSONを作成
    let json = """
    {
      "c": {
        "i": "8F1C2A34-5B6D-4E7F-8091-A2B3C4D5E6F7",
        "n": "Mika",
        "l": [
          {"k": "gh", "v": "mika"},
          {"k": "unknown", "v": "value"},
          {"k": "x", "v": "mika_x"}
        ],
        "s": {"p": 0, "a": 0}
      }
    }
    """
    let data = json.data(using: .utf8)!
    let base64 = data.base64URLEncodedString()
    let url = "meilog://v1/card?d=\(base64)"

    let envelope = try CardPayload.decode(url)

    // 未知のkindは読み飛ばされ、2件だけ残る
    #expect(envelope.card.links.count == 2)
    #expect(envelope.card.links[0].kind == .github)
    #expect(envelope.card.links[1].kind == .x)
}
