import SwiftUI
import SwiftData
import OSLog
import MeilogCore

/// 自分のカード表示画面
struct MyCardView: View {
    @Bindable var store: MyCardStore
    @Bindable var encounterListStore: EncounterListStore
    @State private var showingEdit = false
    @State private var showingExchange = false
    @State private var exchangeStore: ExchangeStore?

    var body: some View {
        NavigationStack {
            if let card = store.myCard {
                VStack(spacing: 0) {
                    // スクロール可能なコンテンツ
                    ScrollView {
                        VStack(spacing: Space.xl) {
                            // カードプレビュー（大きく表示）
                            LargeCardView(card: card)
                                .padding(.top, Space.xl)
                        }
                        .padding(.horizontal, Space.md)
                        .padding(.bottom, 120) // ボタンエリア分の余白
                    }

                    // 固定フッターエリア
                    VStack(spacing: Space.sm) {
                        // イベント表示
                        if let event = store.recentEvent {
                            HStack(spacing: Space.xs) {
                                Image(systemName: "clock")
                                    .font(Typography.body)
                                Text("今日のイベント: \(event.name)")
                                    .font(Typography.body)
                            }
                            .foregroundStyle(Colors.textSecondary)
                            .padding(.horizontal, Space.md)
                        }

                        // カード交換ボタン
                        Button {
                            showingExchange = true
                        } label: {
                            Label("カードを送る", systemImage: "square.and.arrow.up")
                                .font(Typography.button)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal, Space.md)
                        .padding(.bottom)
                    }
                    .background(.regularMaterial)
                }
                .navigationTitle("自分のカード")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("編集") {
                            showingEdit = true
                        }
                    }
                }
                .sheet(isPresented: $showingEdit) {
                    CardEditView(store: store)
                }
                .task {
                    if exchangeStore == nil {
                        exchangeStore = ExchangeStore(
                            repository: encounterListStore.repository,
                            myCardStore: store
                        )
                    }
                }
                .sheet(isPresented: $showingExchange) {
                    if let card = store.myCard,
                       let exchangeStore = exchangeStore {
                        ExchangeView(
                            store: exchangeStore,
                            myCard: card,
                            recentEvent: store.recentEvent
                        )
                    }
                }
            } else {
                // 初回起動時
                ContentUnavailableView {
                    Label("カードを作成", systemImage: "person.crop.rectangle")
                } description: {
                    Text("まず自分のカードを作成してください")
                } actions: {
                    Button("カードを作成") {
                        showingEdit = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .sheet(isPresented: $showingEdit) {
                    CardEditView(store: store)
                }
            }
        }
    }
}

/// 大きなカード表示
private struct LargeCardView: View {
    let card: Card

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.sheet)
            .fill(
                LinearGradient(
                    colors: Palette.colors(for: card.style.paletteID).map { $0.opacity(0.4) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(1.586, contentMode: .fit) // クレジットカード比率
            .overlay {
                // 模様レイヤー
                if card.style.patternID > 0 {
                    CardPatternOverlay(patternID: card.style.patternID)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sheet))
                }
            }
            .overlay {
                VStack(spacing: Space.md) {
                    Spacer()

                    // アバター
                    Circle()
                        .fill(Colors.textPrimary)
                        .frame(width: 80, height: 80)
                        .overlay {
                            if let avatarData = card.avatar,
                               let uiImage = UIImage(data: avatarData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .clipShape(Circle())
                            } else {
                                Text(card.name.prefix(1))
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(.white)
                            }
                        }

                    Spacer()

                    // テキスト情報
                    VStack(spacing: Space.xs) {
                        HStack(spacing: Space.sm) {
                            if let title = card.title {
                                Text(title)
                                    .font(Typography.cardTitle)
                                    .foregroundStyle(Colors.textSecondary)
                                Text("|")
                                    .foregroundStyle(Colors.textTertiary)
                            }
                            Text(card.name)
                                .font(Typography.cardName)
                        }

                        // リンク（最大3件）
                        if !card.links.isEmpty {
                            VStack(alignment: .leading, spacing: Space.xxs) {
                                ForEach(card.links.prefix(3), id: \.value) { link in
                                    Text(link.value)
                                        .font(Typography.cardLink)
                                        .foregroundStyle(Colors.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(.bottom, Space.lg)
                }
                .padding(Space.md)
            }
            .cardShadow()
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

#Preview("カードあり") {
    @Previewable @State var myCardStore = MyCardStore()
    @Previewable @State var encounterListStore = EncounterListStore(
        repository: SwiftDataEncounterRepository(
            modelContainer: try! ModelContainer(for: EncounterEntity.self)
        ),
        myCardStore: MyCardStore()
    )

    let _ = myCardStore.saveMyCard(Card(
        id: UUID(),
        name: "山田太郎",
        title: "iOS Developer",
        links: [],
        style: CardStyle(paletteID: 0, patternID: 0),
        avatar: nil
    ))

    MyCardView(
        store: myCardStore,
        encounterListStore: encounterListStore
    )
}

#Preview("初回起動") {
    @Previewable @State var myCardStore = MyCardStore()
    @Previewable @State var encounterListStore = EncounterListStore(
        repository: SwiftDataEncounterRepository(
            modelContainer: try! ModelContainer(for: EncounterEntity.self)
        ),
        myCardStore: MyCardStore()
    )

    MyCardView(
        store: myCardStore,
        encounterListStore: encounterListStore
    )
}
