import SwiftUI
import struct MeilogCore.Link
import struct MeilogCore.Card
import struct MeilogCore.Encounter
import struct MeilogCore.Meeting
import struct MeilogCore.MeetupEvent
import struct MeilogCore.CardStyle
import enum MeilogCore.EventAssignment
import enum MeilogCore.Confidence
import enum MeilogCore.AvatarState
import protocol MeilogCore.EncounterRepository

// SwiftUI.Link との衝突を避ける
typealias CardLink = Link

/// Encounter の詳細画面
struct EncounterDetailView: View {
    @Bindable var store: EncounterListStore
    let encounterID: UUID
    @State private var editingNote = false
    @State private var noteText = ""

    // Store の状態から最新の Encounter を取得
    private var encounter: Encounter? {
        store.state.encounters.first(where: { $0.id == encounterID })
    }

    var body: some View {
        if let encounter = encounter {
            List {
            // カード情報
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(encounter.card.name)
                        .font(.title2.bold())

                    if let title = encounter.card.title {
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // リンク
                    if !encounter.card.links.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(encounter.card.links, id: \.self) { link in
                                HStack {
                                    linkIcon(for: link.kind)
                                    Text(link.value)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }

                    #if DEBUG
                    // スタイル（デバッグ用）
                    HStack {
                        Label("パレット: \(encounter.card.style.paletteID)", systemImage: "paintpalette")
                        Label("パターン: \(encounter.card.style.patternID)", systemImage: "square.grid.2x2")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    #endif
                }
                .padding(.vertical, 8)
            } header: {
                Text("カード情報")
            }

            // Meeting 履歴
            Section {
                ForEach(encounter.meetings) { meeting in
                    MeetingRow(meeting: meeting)
                }
            } header: {
                Text("会った履歴 (\(encounter.meetings.count)回)")
            }

            // メモ
            Section {
                Group {
                    if editingNote {
                        TextEditor(text: $noteText)
                            .frame(minHeight: 100)
                    } else {
                        if encounter.note.isEmpty {
                            Text("メモを追加")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(encounter.note)
                        }
                    }
                }
                .onTapGesture {
                    if !editingNote {
                        noteText = encounter.note
                        editingNote = true
                    }
                }
            } header: {
                Text("メモ")
            } footer: {
                if editingNote {
                    HStack {
                        Button("キャンセル") {
                            noteText = encounter.note
                            editingNote = false
                        }
                        Spacer()
                        Button("保存") {
                            store.send(.noteUpdated(encounterID: encounter.id, note: noteText))
                            editingNote = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            }
            .navigationTitle(encounter.card.name)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView {
                Label("カードが見つかりません", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private func linkIcon(for kind: CardLink.Kind) -> some View {
        let iconName: String = switch kind {
        case .github: "github"
        case .x: "xmark.app"
        case .bluesky: "cloud"
        case .mastodon: "mastodon"
        case .web: "globe"
        }
        return Image(systemName: iconName)
            .foregroundStyle(.secondary)
    }
}

/// Meeting 1回分の表示
private struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(meeting.at, style: .date)
                .font(.subheadline.weight(.medium))

            HStack {
                eventLabel
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var eventLabel: some View {
        switch meeting.event {
        case .unassigned:
            Label("未割り当て", systemImage: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.orange)

        case .assigned(let event, let confidence):
            HStack(spacing: 4) {
                if confidence == .inferred {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
                Text(event.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .none:
            Label("イベント外", systemImage: "minus.circle")
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }
}

#Preview {
    let encounterID = UUID()
    let encounter = Encounter(
        id: encounterID,
        card: Card(
            id: UUID(),
            name: "山田太郎",
            title: "iOS Developer",
            links: [
                CardLink(kind: .github, value: "yamada"),
                CardLink(kind: .x, value: "@yamada")
            ],
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
                        name: "iOSDC 2024",
                        date: Date(),
                        venue: "東京"
                    ),
                    confidence: .confirmed
                )
            ),
            Meeting(
                id: UUID(),
                at: Date().addingTimeInterval(-86400 * 30),
                event: .unassigned
            )
        ],
        note: "とても良い人でした",
        avatarState: .notReceived
    )

    let store = EncounterListStore(
        repository: PreviewEncounterRepository(),
        myCardStore: MyCardStore()
    )
    // Preview 用に state を設定
    store.send(.loaded([encounter], recentEvent: nil))

    return NavigationStack {
        EncounterDetailView(store: store, encounterID: encounterID)
    }
}

/// Preview 用の Repository
private actor PreviewEncounterRepository: EncounterRepository {
    func load() async throws -> [Encounter] { [] }
    func save(_ encounter: Encounter) async throws {}
    func delete(id: UUID) async throws {}
}
