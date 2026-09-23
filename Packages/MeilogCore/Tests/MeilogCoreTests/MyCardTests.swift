import Testing
@testable import MeilogCore
import Foundation

// MARK: - MyCard reduce のテスト

@Suite("MyCard reduce のテスト")
struct MyCardTests {
    @Test("appeared でロード Effect が発行される")
    func appeared_emitsLoadEffect() {
        let state = MyCardState()
        let (newState, effects) = reduce(state, .appeared)

        #expect(newState == state)
        #expect(effects == [.load])
    }

    @Test("loaded でカードとイベントが State に設定される")
    func loaded_updatesState() {
        let state = MyCardState()
        let card = Card(
            id: UUID(),
            name: "山田太郎",
            title: "iOS Developer",
            links: [],
            style: CardStyle(paletteID: 0, patternID: 0),
            avatar: nil
        )
        let event = MeetupEvent(
            id: UUID(),
            name: "Swift勉強会",
            date: Date(),
            venue: "東京"
        )

        let (newState, effects) = reduce(state, .loaded(card: card, recentEvent: event))

        #expect(newState.card == card)
        #expect(newState.recentEvent == event)
        #expect(effects.isEmpty)
    }

    @Test("cardSaved でカードが保存され永続化 Effect が発行される")
    func cardSaved_updatesStateAndEmitsEffect() {
        let state = MyCardState()
        let card = Card(
            id: UUID(),
            name: "佐藤花子",
            title: "Designer",
            links: [],
            style: CardStyle(paletteID: 1, patternID: 0),
            avatar: nil
        )

        let (newState, effects) = reduce(state, .cardSaved(card))

        #expect(newState.card == card)
        #expect(effects == [.persistCard(card)])
    }

    @Test("recentEventSaved でイベントが保存され永続化 Effect が発行される")
    func recentEventSaved_updatesStateAndEmitsEffect() {
        let state = MyCardState()
        let event = MeetupEvent(
            id: UUID(),
            name: "iOSDC 2024",
            date: Date(),
            venue: "東京"
        )

        let (newState, effects) = reduce(state, .recentEventSaved(event))

        #expect(newState.recentEvent == event)
        #expect(effects == [.persistRecentEvent(event)])
    }

    @Test("recentEventSaved に nil を渡すとイベントがクリアされる")
    func recentEventSaved_withNil_clearsEvent() {
        let event = MeetupEvent(
            id: UUID(),
            name: "Swift勉強会",
            date: Date(),
            venue: nil
        )
        let state = MyCardState(card: nil, recentEvent: event)

        let (newState, effects) = reduce(state, .recentEventSaved(nil))

        #expect(newState.recentEvent == nil)
        #expect(effects == [.persistRecentEvent(nil)])
    }

    @Test("isFirstLaunch は card が nil の時 true を返す")
    func isFirstLaunch_whenCardIsNil_returnsTrue() {
        let state = MyCardState()

        #expect(state.isFirstLaunch == true)
    }

    @Test("isFirstLaunch は card がある時 false を返す")
    func isFirstLaunch_whenCardExists_returnsFalse() {
        let card = Card(
            id: UUID(),
            name: "テスト",
            title: nil,
            links: [],
            style: CardStyle(paletteID: 0, patternID: 0),
            avatar: nil
        )
        let state = MyCardState(card: card, recentEvent: nil)

        #expect(state.isFirstLaunch == false)
    }
}
