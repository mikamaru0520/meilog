import SwiftUI
import MeilogCore

/// カード受信確認画面（AirDrop 後）
struct CardReceiveView: View {
    @Environment(\.dismiss) private var dismiss
    let envelope: CardEnvelope
    @Bindable var encounterListStore: EncounterListStore

    @State private var selectedEvent: MeetupEvent?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.lg) {
                    // カードプレビュー
                    ReceivedCardPreview(card: envelope.card)
                        .padding(.top, Space.lg)

                    // イベント選択
                    VStack(alignment: .leading, spacing: Space.md) {
                        Text("どこで会いましたか？")
                            .font(Typography.sectionHeader)
                            .padding(.horizontal, Space.md)

                        // 受信時のイベント（あれば）
                        if let receivedEvent = envelope.event {
                            Button {
                                selectedEvent = receivedEvent
                            } label: {
                                HStack {
                                    Image(systemName: selectedEvent?.id == receivedEvent.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedEvent?.id == receivedEvent.id ? Colors.success : Colors.textSecondary)
                                    Text(receivedEvent.name)
                                        .font(Typography.body)
                                        .foregroundStyle(Colors.textPrimary)
                                    Spacer()
                                }
                                .padding(Space.md)
                                .background(selectedEvent?.id == receivedEvent.id ? Colors.success.opacity(0.1) : Color.clear)
                                .cornerRadius(Radius.control)
                            }
                            .padding(.horizontal, Space.md)
                        }

                        // 別のイベント
                        Button {
                            // TODO: イベント選択
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                Text("別のイベント")
                                    .font(Typography.body)
                                Spacer()
                            }
                            .padding(Space.md)
                            .background(.regularMaterial)
                            .cornerRadius(Radius.control)
                        }
                        .padding(.horizontal, Space.md)

                        // あとで決める
                        Button {
                            selectedEvent = nil
                        } label: {
                            HStack {
                                Image(systemName: selectedEvent == nil ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedEvent == nil ? Colors.success : Colors.textSecondary)
                                Text("あとで")
                                    .font(Typography.body)
                                    .foregroundStyle(Colors.textPrimary)
                                Spacer()
                            }
                            .padding(Space.md)
                            .background(selectedEvent == nil ? Colors.success.opacity(0.1) : Color.clear)
                            .cornerRadius(Radius.control)
                        }
                        .padding(.horizontal, Space.md)
                    }

                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("カードを受け取りました")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        saveCard()
                    } label: {
                        Text("保存する")
                            .font(Typography.button)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(Space.md)
                    .background(.regularMaterial)

                    if selectedEvent == nil {
                        Text("自分のカードも送り返す")
                            .font(Typography.caption)
                            .foregroundStyle(Colors.textSecondary)
                            .padding(.bottom)
                    }
                }
            }
        }
        .onAppear {
            // 受信時のイベントを初期選択
            selectedEvent = envelope.event
        }
    }

    private func saveCard() {
        // IntentにeventをセットしたCardEnvelopeを渡す
        var envelopeToSave = envelope
        envelopeToSave.event = selectedEvent

        encounterListStore.send(.cardReceived(
            envelopeToSave,
            now: Date(),
            newID: UUID(),
            calendar: Calendar.current
        ))

        dismiss()
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
