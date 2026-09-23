import SwiftUI
import SwiftData
import MeilogCore

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var myCardStore = MyCardStore()
    @State private var encounterListStore: EncounterListStore?
    @State private var receivedEnvelope: CardEnvelope?
    @State private var showingReceive = false

    var body: some View {
        TabView {
            if let encounterListStore = encounterListStore {
                MyCardView(
                    store: myCardStore,
                    encounterListStore: encounterListStore
                )
                .tabItem {
                    Label("カード", systemImage: "person.crop.rectangle")
                }
            } else {
                ProgressView()
                    .tabItem {
                        Label("カード", systemImage: "person.crop.rectangle")
                    }
            }

            if let encounterListStore = encounterListStore {
                EncounterListView(store: encounterListStore)
                    .tabItem {
                        Label("受け取ったカード", systemImage: "person.2")
                    }
            } else {
                ProgressView()
                    .tabItem {
                        Label("受け取ったカード", systemImage: "person.2")
                    }
            }
        }
        .task {
            // MyCardStore のロード
            myCardStore.send(.appeared)

            // EncounterListStore の初期化
            if encounterListStore == nil {
                let repository = SwiftDataEncounterRepository(
                    modelContainer: modelContext.container
                )
                encounterListStore = EncounterListStore(
                    repository: repository,
                    myCardStore: myCardStore
                )
            }
        }
        .onOpenURL { url in
            handleReceivedFile(url)
        }
        .sheet(isPresented: $showingReceive) {
            if let envelope = receivedEnvelope,
               let store = encounterListStore {
                CardReceiveView(envelope: envelope, encounterListStore: store)
            }
        }
    }

    private func handleReceivedFile(_ url: URL) {
        // .meilog ファイルを読み込む
        guard url.pathExtension == "meilog" else { return }

        do {
            // ファイルを読み込む
            let data = try Data(contentsOf: url)

            // CardEnvelope にデコード
            let envelope = try CardPayload.decode(data)

            // 確認画面を表示
            receivedEnvelope = envelope
            showingReceive = true
        } catch {
            print("Failed to receive card: \(error)")
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: EncounterEntity.self)
}
