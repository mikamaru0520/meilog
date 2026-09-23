import SwiftUI
import OSLog
import MeilogCore

/// 自分のカード表示画面
struct MyCardView: View {
    @Bindable var store: MyCardStore
    @State private var showingEdit = false
    @State private var showingQR = false

    var body: some View {
        NavigationStack {
            if let card = store.myCard {
                VStack(spacing: 0) {
                    // スクロール可能なコンテンツ
                    ScrollView {
                        VStack(spacing: 32) {
                            // カードプレビュー（大きく表示）
                            LargeCardView(card: card)
                                .onTapGesture {
                                    showingQR = true
                                }
                                .padding(.top, 32)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 120) // ボタンエリア分の余白
                    }

                    // 固定フッターエリア
                    VStack(spacing: 12) {
                        // イベント表示
                        if let event = store.recentEvent {
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .font(.subheadline)
                                Text("今日のイベント: \(event.name)")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        }

                        // QRコード表示ボタン
                        Button {
                            showingQR = true
                        } label: {
                            Label("QRコードを表示", systemImage: "qrcode")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal)
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
                .fullScreenCover(isPresented: $showingQR) {
                    QRCodeModalView(store: store)
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

    // 配色の定義
    private let palettes: [[Color]] = [
        [.mint, .orange], // 朝霧
        [.pink, .orange], // 夕焼け
        [.blue, .indigo], // 深海
        [.green, .yellow], // 新緑
        [.purple, .pink], // 藤色
        [.black, .gray], // 墨
    ]

    private var selectedPalette: [Color] {
        guard card.style.paletteID >= 0 && card.style.paletteID < palettes.count else {
            return palettes[0]
        }
        return palettes[card.style.paletteID]
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(
                LinearGradient(
                    colors: [
                        selectedPalette[0].opacity(0.5),
                        selectedPalette[1].opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(1.586, contentMode: .fit) // クレジットカード比率
            .overlay {
                // 模様レイヤー
                if card.style.patternID > 0 {
                    CardPatternOverlay(patternID: card.style.patternID)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
            }
            .overlay {
                VStack(spacing: 16) {
                    Spacer()

                    // アバター
                    Circle()
                        .fill(Color.primary)
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
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            if let title = card.title {
                                Text(title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("|")
                                    .foregroundStyle(.tertiary)
                            }
                            Text(card.name)
                                .font(.title2.bold())
                        }

                        // リンク（最大3件）
                        if !card.links.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(card.links.prefix(3), id: \.value) { link in
                                    Text(link.value)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
                .padding()
            }
            .shadow(color: .black.opacity(0.1), radius: 16, y: 8)
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
                    let spacing: CGFloat = 16
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
                    let spacing: CGFloat = 16
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
    let store = MyCardStore()
    store.saveMyCard(Card(
        id: UUID(),
        name: "山田太郎",
        title: "iOS Developer",
        links: [],
        style: CardStyle(paletteID: 0, patternID: 0),
        avatar: nil
    ))
    return MyCardView(store: store)
}

#Preview("初回起動") {
    MyCardView(store: MyCardStore())
}
