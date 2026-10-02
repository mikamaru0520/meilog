import SwiftUI
import SwiftData
import MeilogCore

/// Network.framework based card exchange view
struct ExchangeView: View {
    @Bindable var store: ExchangeStore
    let myCard: Card
    let recentEvent: MeetupEvent?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Space.lg) {
                Text("Debug Info:")
                    .font(.headline)
                Text("State: \(String(describing: store.state.connectionState))")
                    .font(.caption)
                Text("Peers: \(store.state.nearbyPeers.count)")
                    .font(.caption)

                Divider()

                switch store.state.connectionState {
                case .idle, .browsing:
                    browsingView
                case .inviting:
                    Text("Inviting...")
                case .connecting, .exchanging:
                    Text("Exchanging...")
                case .completed:
                    Text("Completed!")
                case .failed(let message):
                    Text("Failed: \(message)")
                case .waitingForApproval:
                    Text("Waiting for approval...")
                }
            }
            .navigationTitle("カードを交換")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        store.send(.dismissed)
                        dismiss()
                    }
                }
            }
            .task {
                store.send(.appeared)
                store.send(.browsingStarted)
            }
        }
    }
    
    // MARK: - Browsing View
    
    private var browsingView: some View {
        VStack {
            Text("Browsing View")
                .font(.title)

            if store.state.nearbyPeers.isEmpty {
                Text("No peers found")
                    .font(.body)
                    .padding()
            } else {
                Text("Found \(store.state.nearbyPeers.count) peers")
                    .font(.body)
            }

            ProgressView("探索中...")
                .padding()
        }
    }
    
    // MARK: - Inviting View
    
    private var invitingView: some View {
        VStack(spacing: Space.xl) {
            Spacer()
            
            ProgressView()
                .controlSize(.large)
            
            Text("招待を送信中...")
                .font(Typography.sectionHeader)
            
            if let peerID = store.state.invitedPeerID,
               let peer = store.state.nearbyPeers.first(where: { $0.id == peerID }) {
                Text("\(peer.name)さんの承認を待っています")
                    .font(Typography.body)
                    .foregroundStyle(Colors.textSecondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Exchanging View
    
    private var exchangingView: some View {
        VStack(spacing: Space.xl) {
            Spacer()
            
            ProgressView()
                .controlSize(.large)
            
            Text("カードを交換中...")
                .font(Typography.sectionHeader)
            
            Text("しばらくお待ちください")
                .font(Typography.body)
                .foregroundStyle(Colors.textSecondary)
            
            Spacer()
        }
    }
    
    // MARK: - Completed View
    
    private var completedView: some View {
        VStack(spacing: Space.xl) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Colors.success)
            
            Text("交換完了")
                .font(.title2.bold())
            
            Text("カードを受け取りました")
                .font(Typography.body)
                .foregroundStyle(Colors.textSecondary)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("閉じる")
                    .font(Typography.button)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, Space.md)
            .padding(.bottom, Space.lg)
        }
    }
    
    // MARK: - Failed View
    
    private func failedView(message: String) -> some View {
        VStack(spacing: Space.xl) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Colors.destructive)
            
            Text("交換に失敗しました")
                .font(.title2.bold())
            
            Text(message)
                .font(Typography.body)
                .foregroundStyle(Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xl)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("閉じる")
                    .font(Typography.button)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, Space.md)
            .padding(.bottom, Space.lg)
        }
    }
}

#Preview("探索中 - 近くに人がいない") {
    @Previewable @State var store = ExchangeStore(
        repository: SwiftDataEncounterRepository(
            modelContainer: try! ModelContainer(for: EncounterEntity.self)
        ),
        myCardStore: MyCardStore()
    )
    
    let card = Card(
        id: UUID(),
        name: "山田太郎",
        title: "iOS Developer",
        links: [],
        style: CardStyle(paletteID: 0, patternID: 0),
        avatar: nil
    )
    
    ExchangeView(store: store, myCard: card, recentEvent: nil)
}

#Preview("探索中 - 近くに人がいる") {
    @Previewable @State var store: ExchangeStore = {
        let s = ExchangeStore(
            repository: SwiftDataEncounterRepository(
                modelContainer: try! ModelContainer(for: EncounterEntity.self)
            ),
            myCardStore: MyCardStore()
        )
        s.send(.browsingStarted)
        s.send(.peerDiscovered(id: "peer1", name: "佐藤花子", paletteID: 2))
        s.send(.peerDiscovered(id: "peer2", name: "田中一郎", paletteID: 5))
        return s
    }()
    
    let card = Card(
        id: UUID(),
        name: "山田太郎",
        title: "iOS Developer",
        links: [],
        style: CardStyle(paletteID: 0, patternID: 0),
        avatar: nil
    )
    
    ExchangeView(store: store, myCard: card, recentEvent: nil)
}

#Preview("交換完了") {
    @Previewable @State var store: ExchangeStore = {
        let s = ExchangeStore(
            repository: SwiftDataEncounterRepository(
                modelContainer: try! ModelContainer(for: EncounterEntity.self)
            ),
            myCardStore: MyCardStore()
        )
        s.send(.exchangeCompleted)
        return s
    }()
    
    let card = Card(
        id: UUID(),
        name: "山田太郎",
        title: "iOS Developer",
        links: [],
        style: CardStyle(paletteID: 0, patternID: 0),
        avatar: nil
    )
    
    ExchangeView(store: store, myCard: card, recentEvent: nil)
}
