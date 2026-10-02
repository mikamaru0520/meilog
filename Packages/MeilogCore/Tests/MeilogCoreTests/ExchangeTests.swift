import Testing
import Foundation
@testable import MeilogCore

@Suite("Exchange reduce tests")
struct ExchangeTests {
    private func makeCard(name: String = "Alice") -> Card {
        Card(
            id: UUID(),
            name: name,
            links: [],
            style: CardStyle(paletteID: 0, patternID: 0)
        )
    }

    @Test("browsingStarted starts discovery")
    func browsingStarted_startsDiscovery() {
        let state = ExchangeState()

        let (newState, effects) = reduce(state, .browsingStarted)

        #expect(newState.connectionState == .browsing)
        #expect(effects.contains(.startBrowsing))
    }

    @Test("peerDiscovered adds peer to list")
    func peerDiscovered_addsPeerToList() {
        var state = ExchangeState()
        state.connectionState = .browsing

        let (newState, _) = reduce(state, .peerDiscovered(id: "peer1", name: "Bob", paletteID: 1))

        #expect(newState.nearbyPeers.count == 1)
        #expect(newState.nearbyPeers[0].id == "peer1")
        #expect(newState.nearbyPeers[0].name == "Bob")
        #expect(newState.nearbyPeers[0].paletteID == 1)
    }

    @Test("peerLost removes peer from list")
    func peerLost_removesPeerFromList() {
        var state = ExchangeState()
        state.nearbyPeers = [
            Peer(id: "peer1", name: "Bob", paletteID: 1),
            Peer(id: "peer2", name: "Carol", paletteID: 2)
        ]

        let (newState, _) = reduce(state, .peerLost(id: "peer1"))

        #expect(newState.nearbyPeers.count == 1)
        #expect(newState.nearbyPeers[0].id == "peer2")
    }

    @Test("inviteTapped sends invitation")
    func inviteTapped_sendsInvitation() {
        var state = ExchangeState()
        state.connectionState = .browsing

        let (newState, effects) = reduce(state, .inviteTapped(peerID: "peer1"))

        #expect(newState.connectionState == .inviting(peerID: "peer1"))
        #expect(newState.invitedPeerID == "peer1")
        #expect(effects.contains(.sendInvitation(to: "peer1")))
    }

    @Test("invitationReceived stores invitation")
    func invitationReceived_storesInvitation() {
        let state = ExchangeState()

        let (newState, _) = reduce(state, .invitationReceived(from: "peer1", name: "Bob", paletteID: 1))

        #expect(newState.receivedInvitation?.id == "peer1")
        #expect(newState.receivedInvitation?.name == "Bob")
        #expect(newState.receivedInvitation?.paletteID == 1)
    }

    @Test("invitationAccepted starts connecting")
    func invitationAccepted_startsConnecting() {
        var state = ExchangeState()
        state.receivedInvitation = Peer(id: "peer1", name: "Bob", paletteID: 1)

        let (newState, _) = reduce(state, .invitationAccepted)

        #expect(newState.connectionState == .connecting(peerID: "peer1"))
        #expect(newState.receivedInvitation == nil)
    }

    @Test("invitationDeclined clears invitation")
    func invitationDeclined_clearsInvitation() {
        var state = ExchangeState()
        state.receivedInvitation = Peer(id: "peer1", name: "Bob", paletteID: 1)

        let (newState, _) = reduce(state, .invitationDeclined)

        #expect(newState.receivedInvitation == nil)
    }

    @Test("dataReceived saves encounter")
    func dataReceived_savesEncounter() {
        var state = ExchangeState()
        state.connectionState = .exchanging(peerID: "peer1")

        let card = makeCard()
        let envelope = CardEnvelope(card: card, event: nil)

        let (_, effects) = reduce(state, .dataReceived(envelope))

        #expect(effects.contains(.saveEncounter(envelope)))
    }

    @Test("exchangeCompleted stops discovery")
    func exchangeCompleted_stopsDiscovery() {
        var state = ExchangeState()
        state.connectionState = .exchanging(peerID: "peer1")

        let (newState, effects) = reduce(state, .exchangeCompleted)

        #expect(newState.connectionState == .completed)
        #expect(effects.contains(.stopBrowsing))
        #expect(effects.contains(.stopAdvertising))
    }

    @Test("exchangeFailed sets failed state")
    func exchangeFailed_setsFailedState() {
        var state = ExchangeState()
        state.connectionState = .exchanging(peerID: "peer1")

        let (newState, effects) = reduce(state, .exchangeFailed("Connection lost"))

        #expect(newState.connectionState == .failed("Connection lost"))
        #expect(newState.errorMessage == "Connection lost")
        #expect(effects.contains(.stopBrowsing))
        #expect(effects.contains(.stopAdvertising))
    }

    @Test("dismissed stops discovery")
    func dismissed_stopsDiscovery() {
        var state = ExchangeState()
        state.connectionState = .browsing

        let (_, effects) = reduce(state, .dismissed)

        #expect(effects.contains(.stopBrowsing))
        #expect(effects.contains(.stopAdvertising))
    }
}
