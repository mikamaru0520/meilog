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

@Test func リンクが4件を超えるとエラーになる() {
    let card = Card(
        id: UUID(),
        name: "名前",
        links: [
            Link(kind: .github, value: "a"),
            Link(kind: .github, value: "b"),
            Link(kind: .github, value: "c"),
            Link(kind: .github, value: "d"),
            Link(kind: .github, value: "e")  // 5件目
        ],
        style: CardStyle(paletteID: 0, patternID: 0)
    )
    let envelope = CardEnvelope(card: card)

    #expect(throws: CardPayloadError.constraintViolation) {
        try CardPayload.encode(envelope)
    }
}

// MARK: - ゴールデンベクタのテスト

@Test func ゴールデンベクタ_イベントなし() throws {
    let json = """
    {
      "card": {
        "id": "8F1C2A34-5B6D-4E7F-8091-A2B3C4D5E6F7",
        "name": "サンプル太郎",
        "title": "iOSエンジニア",
        "links": [
          {
            "kind": "github",
            "value": "sample-taro"
          }
        ],
        "style": {
          "paletteID": 3,
          "patternID": 7
        }
      }
    }
    """
    let data = json.data(using: .utf8)!
    let envelope = try CardPayload.decode(data)

    #expect(envelope.card.id == UUID(uuidString: "8F1C2A34-5B6D-4E7F-8091-A2B3C4D5E6F7"))
    #expect(envelope.card.name == "サンプル太郎")
    #expect(envelope.card.title == "iOSエンジニア")
    #expect(envelope.card.links.count == 1)
    #expect(envelope.card.links[0].kind == .github)
    #expect(envelope.card.links[0].value == "sample-taro")
    #expect(envelope.card.style.paletteID == 3)
    #expect(envelope.card.style.patternID == 7)
    #expect(envelope.card.avatar == nil)
    #expect(envelope.event == nil)
}

@Test func ゴールデンベクタ_イベントあり() throws {
    let json = """
    {
      "card": {
        "id": "8F1C2A34-5B6D-4E7F-8091-A2B3C4D5E6F7",
        "name": "サンプル太郎",
        "title": "iOSエンジニア",
        "links": [
          {
            "kind": "github",
            "value": "sample-taro"
          },
          {
            "kind": "x",
            "value": "sample_taro"
          }
        ],
        "style": {
          "paletteID": 3,
          "patternID": 7
        }
      },
      "event": {
        "id": "0B7E4C21-9A3F-4D5E-8C6B-1F2A3B4C5D6E",
        "name": "iOSDC Japan 2026",
        "date": 1789743600
      }
    }
    """
    let data = json.data(using: .utf8)!
    let envelope = try CardPayload.decode(data)

    #expect(envelope.card.id == UUID(uuidString: "8F1C2A34-5B6D-4E7F-8091-A2B3C4D5E6F7"))
    #expect(envelope.card.name == "サンプル太郎")
    #expect(envelope.card.title == "iOSエンジニア")
    #expect(envelope.card.links.count == 2)
    #expect(envelope.card.links[0].kind == .github)
    #expect(envelope.card.links[0].value == "sample-taro")
    #expect(envelope.card.links[1].kind == .x)
    #expect(envelope.card.links[1].value == "sample_taro")
    #expect(envelope.card.style.paletteID == 3)
    #expect(envelope.card.style.patternID == 7)
    #expect(envelope.card.avatar == nil)
    #expect(envelope.event?.id == UUID(uuidString: "0B7E4C21-9A3F-4D5E-8C6B-1F2A3B4C5D6E"))
    #expect(envelope.event?.name == "iOSDC Japan 2026")
    #expect(envelope.event?.date.timeIntervalSince1970 == 1789743600)
    #expect(envelope.event?.venue == nil)
}
