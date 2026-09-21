import Testing
import Foundation
@testable import MeilogCore

@Test func Cardは初期化できる() {
    let card = Card(
        id: UUID(),
        name: "山田太郎",
        title: "iOS Engineer",
        links: [Link(kind: .github, value: "yamada")],
        style: CardStyle(paletteID: 1, patternID: 2)
    )
    #expect(card.name == "山田太郎")
    #expect(card.title == "iOS Engineer")
    #expect(card.links.count == 1)
    #expect(card.avatar == nil)
}

@Test func CardはCodableである() throws {
    let card = Card(
        id: UUID(),
        name: "山田太郎",
        links: [],
        style: CardStyle(paletteID: 0, patternID: 0)
    )
    let data = try JSONEncoder().encode(card)
    let decoded = try JSONDecoder().decode(Card.self, from: data)
    #expect(decoded == card)
}

@Test func EventAssignmentはイベント情報を取得できる() {
    let event = MeetupEvent(id: UUID(), name: "もくもく会", date: Date())
    let assigned = EventAssignment.assigned(event, confidence: .confirmed)
    #expect(assigned.event == event)
    #expect(assigned.confidence == .confirmed)

    let unassigned = EventAssignment.unassigned
    #expect(unassigned.event == nil)
    #expect(unassigned.confidence == nil)

    let none = EventAssignment.none
    #expect(none.event == nil)
}

@Test func Encounterは最後に会った日時を返す() {
    let card = Card(
        id: UUID(),
        name: "佐藤花子",
        links: [],
        style: CardStyle(paletteID: 0, patternID: 0)
    )
    let date1 = Date(timeIntervalSince1970: 1000)
    let date2 = Date(timeIntervalSince1970: 2000)
    let meeting1 = Meeting(id: UUID(), at: date1, event: .unassigned)
    let meeting2 = Meeting(id: UUID(), at: date2, event: .unassigned)

    // meetings は新しい順
    let encounter = Encounter(
        id: UUID(),
        card: card,
        meetings: [meeting2, meeting1]
    )
    #expect(encounter.lastMetAt == date2)
}

@Test func Encounterのmeetingsが空の場合lastMetAtはnil() {
    let card = Card(
        id: UUID(),
        name: "佐藤花子",
        links: [],
        style: CardStyle(paletteID: 0, patternID: 0)
    )
    let encounter = Encounter(id: UUID(), card: card, meetings: [])
    #expect(encounter.lastMetAt == nil)
}
