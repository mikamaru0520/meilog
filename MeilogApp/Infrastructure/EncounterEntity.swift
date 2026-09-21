import Foundation
import SwiftData
import MeilogCore

/// SwiftData 用の Encounter エンティティ
@Model
final class EncounterEntity {
    /// ID
    @Attribute(.unique) var id: UUID

    /// カードの JSON データ
    var cardData: Data

    /// ミーティングの JSON データの配列
    var meetingsData: [Data]

    /// メモ
    var note: String

    /// アイコンの状態（"notReceived", "received", "unavailable"）
    var avatarStateRaw: String

    /// 最後に会った日時（ソート用）
    var lastMetAt: Date?

    init(
        id: UUID,
        cardData: Data,
        meetingsData: [Data],
        note: String,
        avatarStateRaw: String,
        lastMetAt: Date?
    ) {
        self.id = id
        self.cardData = cardData
        self.meetingsData = meetingsData
        self.note = note
        self.avatarStateRaw = avatarStateRaw
        self.lastMetAt = lastMetAt
    }
}

// MARK: - Encounter ↔ EncounterEntity 変換

extension EncounterEntity {
    /// Core の Encounter から EncounterEntity を作成
    convenience init(from encounter: Encounter) throws {
        let cardData = try JSONEncoder().encode(encounter.card)
        let meetingsData = try encounter.meetings.map { try JSONEncoder().encode($0) }

        let avatarStateRaw: String
        switch encounter.avatarState {
        case .notReceived: avatarStateRaw = "notReceived"
        case .received: avatarStateRaw = "received"
        case .unavailable: avatarStateRaw = "unavailable"
        }

        self.init(
            id: encounter.id,
            cardData: cardData,
            meetingsData: meetingsData,
            note: encounter.note,
            avatarStateRaw: avatarStateRaw,
            lastMetAt: encounter.lastMetAt
        )
    }

    /// EncounterEntity から Core の Encounter に変換
    func toEncounter() throws -> Encounter {
        let card = try JSONDecoder().decode(Card.self, from: cardData)
        let meetings = try meetingsData.map { try JSONDecoder().decode(Meeting.self, from: $0) }

        let avatarState: AvatarState
        switch avatarStateRaw {
        case "received": avatarState = .received
        case "unavailable": avatarState = .unavailable
        default: avatarState = .notReceived
        }

        return Encounter(
            id: id,
            card: card,
            meetings: meetings,
            note: note,
            avatarState: avatarState
        )
    }
}
