import Foundation
import SwiftData
import MeilogCore

/// SwiftData を使った EncounterRepository の実装
actor SwiftDataEncounterRepository: EncounterRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @MainActor
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    func load() async throws -> [Encounter] {
        try await MainActor.run {
            let descriptor = FetchDescriptor<EncounterEntity>(
                sortBy: [SortDescriptor(\.lastMetAt, order: .reverse)]
            )

            let entities = try modelContext.fetch(descriptor)
            return try entities.map { try $0.toEncounter() }
        }
    }

    func save(_ encounter: Encounter) async throws {
        try await MainActor.run {
            // 既存のエンティティを探す
            let predicate = #Predicate<EncounterEntity> { entity in
                entity.id == encounter.id
            }
            let descriptor = FetchDescriptor(predicate: predicate)
            let existing = try modelContext.fetch(descriptor).first

            if let existing = existing {
                // 更新
                let entity = try EncounterEntity(from: encounter)
                existing.cardData = entity.cardData
                existing.meetingsData = entity.meetingsData
                existing.note = entity.note
                existing.avatarStateRaw = entity.avatarStateRaw
                existing.lastMetAt = entity.lastMetAt
            } else {
                // 新規作成
                let entity = try EncounterEntity(from: encounter)
                modelContext.insert(entity)
            }

            try modelContext.save()
        }
    }

    func delete(id: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<EncounterEntity> { entity in
                entity.id == id
            }
            let descriptor = FetchDescriptor(predicate: predicate)

            if let entity = try modelContext.fetch(descriptor).first {
                modelContext.delete(entity)
                try modelContext.save()
            }
        }
    }
}
