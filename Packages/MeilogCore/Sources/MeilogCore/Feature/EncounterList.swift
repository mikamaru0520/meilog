import Foundation

// MARK: - State

public struct EncounterListState: Equatable, Sendable {
    /// すべての Encounter（最後に会った日時の新しい順）
    public var encounters: [Encounter] = []

    /// 直近のイベント（3段フォールバックで使う）
    public var recentEvent: MeetupEvent?

    /// 検索クエリ
    public var query: String = ""

    public init(
        encounters: [Encounter] = [],
        recentEvent: MeetupEvent? = nil,
        query: String = ""
    ) {
        self.encounters = encounters
        self.recentEvent = recentEvent
        self.query = query
    }

    /// フィルタリングされた Encounter 一覧
    public var filteredEncounters: [Encounter] {
        if query.isEmpty {
            return encounters
        }

        let lowercasedQuery = query.lowercased()
        return encounters.filter { encounter in
            // 名前で検索
            if encounter.card.name.lowercased().contains(lowercasedQuery) {
                return true
            }

            // 肩書きで検索
            if let title = encounter.card.title,
               title.lowercased().contains(lowercasedQuery) {
                return true
            }

            // イベント名で検索
            for meeting in encounter.meetings {
                if case .assigned(let event, _) = meeting.event,
                   event.name.lowercased().contains(lowercasedQuery) {
                    return true
                }
            }

            return false
        }
    }

    /// 未割り当て（unassigned）の Meeting の数
    public var unassignedCount: Int {
        encounters.reduce(0) { count, encounter in
            count + encounter.meetings.filter { meeting in
                if case .unassigned = meeting.event {
                    return true
                }
                return false
            }.count
        }
    }

    /// 推測された（inferred）Meeting の数
    public var inferredCount: Int {
        encounters.reduce(0) { count, encounter in
            count + encounter.meetings.filter { meeting in
                if case .assigned(_, confidence: .inferred) = meeting.event {
                    return true
                }
                return false
            }.count
        }
    }
}

// MARK: - Intent

public enum EncounterListIntent: Sendable {
    /// 画面が表示された
    case appeared

    /// データがロードされた
    case loaded([Encounter], recentEvent: MeetupEvent?)

    /// 検索クエリが変更された
    case queryChanged(String)

    /// QR からカードを受信した
    case cardReceived(CardEnvelope, now: Date, newID: UUID, calendar: Calendar)

    /// アイコン画像が届いた
    case avatarArrived(encounterID: UUID, data: Data)

    /// アイコン取得に失敗した
    case avatarFailed(encounterID: UUID)

    /// 指定した Meeting をイベントに割り当てる
    case assignEvent(meetingIDs: [UUID], event: MeetupEvent)

    /// 指定した Meeting を「イベント外」にマークする
    case markAsNoEvent(meetingIDs: [UUID])

    /// Encounter の削除が要求された
    case deleteRequested(encounterID: UUID)
}

// MARK: - Effect

public enum EncounterListEffect: Equatable, Sendable {
    /// データをロードする
    case load

    /// Encounter を永続化する
    case persist(Encounter)

    /// Encounter を削除する
    case delete(encounterID: UUID)

    /// アイコン画像をリクエストする
    case requestAvatar(encounterID: UUID, rendezvous: String)
}

// MARK: - Reduce

/// EncounterList の reduce 関数
///
/// - Parameters:
///   - state: 現在の State
///   - intent: Intent
/// - Returns: 新しい State と Effect の配列
public func reduce(
    _ state: EncounterListState,
    _ intent: EncounterListIntent
) -> (EncounterListState, [EncounterListEffect]) {
    var state = state
    var effects: [EncounterListEffect] = []

    switch intent {
    case .appeared:
        // ロード Effect を発行
        effects.append(.load)

    case let .loaded(encounters, recentEvent):
        // ロードされた Encounter を最後に会った日時の新しい順にソート
        state.encounters = encounters.sorted { lhs, rhs in
            guard let lhsDate = lhs.lastMetAt, let rhsDate = rhs.lastMetAt else {
                // lastMetAt が nil の場合は後ろに
                return lhs.lastMetAt != nil
            }
            return lhsDate > rhsDate
        }
        state.recentEvent = recentEvent

    case let .queryChanged(query):
        state.query = query

    case let .cardReceived(envelope, now, newID, calendar):
        // 再会検出: 同じ card.id を持つ Encounter を探す
        if let existingIndex = state.encounters.firstIndex(where: { $0.card.id == envelope.card.id }) {
            // 既存の Encounter を更新
            var encounter = state.encounters[existingIndex]

            // カードを最新に更新
            encounter.card = envelope.card

            // 新しい Meeting を作成
            let meeting = createMeeting(
                envelope: envelope,
                now: now,
                newID: newID,
                calendar: calendar,
                recentEvent: state.recentEvent
            )

            // meetings の先頭に追加
            encounter.meetings.insert(meeting, at: 0)

            // Encounter を更新
            state.encounters[existingIndex] = encounter

            // 永続化 Effect を発行
            effects.append(.persist(encounter))

            // rendezvous があればアイコンをリクエスト
            if let rendezvous = envelope.rendezvous {
                effects.append(.requestAvatar(encounterID: encounter.id, rendezvous: rendezvous))
            }
        } else {
            // 新しい Encounter を作成
            let meeting = createMeeting(
                envelope: envelope,
                now: now,
                newID: newID,
                calendar: calendar,
                recentEvent: state.recentEvent
            )

            let encounter = Encounter(
                id: newID,
                card: envelope.card,
                meetings: [meeting],
                note: "",
                avatarState: .notReceived
            )

            // encounters の先頭に追加（新しい順）
            state.encounters.insert(encounter, at: 0)

            // 永続化 Effect を発行
            effects.append(.persist(encounter))

            // rendezvous があればアイコンをリクエスト
            if let rendezvous = envelope.rendezvous {
                effects.append(.requestAvatar(encounterID: encounter.id, rendezvous: rendezvous))
            }
        }

    case let .avatarArrived(encounterID, data):
        // Encounter を探して avatar を更新
        if let index = state.encounters.firstIndex(where: { $0.id == encounterID }) {
            var encounter = state.encounters[index]
            encounter.card.avatar = data
            encounter.avatarState = .received
            state.encounters[index] = encounter

            // 永続化 Effect を発行
            effects.append(.persist(encounter))
        }

    case let .avatarFailed(encounterID):
        // Encounter を探して avatarState を unavailable に更新
        if let index = state.encounters.firstIndex(where: { $0.id == encounterID }) {
            var encounter = state.encounters[index]
            encounter.avatarState = .unavailable
            state.encounters[index] = encounter

            // 永続化 Effect を発行
            effects.append(.persist(encounter))
        }

    case let .assignEvent(meetingIDs, event):
        // 指定された Meeting をイベントに割り当てる
        var updatedEncounters: [Encounter] = []

        for var encounter in state.encounters {
            var updated = false

            for (index, meeting) in encounter.meetings.enumerated() {
                if meetingIDs.contains(meeting.id) {
                    encounter.meetings[index].event = .assigned(event, confidence: .confirmed)
                    updated = true
                }
            }

            if updated {
                updatedEncounters.append(encounter)

                // Encounter を更新
                if let stateIndex = state.encounters.firstIndex(where: { $0.id == encounter.id }) {
                    state.encounters[stateIndex] = encounter
                }
            }
        }

        // 更新された Encounter を永続化
        for encounter in updatedEncounters {
            effects.append(.persist(encounter))
        }

    case let .markAsNoEvent(meetingIDs):
        // 指定された Meeting を「イベント外」にマークする
        var updatedEncounters: [Encounter] = []

        for var encounter in state.encounters {
            var updated = false

            for (index, meeting) in encounter.meetings.enumerated() {
                if meetingIDs.contains(meeting.id) {
                    encounter.meetings[index].event = .none
                    updated = true
                }
            }

            if updated {
                updatedEncounters.append(encounter)

                // Encounter を更新
                if let stateIndex = state.encounters.firstIndex(where: { $0.id == encounter.id }) {
                    state.encounters[stateIndex] = encounter
                }
            }
        }

        // 更新された Encounter を永続化
        for encounter in updatedEncounters {
            effects.append(.persist(encounter))
        }

    case let .deleteRequested(encounterID):
        // Encounter を削除
        state.encounters.removeAll { $0.id == encounterID }

        // 削除 Effect を発行
        effects.append(.delete(encounterID: encounterID))
    }

    return (state, effects)
}

// MARK: - Private Helpers

/// Meeting を作成する（3段フォールバック）
private func createMeeting(
    envelope: CardEnvelope,
    now: Date,
    newID: UUID,
    calendar: Calendar,
    recentEvent: MeetupEvent?
) -> Meeting {
    let eventAssignment: EventAssignment

    if let qrEvent = envelope.event {
        // 1. QR にイベントが入っている
        eventAssignment = .assigned(qrEvent, confidence: .confirmed)
    } else if let recent = recentEvent, calendar.isDate(recent.date, inSameDayAs: now) {
        // 2. 直近のイベントの日付が受信日と同じ日
        eventAssignment = .assigned(recent, confidence: .inferred)
    } else {
        // 3. どちらもない
        eventAssignment = .unassigned
    }

    return Meeting(id: newID, at: now, event: eventAssignment)
}
