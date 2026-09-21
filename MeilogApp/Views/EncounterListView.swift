import SwiftUI
import SwiftData
import MeilogCore

/// 受け取ったカード一覧画面
struct EncounterListView: View {
    @Bindable var store: EncounterListStore
    @State private var scanner = QRScanner()
    @State private var showingScanner = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if store.state.filteredEncounters.isEmpty {
                    if searchText.isEmpty {
                        // まだカードを受け取っていない
                        ContentUnavailableView {
                            Label("受け取ったカードはありません", systemImage: "person.2")
                        } description: {
                            Text("QRコードを読み取ってカードを受け取りましょう")
                        } actions: {
                            Button("QRコードを読み取る") {
                                showingScanner = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        // 検索結果なし
                        ContentUnavailableView.search
                    }
                } else {
                    List {
                        ForEach(store.state.filteredEncounters) { encounter in
                            EncounterRow(encounter: encounter)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let encounter = store.state.filteredEncounters[index]
                                store.send(.deleteRequested(encounterID: encounter.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("受け取ったカード")
            .searchable(text: $searchText, prompt: "名前、肩書き、イベントで検索")
            .onChange(of: searchText) { _, newValue in
                store.send(.queryChanged(newValue))
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("QRコードを読み取る", systemImage: "qrcode.viewfinder")
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                NavigationStack {
                    QRScannerView(scanner: scanner, store: store)
                }
            }
            .task {
                store.send(.appeared)
            }
        }
    }
}

/// Encounter の行表示
private struct EncounterRow: View {
    let encounter: Encounter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 名前
            Text(encounter.card.name)
                .font(.headline)

            // 肩書き
            if let title = encounter.card.title {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // 最後に会った日時とイベント
            HStack {
                if let lastMet = encounter.lastMetAt {
                    Text(lastMet, style: .date)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let firstMeeting = encounter.meetings.first {
                    switch firstMeeting.event {
                    case .assigned(let event, let confidence):
                        HStack(spacing: 4) {
                            Image(systemName: confidence == .confirmed ? "checkmark.circle.fill" : "sparkles")
                                .font(.caption)
                            Text(event.name)
                                .font(.caption)
                        }
                        .foregroundStyle(confidence == .confirmed ? .green : .orange)
                    case .unassigned:
                        Text("未割り当て")
                            .font(.caption)
                            .foregroundStyle(.red)
                    case .none:
                        Text("イベント外")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 会った回数
            if encounter.meetings.count > 1 {
                Text("\(encounter.meetings.count)回会いました")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("カードあり") {
    @Previewable @State var store: EncounterListStore = {
        let s = EncounterListStore(
            repository: SwiftDataEncounterRepository(
                modelContainer: try! ModelContainer(for: EncounterEntity.self)
            ),
            myCardStore: MyCardStore()
        )

        let encounter = Encounter(
            id: UUID(),
            card: Card(
                id: UUID(),
                name: "山田太郎",
                title: "iOS Developer",
                links: [],
                style: CardStyle(paletteID: 0, patternID: 0),
                avatar: nil
            ),
            meetings: [
                Meeting(
                    id: UUID(),
                    at: Date(),
                    event: .assigned(
                        MeetupEvent(
                            id: UUID(),
                            name: "Swift勉強会",
                            date: Date(),
                            venue: nil
                        ),
                        confidence: .confirmed
                    )
                )
            ],
            note: "",
            avatarState: .notReceived
        )

        s.send(.loaded([encounter], recentEvent: nil))
        return s
    }()

    EncounterListView(store: store)
}

#Preview("カードなし") {
    @Previewable @State var store = EncounterListStore(
        repository: SwiftDataEncounterRepository(
            modelContainer: try! ModelContainer(for: EncounterEntity.self)
        ),
        myCardStore: MyCardStore()
    )

    EncounterListView(store: store)
}
