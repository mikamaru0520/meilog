import SwiftUI
import OSLog
import MeilogCore

/// 自分のカード表示画面（QR コード付き）
struct MyCardView: View {
    @Bindable var store: MyCardStore
    @State private var qrImage: UIImage?
    @State private var rendezvous: String = Rendezvous.generate()
    @State private var showingEdit = false
    private let logger = Logger(subsystem: "com.example.meilog", category: "MyCardView")

    var body: some View {
        NavigationStack {
            if let card = store.myCard {
                ScrollView {
                    VStack(spacing: 32) {
                        // カード情報
                        CardInfoView(card: card)
                            .padding()

                        // QR コード
                        if let qrImage = qrImage {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 300, maxHeight: 300)
                                .padding()
                                .background(.white)
                                .cornerRadius(16)
                                .shadow(radius: 4)
                        } else {
                            ProgressView("QR コード生成中...")
                        }

                        Text("このQRコードを読み取ってもらってください")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
                .navigationTitle("自分のカード")
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
                .task(id: "\(card.id.uuidString)-\(rendezvous)") {
                    await generateQRCode(for: card)
                }
                .onAppear {
                    // 表示のたびに rendezvous を再生成
                    rendezvous = Rendezvous.generate()
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

    private func generateQRCode(for card: Card) async {
        let envelope = CardEnvelope(
            card: card,
            event: store.recentEvent,
            rendezvous: rendezvous
        )

        do {
            let image = try QRCodeGenerator.generateQRCode(from: envelope)
            await MainActor.run {
                qrImage = image
            }
        } catch {
            logger.error("Failed to generate QR code: \(error.localizedDescription)")
        }
    }
}

/// カード情報表示
private struct CardInfoView: View {
    let card: Card

    var body: some View {
        VStack(spacing: 16) {
            // 名前
            Text(card.name)
                .font(.title.bold())

            // 肩書き
            if let title = card.title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            // スタイル情報（デバッグ用）
            HStack {
                Label("パレット: \(card.style.paletteID)", systemImage: "paintpalette")
                Label("パターン: \(card.style.patternID)", systemImage: "square.grid.2x2")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
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
