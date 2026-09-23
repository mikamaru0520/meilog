import SwiftUI
import SwiftData
import MeilogCore

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var myCardStore = MyCardStore()
    @State private var encounterListStore: EncounterListStore?

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
    }
}

#Preview {
    RootView()
        .modelContainer(for: EncounterEntity.self)
}
