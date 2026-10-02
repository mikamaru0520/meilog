import Foundation

// MARK: - State

/// State for card exchange screen
public struct ExchangeState: Equatable, Sendable {
    /// Connection state
    public var connectionState: ConnectionState

    /// List of nearby discovered peers
    public var nearbyPeers: [Peer]

    /// ID of the peer we sent invitation to
    public var invitedPeerID: String?

    /// Peer information of received invitation
    public var receivedInvitation: Peer?

    /// Error message
    public var errorMessage: String?

    public init(
        connectionState: ConnectionState = .idle,
        nearbyPeers: [Peer] = [],
        invitedPeerID: String? = nil,
        receivedInvitation: Peer? = nil,
        errorMessage: String? = nil
    ) {
        self.connectionState = connectionState
        self.nearbyPeers = nearbyPeers
        self.invitedPeerID = invitedPeerID
        self.receivedInvitation = receivedInvitation
        self.errorMessage = errorMessage
    }
}

/// Connection state
public enum ConnectionState: Equatable, Sendable {
    case idle
    case browsing
    case inviting(peerID: String)
    case waitingForApproval(peerID: String)
    case connecting(peerID: String)
    case exchanging(peerID: String)
    case completed
    case failed(String)
}

/// Information about nearby peer
public struct Peer: Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let paletteID: Int

    public init(id: String, name: String, paletteID: Int) {
        self.id = id
        self.name = name
        self.paletteID = paletteID
    }
}

// MARK: - Intent

/// Intent for card exchange
public enum ExchangeIntent: Sendable {
    case appeared
    case browsingStarted
    case peerDiscovered(id: String, name: String, paletteID: Int)
    case peerLost(id: String)
    case inviteTapped(peerID: String)
    case invitationReceived(from: String, name: String, paletteID: Int)
    case invitationAccepted
    case invitationDeclined
    case dataReceived(CardEnvelope)
    case exchangeCompleted
    case exchangeFailed(String)
    case dismissed
}

// MARK: - Effect

/// Effect for card exchange
public enum ExchangeEffect: Equatable, Sendable {
    case startAdvertising(card: Card, event: MeetupEvent?)
    case stopAdvertising
    case startBrowsing
    case stopBrowsing
    case sendInvitation(to: String)
    case sendData(CardEnvelope, to: String)
    case saveEncounter(CardEnvelope)
}

// MARK: - Reducer

/// Exchange reduce function
public func reduce(
    _ state: ExchangeState,
    _ intent: ExchangeIntent
) -> (ExchangeState, [ExchangeEffect]) {
    var newState = state
    var effects: [ExchangeEffect] = []

    switch intent {
    case .appeared:
        break

    case .browsingStarted:
        newState.connectionState = .browsing
        effects.append(.startBrowsing)

    case let .peerDiscovered(id, name, paletteID):
        let peer = Peer(id: id, name: name, paletteID: paletteID)
        if !newState.nearbyPeers.contains(peer) {
            newState.nearbyPeers.append(peer)
        }

    case let .peerLost(id):
        newState.nearbyPeers.removeAll { $0.id == id }

    case let .inviteTapped(peerID):
        newState.connectionState = .inviting(peerID: peerID)
        newState.invitedPeerID = peerID
        effects.append(.sendInvitation(to: peerID))

    case let .invitationReceived(from, name, paletteID):
        let peer = Peer(id: from, name: name, paletteID: paletteID)
        newState.receivedInvitation = peer

    case .invitationAccepted:
        if let peer = newState.receivedInvitation {
            newState.connectionState = .connecting(peerID: peer.id)
            newState.receivedInvitation = nil
        }

    case .invitationDeclined:
        newState.receivedInvitation = nil

    case let .dataReceived(envelope):
        if case .exchanging = newState.connectionState {
            effects.append(.saveEncounter(envelope))
        }

    case .exchangeCompleted:
        newState.connectionState = .completed
        effects.append(.stopBrowsing)
        effects.append(.stopAdvertising)

    case let .exchangeFailed(message):
        newState.connectionState = .failed(message)
        newState.errorMessage = message
        effects.append(.stopBrowsing)
        effects.append(.stopAdvertising)

    case .dismissed:
        effects.append(.stopBrowsing)
        effects.append(.stopAdvertising)
    }

    return (newState, effects)
}
