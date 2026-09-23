import Foundation
import Testing
@testable import MeilogCore

@Suite("EncounterList reduce のテスト")
struct EncounterListTests {
    // MARK: - Helper

    /// テスト用のカレンダー（UTC）
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// テスト用の日付を作成
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(identifier: "UTC")
        return calendar.date(from: components)!
    }

    /// テスト用のカードを作成
    private func makeCard(
        id: UUID = UUID(),
        name: String = "Alice",
        title: String? = nil
    ) -> Card {
        Card(
            id: id,
            name: name,
            title: title,
            links: [],
            style: CardStyle(paletteID: 0, patternID: 0),
            avatar: nil
        )
    }

    /// テスト用のイベントを作成
    private func makeEvent(
        id: UUID = UUID(),
        name: String = "Swift勉強会",
        date: Date
    ) -> MeetupEvent {
        MeetupEvent(id: id, name: name, date: date, venue: nil)
    }

    // MARK: - appeared のテスト

    @Test("appeared でロード Effect が発行される")
    func appeared_emitsLoadEffect() {
        let state = EncounterListState()

        let (_, effects) = reduce(state, .appeared)

        #expect(effects == [.load])
    }

    // MARK: - loaded のテスト

    @Test("loaded で Encounter が最後に会った日時の新しい順にソートされる")
    func loaded_sortsEncountersByLastMetAt() {
        let oldDate = date(2026, 1, 1)
        let newDate = date(2026, 1, 10)

        let encounterOld = Encounter(
            id: UUID(),
            card: makeCard(name: "Alice"),
            meetings: [Meeting(id: UUID(), at: oldDate, event: .unassigned)],
            note: "",
            avatarState: .notReceived
        )

        let encounterNew = Encounter(
            id: UUID(),
            card: makeCard(name: "Bob"),
            meetings: [Meeting(id: UUID(), at: newDate, event: .unassigned)],
            note: "",
            avatarState: .notReceived
        )

        let state = EncounterListState()

        let (newState, _) = reduce(state, .loaded([encounterOld, encounterNew], recentEvent: nil))

        #expect(newState.encounters.count == 2)
        #expect(newState.encounters[0].card.name == "Bob")  // 新しい方が先
        #expect(newState.encounters[1].card.name == "Alice")
    }

    // MARK: - queryChanged のテスト

    @Test("queryChanged でクエリが更新される")
    func queryChanged_updatesQuery() {
        let state = EncounterListState()

        let (newState, _) = reduce(state, .queryChanged("Swift"))

        #expect(newState.query == "Swift")
    }

    @Test("filteredEncounters が名前でフィルタリングされる")
    func filteredEncounters_filtersByName() {
        let encounterAlice = Encounter(
            id: UUID(),
            card: makeCard(name: "Alice"),
            meetings: [],
            note: "",
            avatarState: .notReceived
        )

        let encounterBob = Encounter(
            id: UUID(),
            card: makeCard(name: "Bob"),
            meetings: [],
            note: "",
            avatarState: .notReceived
        )

        var state = EncounterListState(encounters: [encounterAlice, encounterBob])
        state.query = "alice"

        #expect(state.filteredEncounters.count == 1)
        #expect(state.filteredEncounters[0].card.name == "Alice")
    }

    @Test("filteredEncounters が肩書きでフィルタリングされる")
    func filteredEncounters_filtersByTitle() {
        let encounterWithTitle = Encounter(
            id: UUID(),
            card: makeCard(name: "Alice", title: "iOS Developer"),
            meetings: [],
            note: "",
            avatarState: .notReceived
        )

        let encounterWithoutTitle = Encounter(
            id: UUID(),
            card: makeCard(name: "Bob"),
            meetings: [],
            note: "",
            avatarState: .notReceived
        )

        var state = EncounterListState(encounters: [encounterWithTitle, encounterWithoutTitle])
        state.query = "developer"

        #expect(state.filteredEncounters.count == 1)
        #expect(state.filteredEncounters[0].card.name == "Alice")
    }

    @Test("filteredEncounters がイベント名でフィルタリングされる")
    func filteredEncounters_filtersByEventName() {
        let event = makeEvent(name: "Swift勉強会", date: date(2026, 1, 1))
        let meeting = Meeting(id: UUID(), at: date(2026, 1, 1), event: .assigned(event, confidence: .confirmed))

        let encounterWithEvent = Encounter(
            id: UUID(),
            card: makeCard(name: "Alice"),
            meetings: [meeting],
            note: "",
            avatarState: .notReceived
        )

        let encounterWithoutEvent = Encounter(
            id: UUID(),
            card: makeCard(name: "Bob"),
            meetings: [],
            note: "",
            avatarState: .notReceived
        )

        var state = EncounterListState(encounters: [encounterWithEvent, encounterWithoutEvent])
        state.query = "swift"

        #expect(state.filteredEncounters.count == 1)
        #expect(state.filteredEncounters[0].card.name == "Alice")
    }

    // MARK: - cardReceived のテスト（3段フォールバック）

    @Test("QRにイベントが入っていたら confirmed で割り当てられる")
    func cardReceived_withQREvent_assignsConfirmed() {
        let state = EncounterListState()
        let eventDate = date(2026, 1, 1)
        let event = makeEvent(name: "Swift勉強会", date: eventDate)
        let card = makeCard(name: "Alice")
        let envelope = CardEnvelope(card: card, event: event, rendezvous: nil)

        let (newState, effects) = reduce(
            state,
            .cardReceived(envelope, now: eventDate, newID: UUID(), calendar: calendar)
        )

        #expect(newState.encounters.count == 1)
        let encounter = newState.encounters[0]
        #expect(encounter.meetings.count == 1)

        if case .assigned(let assignedEvent, confidence: .confirmed) = encounter.meetings[0].event {
            #expect(assignedEvent.name == "Swift勉強会")
        } else {
            Issue.record("イベントが confirmed で割り当てられていない")
        }

        // persist Effect が発行される
        #expect(effects.contains(.persist(encounter)))
    }

    @Test("QRにイベントがなく直近のイベントと同じ日なら inferred で割り当てられる")
    func cardReceived_withRecentEventSameDay_assignsInferred() {
        let eventDate = date(2026, 1, 1)
        let recentEvent = makeEvent(name: "もくもく会", date: eventDate)
        let state = EncounterListState(recentEvent: recentEvent)

        let card = makeCard(name: "Bob")
        let envelope = CardEnvelope(card: card, event: nil, rendezvous: nil)

        let (newState, _) = reduce(
            state,
            .cardReceived(envelope, now: eventDate, newID: UUID(), calendar: calendar)
        )

        #expect(newState.encounters.count == 1)
        let encounter = newState.encounters[0]
        #expect(encounter.meetings.count == 1)

        if case .assigned(let assignedEvent, confidence: .inferred) = encounter.meetings[0].event {
            #expect(assignedEvent.name == "もくもく会")
        } else {
            Issue.record("イベントが inferred で割り当てられていない")
        }
    }

    @Test("QRにイベントがなく直近のイベントと違う日なら unassigned になる")
    func cardReceived_withRecentEventDifferentDay_assignsUnassigned() {
        let eventDate = date(2026, 1, 1)
        let recentEvent = makeEvent(name: "もくもく会", date: eventDate)
        let state = EncounterListState(recentEvent: recentEvent)

        let card = makeCard(name: "Charlie")
        let envelope = CardEnvelope(card: card, event: nil, rendezvous: nil)

        let differentDate = date(2026, 1, 2)  // 1日後

        let (newState, _) = reduce(
            state,
            .cardReceived(envelope, now: differentDate, newID: UUID(), calendar: calendar)
        )

        #expect(newState.encounters.count == 1)
        let encounter = newState.encounters[0]
        #expect(encounter.meetings.count == 1)

        if case .unassigned = encounter.meetings[0].event {
            // OK
        } else {
            Issue.record("イベントが unassigned になっていない")
        }
    }

    @Test("QRにイベントがなく直近のイベントもない場合は unassigned になる")
    func cardReceived_withoutAnyEvent_assignsUnassigned() {
        let state = EncounterListState(recentEvent: nil)

        let card = makeCard(name: "Dave")
        let envelope = CardEnvelope(card: card, event: nil, rendezvous: nil)

        let (newState, _) = reduce(
            state,
            .cardReceived(envelope, now: date(2026, 1, 1), newID: UUID(), calendar: calendar)
        )

        #expect(newState.encounters.count == 1)
        let encounter = newState.encounters[0]
        #expect(encounter.meetings.count == 1)

        if case .unassigned = encounter.meetings[0].event {
            // OK
        } else {
            Issue.record("イベントが unassigned になっていない")
        }
    }

    // MARK: - cardReceived のテスト（再会検出）

    @Test("同じ card.id のカードを受け取ったら Meeting が追加される")
    func cardReceived_sameCardID_addsMeeting() {
        let cardID = UUID()
        let oldCard = makeCard(id: cardID, name: "Alice v1")
        let oldMeeting = Meeting(id: UUID(), at: date(2026, 1, 1), event: .unassigned)
        let existingEncounter = Encounter(
            id: UUID(),
            card: oldCard,
            meetings: [oldMeeting],
            note: "メモ",
            avatarState: .received
        )

        let state = EncounterListState(encounters: [existingEncounter])

        // 同じ card.id で名前が更新されたカード
        let newCard = makeCard(id: cardID, name: "Alice v2")
        let envelope = CardEnvelope(card: newCard, event: nil, rendezvous: nil)

        let (newState, _) = reduce(
            state,
            .cardReceived(envelope, now: date(2026, 1, 10), newID: UUID(), calendar: calendar)
        )

        // Encounter は増えない
        #expect(newState.encounters.count == 1)

        let encounter = newState.encounters[0]

        // カードが最新に更新される
        #expect(encounter.card.name == "Alice v2")

        // Meeting が追加される
        #expect(encounter.meetings.count == 2)

        // 新しい Meeting が先頭に追加される
        #expect(encounter.meetings[0].at == date(2026, 1, 10))
        #expect(encounter.meetings[1].at == date(2026, 1, 1))

        // メモは保持される
        #expect(encounter.note == "メモ")
    }

    @Test("異なる card.id のカードを受け取ったら新しい Encounter が追加される")
    func cardReceived_differentCardID_addsNewEncounter() {
        let existingEncounter = Encounter(
            id: UUID(),
            card: makeCard(id: UUID(), name: "Alice"),
            meetings: [Meeting(id: UUID(), at: date(2026, 1, 1), event: .unassigned)],
            note: "",
            avatarState: .notReceived
        )

        let state = EncounterListState(encounters: [existingEncounter])

        // 異なる card.id
        let newCard = makeCard(id: UUID(), name: "Bob")
        let envelope = CardEnvelope(card: newCard, event: nil, rendezvous: nil)

        let (newState, _) = reduce(
            state,
            .cardReceived(envelope, now: date(2026, 1, 2), newID: UUID(), calendar: calendar)
        )

        // Encounter が増える
        #expect(newState.encounters.count == 2)

        // 新しい Encounter が先頭に追加される
        #expect(newState.encounters[0].card.name == "Bob")
        #expect(newState.encounters[1].card.name == "Alice")
    }

    @Test("rendezvous があればアイコンリクエスト Effect が発行される")
    func cardReceived_withRendezvous_emitsRequestAvatarEffect() {
        let state = EncounterListState()
        let card = makeCard(name: "Alice")
        let envelope = CardEnvelope(card: card, event: nil, rendezvous: "abc12345")

        let (newState, effects) = reduce(
            state,
            .cardReceived(envelope, now: date(2026, 1, 1), newID: UUID(), calendar: calendar)
        )

        let encounterID = newState.encounters[0].id

        #expect(effects.contains(.requestAvatar(encounterID: encounterID, rendezvous: "abc12345")))
    }

    // MARK: - avatarArrived のテスト

    @Test("avatarArrived でアイコンが保存され avatarState が received になる")
    func avatarArrived_savesAvatarAndUpdatesState() {
        let encounterID = UUID()
        let encounter = Encounter(
            id: encounterID,
            card: makeCard(name: "Alice"),
            meetings: [],
            note: "",
            avatarState: .notReceived
        )

        let state = EncounterListState(encounters: [encounter])

        let avatarData = Data([1, 2, 3])

        let (newState, effects) = reduce(state, .avatarArrived(encounterID: encounterID, data: avatarData))

        #expect(newState.encounters.count == 1)
        #expect(newState.encounters[0].card.avatar == avatarData)
        #expect(newState.encounters[0].avatarState == .received)

        // persist Effect が発行される
        #expect(effects.contains(.persist(newState.encounters[0])))
    }

    // MARK: - avatarFailed のテスト

    @Test("avatarFailed で avatarState が unavailable になる")
    func avatarFailed_updatesStateToUnavailable() {
        let encounterID = UUID()
        let encounter = Encounter(
            id: encounterID,
            card: makeCard(name: "Alice"),
            meetings: [],
            note: "",
            avatarState: .notReceived
        )

        let state = EncounterListState(encounters: [encounter])

        let (newState, effects) = reduce(state, .avatarFailed(encounterID: encounterID))

        #expect(newState.encounters.count == 1)
        #expect(newState.encounters[0].avatarState == .unavailable)

        // persist Effect が発行される
        #expect(effects.contains(.persist(newState.encounters[0])))
    }

    // MARK: - assignEvent のテスト

    @Test("assignEvent で指定した Meeting がイベントに割り当てられる")
    func assignEvent_assignsMeetingsToEvent() {
        let meeting1 = Meeting(id: UUID(), at: date(2026, 1, 1), event: .unassigned)
        let meeting2 = Meeting(id: UUID(), at: date(2026, 1, 2), event: .unassigned)

        let encounter = Encounter(
            id: UUID(),
            card: makeCard(name: "Alice"),
            meetings: [meeting1, meeting2],
            note: "",
            avatarState: .notReceived
        )

        let state = EncounterListState(encounters: [encounter])

        let event = makeEvent(name: "Swift勉強会", date: date(2026, 1, 1))

        let (newState, effects) = reduce(
            state,
            .assignEvent(meetingIDs: [meeting1.id], event: event)
        )

        #expect(newState.encounters.count == 1)
        let updatedEncounter = newState.encounters[0]

        // meeting1 がイベントに割り当てられる（confirmed）
        if case .assigned(let assignedEvent, confidence: .confirmed) = updatedEncounter.meetings[0].event {
            #expect(assignedEvent.name == "Swift勉強会")
        } else {
            Issue.record("meeting1 がイベントに割り当てられていない")
        }

        // meeting2 は変更されない
        if case .unassigned = updatedEncounter.meetings[1].event {
            // OK
        } else {
            Issue.record("meeting2 が unassigned のままでない")
        }

        // persist Effect が発行される
        #expect(effects.contains(.persist(updatedEncounter)))
    }

    // MARK: - markAsNoEvent のテスト

    @Test("markAsNoEvent で指定した Meeting が none になる")
    func markAsNoEvent_marksMeetingsAsNone() {
        let meeting1 = Meeting(id: UUID(), at: date(2026, 1, 1), event: .unassigned)
        let meeting2 = Meeting(id: UUID(), at: date(2026, 1, 2), event: .unassigned)

        let encounter = Encounter(
            id: UUID(),
            card: makeCard(name: "Alice"),
            meetings: [meeting1, meeting2],
            note: "",
            avatarState: .notReceived
        )

        let state = EncounterListState(encounters: [encounter])

        let (newState, effects) = reduce(
            state,
            .markAsNoEvent(meetingIDs: [meeting1.id])
        )

        #expect(newState.encounters.count == 1)
        let updatedEncounter = newState.encounters[0]

        // meeting1 が none になる
        if case .none = updatedEncounter.meetings[0].event {
            // OK
        } else {
            Issue.record("meeting1 が none になっていない")
        }

        // meeting2 は変更されない
        if case .unassigned = updatedEncounter.meetings[1].event {
            // OK
        } else {
            Issue.record("meeting2 が unassigned のままでない")
        }

        // persist Effect が発行される
        #expect(effects.contains(.persist(updatedEncounter)))
    }

    // MARK: - deleteRequested のテスト

    @Test("deleteRequested で Encounter が削除される")
    func deleteRequested_deletesEncounter() {
        let encounterID = UUID()
        let encounter = Encounter(
            id: encounterID,
            card: makeCard(name: "Alice"),
            meetings: [],
            note: "",
            avatarState: .notReceived
        )

        let state = EncounterListState(encounters: [encounter])

        let (newState, effects) = reduce(state, .deleteRequested(encounterID: encounterID))

        #expect(newState.encounters.isEmpty)

        // delete Effect が発行される
        #expect(effects.contains(.delete(encounterID: encounterID)))
    }

    // MARK: - unassignedCount のテスト

    @Test("unassignedCount が正しく計算される")
    func unassignedCount_calculatesCorrectly() {
        let meeting1 = Meeting(id: UUID(), at: date(2026, 1, 1), event: .unassigned)
        let meeting2 = Meeting(id: UUID(), at: date(2026, 1, 2), event: .unassigned)
        let meeting3 = Meeting(
            id: UUID(),
            at: date(2026, 1, 3),
            event: .assigned(makeEvent(date: date(2026, 1, 3)), confidence: .confirmed)
        )

        let encounter = Encounter(
            id: UUID(),
            card: makeCard(name: "Alice"),
            meetings: [meeting1, meeting2, meeting3],
            note: "",
            avatarState: .notReceived
        )

        let state = EncounterListState(encounters: [encounter])

        #expect(state.unassignedCount == 2)
    }

    // MARK: - inferredCount のテスト

    @Test("inferredCount が正しく計算される")
    func inferredCount_calculatesCorrectly() {
        let meeting1 = Meeting(
            id: UUID(),
            at: date(2026, 1, 1),
            event: .assigned(makeEvent(date: date(2026, 1, 1)), confidence: .inferred)
        )
        let meeting2 = Meeting(
            id: UUID(),
            at: date(2026, 1, 2),
            event: .assigned(makeEvent(date: date(2026, 1, 2)), confidence: .confirmed)
        )
        let meeting3 = Meeting(id: UUID(), at: date(2026, 1, 3), event: .unassigned)

        let encounter = Encounter(
            id: UUID(),
            card: makeCard(name: "Alice"),
            meetings: [meeting1, meeting2, meeting3],
            note: "",
            avatarState: .notReceived
        )

        let state = EncounterListState(encounters: [encounter])

        #expect(state.inferredCount == 1)
    }

    // MARK: - noteUpdated のテスト

    @Test("noteUpdated でメモが更新される")
    func noteUpdated() {
        let encounterID = UUID()
        let encounter = Encounter(
            id: encounterID,
            card: makeCard(name: "Alice"),
            meetings: [],
            note: "古いメモ",
            avatarState: .notReceived
        )

        let state = EncounterListState(encounters: [encounter])

        let (newState, effects) = reduce(state, .noteUpdated(encounterID: encounterID, note: "新しいメモ"))

        // メモが更新されている
        #expect(newState.encounters.first?.note == "新しいメモ")

        // persist Effect が発行されている
        #expect(effects.count == 1)
        if case .persist(let persistedEncounter) = effects[0] {
            #expect(persistedEncounter.note == "新しいメモ")
        } else {
            Issue.record("Expected .persist effect")
        }
    }

    @Test("noteUpdated で存在しない Encounter は無視される")
    func noteUpdatedNonExistent() {
        let encounter = Encounter(
            id: UUID(),
            card: makeCard(name: "Alice"),
            meetings: [],
            note: "メモ",
            avatarState: .notReceived
        )

        let state = EncounterListState(encounters: [encounter])

        let (newState, effects) = reduce(state, .noteUpdated(encounterID: UUID(), note: "新しいメモ"))

        // 状態は変わっていない
        #expect(newState.encounters.first?.note == "メモ")

        // Effect は発行されていない
        #expect(effects.isEmpty)
    }
}
