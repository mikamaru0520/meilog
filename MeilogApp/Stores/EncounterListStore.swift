import Foundation
import OSLog
import MeilogCore

/// Encounter 一覧を管理する Store
@MainActor
@Observable
final class EncounterListStore {
    private(set) var state = EncounterListState()

    private let repository: EncounterRepository
    private let myCardStore: MyCardStore
    // Task.cancel() is thread-safe, and we don't need to observe this array
    @ObservationIgnored private var runningTasks: [Task<Void, Never>] = []
    private let logger = Logger(subsystem: "com.example.meilog", category: "EncounterListStore")

    init(repository: EncounterRepository, myCardStore: MyCardStore) {
        self.repository = repository
        self.myCardStore = myCardStore
    }

    deinit {
        runningTasks.forEach { $0.cancel() }
    }

    /// Intent を送信する
    func send(_ intent: EncounterListIntent) {
        let (newState, effects) = reduce(state, intent)
        state = newState

        for effect in effects {
            run(effect)
        }
    }

    // MARK: - Private

    private func run(_ effect: EncounterListEffect) {
        switch effect {
        case .load:
            let task = Task {
                do {
                    let encounters = try await repository.load()
                    guard !Task.isCancelled else { return }
                    send(.loaded(encounters, recentEvent: myCardStore.recentEvent))
                } catch {
                    guard !Task.isCancelled else { return }
                    logger.error("Failed to load encounters: \(error.localizedDescription)")
                }
            }
            runningTasks.append(task)

        case .persist(let encounter):
            let task = Task {
                do {
                    try await repository.save(encounter)
                } catch {
                    guard !Task.isCancelled else { return }
                    logger.error("Failed to save encounter: \(error.localizedDescription)")
                }
            }
            runningTasks.append(task)

        case .delete(let encounterID):
            let task = Task {
                do {
                    try await repository.delete(id: encounterID)
                } catch {
                    guard !Task.isCancelled else { return }
                    logger.error("Failed to delete encounter: \(error.localizedDescription)")
                }
            }
            runningTasks.append(task)

        case .requestAvatar(let encounterID, let rendezvous):
            // TODO: Step 7 で MultipeerConnectivity を実装
            logger.debug("TODO: Request avatar for \(encounterID) with rendezvous \(rendezvous)")
            // 現時点では unavailable として扱う
            let task = Task {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                send(.avatarFailed(encounterID: encounterID))
            }
            runningTasks.append(task)
        }
    }
}
