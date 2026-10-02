import SwiftUI
import SwiftData
import MeilogCore

/// 受け取ったカード一覧画面
struct EncounterListView: View {
    @Bindable var store: EncounterListStore
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
                            Text("AirDropでカードを受け取りましょう")
                        }
                    } else {
                        // 検索結果なし
                        ContentUnavailableView.search
                    }
                } else {
                    List {
                        // 未割り当て・推測の件数バッジ
                        if store.state.unassignedCount > 0 || store.state.inferredCount > 0 {
                            Section {
                                if store.state.unassignedCount > 0 {
                                    HStack {
                                        Label("未割り当て", systemImage: "questionmark.circle")
                                        Spacer()
                                        Text("\(store.state.unassignedCount)")
                                            .foregroundStyle(.secondary)
                                            .badge(store.state.unassignedCount)
                                    }
                                }
                                if store.state.inferredCount > 0 {
                                    HStack {
                                        Label("推測", systemImage: "sparkles")
                                        Spacer()
                                        Text("\(store.state.inferredCount)")
                                            .foregroundStyle(.secondary)
                                            .badge(store.state.inferredCount)
                                    }
                                }
                            } header: {
                                Text("整理が必要")
                            }
                        }

                        Section {
                            ForEach(store.state.filteredEncounters) { encounter in
                                NavigationLink(value: encounter) {
                                    EncounterRow(encounter: encounter)
                                }
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    let encounter = store.state.filteredEncounters[index]
                                    store.send(.deleteRequested(encounterID: encounter.id))
                                }
                            }
                        } header: {
                            Text("カード一覧")
                        }
                    }
                }
            }
            .navigationTitle("受け取ったカード")
            .navigationDestination(for: Encounter.self) { encounter in
                EncounterDetailView(store: store, encounterID: encounter.id)
            }
            .searchable(text: $searchText, prompt: "名前、肩書き、イベントで検索")
            .onChange(of: searchText) { _, newValue in
                store.send(.queryChanged(newValue))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !store.state.allEvents.isEmpty {
                        Menu {
                            Button {
                                store.send(.eventFilterChanged(nil))
                            } label: {
                                Label("すべて", systemImage: "list.bullet")
                            }

                            Divider()

                            ForEach(store.state.allEvents) { event in
                                Button {
                                    store.send(.eventFilterChanged(event.id))
                                } label: {
                                    Label(event.name, systemImage: "calendar")
                                }
                            }
                        } label: {
                            Label(
                                store.state.eventFilter == nil ? "すべて" : (store.state.allEvents.first(where: { $0.id == store.state.eventFilter })?.name ?? "フィルタ"),
                                systemImage: "line.3.horizontal.decrease.circle"
                            )
                        }
                    }
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
        VStack(alignment: .leading, spacing: Space.xs) {
            // 名前
            Text(encounter.card.name)
                .font(Typography.sectionHeader)

            // 肩書き
            if let title = encounter.card.title {
                Text(title)
                    .font(Typography.cardTitle)
                    .foregroundStyle(Colors.textSecondary)
            }

            // 最後に会った日時とイベント
            HStack {
                if let lastMet = encounter.lastMetAt {
                    Text(lastMet, style: .date)
                        .font(Typography.caption)
                        .foregroundStyle(Colors.textTertiary)
                }

                if let firstMeeting = encounter.meetings.first {
                    switch firstMeeting.event {
                    case .assigned(let event, let confidence):
                        HStack(spacing: Space.xxs) {
                            Image(systemName: confidence == .confirmed ? "checkmark.circle.fill" : "sparkles")
                                .font(Typography.caption)
                            Text(event.name)
                                .font(Typography.caption)
                        }
                        .foregroundStyle(confidence == .confirmed ? Colors.success : Colors.warning)
                    case .unassigned:
                        Text("未割り当て")
                            .font(Typography.caption)
                            .foregroundStyle(Colors.destructive)
                    case .none:
                        Text("イベント外")
                            .font(Typography.caption)
                            .foregroundStyle(Colors.textSecondary)
                    }
                }
            }

            // 会った回数
            if encounter.meetings.count > 1 {
                Text("\(encounter.meetings.count)回会いました")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.accent)
            }
        }
        .padding(.vertical, Space.xxs)
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
            note: ""
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
