import SwiftUI
import MeilogCore

/// カード送信確認画面（AirDrop 前）
struct CardSendView: View {
    @Environment(\.dismiss) private var dismiss
    let store: MyCardStore

    @State private var showingAirDrop = false
    @State private var shareURL: URL?
    @State private var error: Error?
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.lg) {
                    if let card = store.myCard {
                        // カードプレビュー
                        CardSendPreview(card: card)
                            .padding(.top, Space.lg)

                        // イベント情報セクション
                        if let event = store.recentEvent {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                HStack {
                                    VStack(alignment: .leading, spacing: Space.xxs) {
                                        Text("一緒に送るイベント")
                                            .font(Typography.caption)
                                            .foregroundStyle(Colors.textSecondary)
                                        Text(event.name)
                                            .font(Typography.sectionHeader)
                                    }
                                    Spacer()
                                    Button("変更") {
                                        // TODO: イベント選択
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(Space.md)
                            .background(.regularMaterial)
                            .cornerRadius(Radius.control)
                            .padding(.horizontal, Space.md)
                        }

                        // 説明文
                        VStack(alignment: .leading, spacing: Space.xs) {
                            HStack(alignment: .top, spacing: Space.xs) {
                                Image(systemName: "info.circle")
                                    .font(Typography.body)
                                Text("相手のAirDrop受信を「すべての人」（10分間）にしてもらってください。")
                                    .font(Typography.body)
                            }
                            .foregroundStyle(Colors.textSecondary)

                            HStack(alignment: .top, spacing: Space.xs) {
                                Image(systemName: "lock.fill")
                                    .font(Typography.body)
                                Text("連絡先に登録されていない相手とは、初回は対面でコードを確認します。")
                                    .font(Typography.body)
                            }
                            .foregroundStyle(Colors.textSecondary)
                        }
                        .padding(.horizontal, Space.md)
                        .padding(.bottom, Space.xxl)
                    }
                }
            }
            .navigationTitle("カードを送る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        prepareAndShare()
                    } label: {
                        Label("AirDropを開く", systemImage: "square.and.arrow.up")
                            .font(Typography.button)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(Space.md)
                    .background(.regularMaterial)

                    Text("相手と近い場所でボタンを押してください")
                        .font(Typography.caption)
                        .foregroundStyle(Colors.textSecondary)
                        .padding(.bottom)
                }
            }
            .sheet(isPresented: $showingAirDrop) {
                if let url = shareURL {
                    AirDropSheet(url: url)
                }
            }
            .alert("エラー", isPresented: $showingError, presenting: error) { _ in
                Button("OK") {}
            } message: { error in
                Text(error.localizedDescription)
            }
        }
    }

    private func prepareAndShare() {
        guard let card = store.myCard else { return }

        do {
            let envelope = CardEnvelope(card: card, event: store.recentEvent)
            let url = try AirDropCardSender.prepareSharingFile(for: envelope)
            shareURL = url
            showingAirDrop = true
        } catch {
            self.error = error
            showingError = true
        }
    }
}

/// 送信用カードプレビュー
private struct CardSendPreview: View {
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

#Preview {
    CardSendView(store: MyCardStore())
}
