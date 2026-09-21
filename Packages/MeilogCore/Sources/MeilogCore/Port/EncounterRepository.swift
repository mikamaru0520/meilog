import Foundation

/// Encounter の永続化を担当する Repository
public protocol EncounterRepository: Sendable {
    /// すべての Encounter をロードする
    func load() async throws -> [Encounter]

    /// Encounter を保存する（新規作成または更新）
    func save(_ encounter: Encounter) async throws

    /// Encounter を削除する
    func delete(id: UUID) async throws
}
