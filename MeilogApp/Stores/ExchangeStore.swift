import Foundation
import OSLog
import MeilogCore

/// Store for card exchange using Network.framework (MVI pattern)
@MainActor
@Observable
final class ExchangeStore {
    private(set) var state = ExchangeState()
    
    private let networkManager = ExchangeNetworkManager()
    private let repository: EncounterRepository
    private let myCardStore: MyCardStore
    private let logger = Logger(subsystem: "com.example.meilog", category: "ExchangeStore")
    
    init(repository: EncounterRepository, myCardStore: MyCardStore) {
        self.repository = repository
        self.myCardStore = myCardStore
        setupNetworkCallbacks()
    }
    
    /// Send intent to the reducer
    func send(_ intent: ExchangeIntent) {
        let (newState, effects) = reduce(state, intent)
        state = newState
        
        for effect in effects {
            run(effect)
        }
    }
    
    // MARK: - Private
    
    private func setupNetworkCallbacks() {
        networkManager.onPeerDiscovered = { [weak self] id, name, paletteID in
            self?.send(.peerDiscovered(id: id, name: name, paletteID: paletteID))
        }
        
        networkManager.onPeerLost = { [weak self] id in
            self?.send(.peerLost(id: id))
        }
        
        networkManager.onInvitationReceived = { [weak self] from, name, paletteID in
            self?.send(.invitationReceived(from: from, name: name, paletteID: paletteID))
        }
        
        networkManager.onDataReceived = { [weak self] envelope in
            self?.send(.dataReceived(envelope))
        }
        
        networkManager.onConnectionFailed = { [weak self] error in
            self?.send(.exchangeFailed(error.localizedDescription))
        }
        
        networkManager.onConnectionEstablished = { [weak self] in
            // Transition from inviting to exchanging
            if case .inviting = self?.state.connectionState {
                // Note: We'll update this to properly transition to exchanging
                // when we receive confirmation from the peer
            }
        }
    }
    
    private func run(_ effect: ExchangeEffect) {
        switch effect {
        case .startAdvertising(let card, _):
            do {
                try networkManager.startAdvertising(name: card.name, paletteID: card.style.paletteID)
            } catch {
                logger.error("Failed to start advertising: \(error.localizedDescription)")
                send(.exchangeFailed(error.localizedDescription))
            }
            
        case .stopAdvertising:
            networkManager.stopAdvertising()
            
        case .startBrowsing:
            networkManager.startBrowsing()
            
        case .stopBrowsing:
            networkManager.stopBrowsing()
            
        case .sendInvitation(let peerID):
            networkManager.sendInvitation(to: peerID)
            
        case .sendData(let envelope, let peerID):
            do {
                try networkManager.sendData(envelope, to: peerID)
            } catch {
                logger.error("Failed to send data: \(error.localizedDescription)")
                send(.exchangeFailed(error.localizedDescription))
            }
            
        case .saveEncounter(let envelope):
            Task {
                do {
                    // Check if this is a re-encounter
                    let existingEncounters = try await repository.load()
                    
                    if let existing = existingEncounters.first(where: { $0.card.id == envelope.card.id }) {
                        // Re-encounter: add new meeting
                        var updated = existing
                        let meeting = Meeting(
                            id: UUID(),
                            at: Date(),
                            event: envelope.event.map { .assigned($0, confidence: .confirmed) } ?? .unassigned
                        )
                        updated.meetings.insert(meeting, at: 0)
                        updated.card = envelope.card // Update to latest card
                        
                        try await repository.save(updated)
                    } else {
                        // New encounter
                        let meeting = Meeting(
                            id: UUID(),
                            at: Date(),
                            event: envelope.event.map { .assigned($0, confidence: .confirmed) } ?? .unassigned
                        )
                        let encounter = Encounter(
                            id: UUID(),
                            card: envelope.card,
                            meetings: [meeting],
                            note: ""
                        )
                        
                        try await repository.save(encounter)
                    }
                    
                    send(.exchangeCompleted)
                } catch {
                    logger.error("Failed to save encounter: \(error.localizedDescription)")
                    send(.exchangeFailed(error.localizedDescription))
                }
            }
        }
    }
}
