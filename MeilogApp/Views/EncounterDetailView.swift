import SwiftUI
import struct MeilogCore.Link
import struct MeilogCore.Card
import struct MeilogCore.Encounter
import struct MeilogCore.Meeting
import struct MeilogCore.MeetupEvent
import struct MeilogCore.CardStyle
import enum MeilogCore.EventAssignment
import enum MeilogCore.Confidence
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
            // カードプレビュー
            Section {
                ReceivedCardPreview(card: encounter.card)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            // カード情報
            Section {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text(encounter.card.name)
                        .font(Typography.cardName)

                    if let title = encounter.card.title {
                        Text(title)
                            .font(Typography.cardTitle)
                            .foregroundStyle(Colors.textSecondary)
                    }

                    // リンク
                    if !encounter.card.links.isEmpty {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            ForEach(encounter.card.links, id: \.self) { link in
                                HStack {
                                    linkIcon(for: link.kind)
                                    Text(link.value)
                                        .font(Typography.caption)
                                        .foregroundStyle(Colors.textSecondary)
                                }
                            }
                        }
                        .padding(.top, Space.xxs)
                    }
                }
                .padding(.vertical, Space.xs)
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
        case .web: "globe"
        }
        return Image(systemName: iconName)
            .foregroundStyle(.secondary)
    }
}

/// 受け取ったカードのプレビュー
private struct ReceivedCardPreview: View {
    let card: Card

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.card)
            .fill(
                LinearGradient(
                    colors: Palette.colors(for: card.style.paletteID).map { $0.opacity(0.4) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(1.586, contentMode: .fit)
            .overlay {
                // 模様レイヤー
                if card.style.patternID > 0 {
                    CardPatternOverlay(patternID: card.style.patternID)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                }
            }
            .overlay {
                VStack(spacing: Space.xs) {
                    // アバター
                    Circle()
                        .fill(Colors.textPrimary)
                        .frame(width: 60, height: 60)
                        .overlay {
                            if let avatarData = card.avatar,
                               let uiImage = UIImage(data: avatarData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .clipShape(Circle())
                            } else {
                                Text(card.name.prefix(1))
                                    .font(Typography.cardName)
                                    .foregroundStyle(.white)
                            }
                        }

                    // 名前と肩書き
                    if !card.name.isEmpty {
                        Text(card.name)
                            .font(Typography.cardName)
                    }
                    if let title = card.title, !title.isEmpty {
                        Text(title)
                            .font(Typography.cardTitle)
                            .foregroundStyle(Colors.textSecondary)
                    }

                    // リンク表示
                    ForEach(card.links.prefix(3), id: \.value) { link in
                        Text(link.value)
                            .font(Typography.cardLink)
                            .foregroundStyle(Colors.textSecondary)
                    }
                }
                .padding(Space.md)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.lg)
    }
}

/// カード用模様オーバーレイ
private struct CardPatternOverlay: View {
    let patternID: Int

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                switch patternID {
                case 1: // ドット
                    let spacing: CGFloat = Space.md
                    for x in stride(from: 0, to: size.width, by: spacing) {
                        for y in stride(from: 0, to: size.height, by: spacing) {
                            let point = CGPoint(x: x, y: y)
                            context.fill(
                                Circle().path(in: CGRect(x: point.x - 1.5, y: point.y - 1.5, width: 3, height: 3)),
                                with: .color(.primary.opacity(0.15))
                            )
                        }
                    }
                case 2: // 方眼
                    let spacing: CGFloat = 20
                    for x in stride(from: 0, to: size.width, by: spacing) {
                        context.stroke(
                            Path { path in
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: size.height))
                            },
                            with: .color(.primary.opacity(0.1)),
                            lineWidth: 0.5
                        )
                    }
                    for y in stride(from: 0, to: size.height, by: spacing) {
                        context.stroke(
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: size.width, y: y))
                            },
                            with: .color(.primary.opacity(0.1)),
                            lineWidth: 0.5
                        )
                    }
                case 3: // 斜線
                    let spacing: CGFloat = Space.md
                    for offset in stride(from: -size.height, to: size.width + size.height, by: spacing) {
                        context.stroke(
                            Path { path in
                                path.move(to: CGPoint(x: offset, y: 0))
                                path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                            },
                            with: .color(.primary.opacity(0.1)),
                            lineWidth: 1
                        )
                    }
                case 4: // 波紋
                    let centerX = size.width / 2
                    let centerY = size.height / 2
                    for radius in stride(from: 20, to: max(size.width, size.height), by: 30) {
                        context.stroke(
                            Circle().path(in: CGRect(
                                x: centerX - radius,
                                y: centerY - radius,
                                width: radius * 2,
                                height: radius * 2
                            )),
                            with: .color(.primary.opacity(0.08)),
                            lineWidth: 1
                        )
                    }
                default:
                    break
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Meeting 1回分の表示
private struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(meeting.at, style: .date)
                .font(.subheadline.weight(.medium))

            HStack {
                eventLabel
                Spacer()
            }
        }
        .padding(.vertical, Space.xxs)
    }

    @ViewBuilder
    private var eventLabel: some View {
        switch meeting.event {
        case .unassigned:
            Label("未割り当て", systemImage: "questionmark.circle")
                .font(Typography.caption)
                .foregroundStyle(Colors.warning)

        case .assigned(let event, let confidence):
            HStack(spacing: Space.xxs) {
                if confidence == .inferred {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(Colors.warning)
                }
                Text(event.name)
                    .font(Typography.caption)
                    .foregroundStyle(Colors.textSecondary)
            }

        case .none:
            Label("イベント外", systemImage: "minus.circle")
                .font(Typography.caption)
                .foregroundStyle(Colors.textSecondary)
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
        note: "とても良い人でした"
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
