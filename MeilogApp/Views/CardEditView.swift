import SwiftUI
import struct MeilogCore.Link
import struct MeilogCore.Card
import struct MeilogCore.CardStyle

/// リンク編集用の識別可能なアイテム
struct LinkItem: Identifiable {
    let id = UUID()
    var kind: Link.Kind
    var value: String
}

/// カード編集画面
struct CardEditView: View {
    @Environment(\.dismiss) private var dismiss
    let store: MyCardStore

    @State private var name: String
    @State private var title: String
    @State private var links: [LinkItem]
    @State private var paletteID: Int
    @State private var patternID: Int
    @State private var avatarData: Data?

    init(store: MyCardStore) {
        self.store = store

        if let existing = store.myCard {
            _name = State(initialValue: existing.name)
            _title = State(initialValue: existing.title ?? "")
            _links = State(initialValue: existing.links.map { LinkItem(kind: $0.kind, value: $0.value) })
            _paletteID = State(initialValue: existing.style.paletteID)
            _patternID = State(initialValue: existing.style.patternID)
            _avatarData = State(initialValue: existing.avatar)
        } else {
            _name = State(initialValue: "")
            _title = State(initialValue: "")
            _links = State(initialValue: [])
            _paletteID = State(initialValue: 0)
            _patternID = State(initialValue: 0)
            _avatarData = State(initialValue: nil)
        }
    }

    private var isValid: Bool {
        !name.isEmpty && name.count <= 40 && title.count <= 60
    }

    var body: some View {
        VStack(spacing: 0) {
            // ナビゲーションバー
            HStack {
                Button("キャンセル") {
                    dismiss()
                }
                Spacer()
                Text("カードを編集")
                    .font(.headline)
                Spacer()
                Button("保存") {
                    saveCard()
                    dismiss()
                }
                .disabled(!isValid)
            }
            .padding()

            Divider()

            // コンテンツ
            ScrollView {
                VStack(spacing: 24) {
                    // カードプレビュー
                    CardPreviewSection(
                        name: name,
                        title: title,
                        links: links.map { Link(kind: $0.kind, value: $0.value) },
                        paletteID: paletteID,
                        patternID: patternID,
                        avatarData: avatarData
                    )

                    // プロフィール
                    ProfileSection(
                        name: $name,
                        title: $title,
                        avatarData: $avatarData
                    )

                    // リンク
                    LinksSection(links: $links)

                    // デザイン
                    DesignSection(
                        paletteID: $paletteID,
                        patternID: $patternID
                    )

                    // 説明
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("カードはこの編集中に保存されます。QRコードに入るのは名前・肩書き・リンク・デザインだけです。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // 保存ボタン
                    Button {
                        saveCard()
                        dismiss()
                    } label: {
                        Text("カードを保存")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isValid ? Color.green : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(!isValid)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
    }

    private func saveCard() {
        let id = store.myCard?.id ?? UUID()
        let card = Card(
            id: id,
            name: name,
            title: title.isEmpty ? nil : title,
            links: links.map { Link(kind: $0.kind, value: $0.value) },
            style: CardStyle(paletteID: paletteID, patternID: patternID),
            avatar: avatarData
        )
        store.saveMyCard(card)
    }
}

// MARK: - カードプレビューセクション
private struct CardPreviewSection: View {
    let name: String
    let title: String
    let links: [Link]
    let paletteID: Int
    let patternID: Int
    let avatarData: Data?

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
        guard paletteID >= 0 && paletteID < palettes.count else {
            return palettes[0]
        }
        return palettes[paletteID]
    }

    var body: some View {
        VStack(spacing: 12) {
            // カードプレビュー
            RoundedRectangle(cornerRadius: 16)
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
                .frame(height: 240)
                .overlay {
                    // 模様レイヤー
                    if patternID > 0 {
                        PatternOverlay(patternID: patternID)
                    }
                }
                .overlay {
                    VStack(spacing: 8) {
                        // アバター
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 60, height: 60)
                            .overlay {
                                if let avatarData = avatarData,
                                   let uiImage = UIImage(data: avatarData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .clipShape(Circle())
                                } else {
                                    Text(name.prefix(1))
                                        .font(.title)
                                        .foregroundStyle(.white)
                                }
                            }

                        // 名前と肩書き
                        if !name.isEmpty {
                            Text(name)
                                .font(.title3.bold())
                        }
                        if !title.isEmpty {
                            Text(title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        // リンク表示
                        ForEach(links.prefix(4), id: \.value) { link in
                            Text(link.value)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)

            Text("QRコードで相手に届く見た目です")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 模様オーバーレイ
private struct PatternOverlay: View {
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

// MARK: - プロフィールセクション
private struct ProfileSection: View {
    @Binding var name: String
    @Binding var title: String
    @Binding var avatarData: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("プロフィール")
                .font(.headline)

            // アバター
            HStack {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 60, height: 60)
                    .overlay {
                        if let avatarData = avatarData,
                           let uiImage = UIImage(data: avatarData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .clipShape(Circle())
                        } else {
                            Text(name.prefix(1))
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                    }

                Button {
                    // TODO: 写真選択
                } label: {
                    Label("写真を選ぶ", systemImage: "photo")
                }
                .buttonStyle(.bordered)

                if avatarData != nil {
                    Button("削除") {
                        avatarData = nil
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text("写真は近くの相手に直接送られます。\nQRコードには含まれません。")
                .font(.caption)
                .foregroundStyle(.secondary)

            // 名前
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("名前")
                        .font(.subheadline)
                    Text("必須")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                    Text("\(name.count)/40")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TextField("佐藤 ゆい", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
            }

            // 肩書き
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("肩書き")
                        .font(.subheadline)
                    Text("任意")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(title.count)/60")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TextField("iOSエンジニア", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.jobTitle)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - リンクセクション
private struct LinksSection: View {
    @Binding var links: [LinkItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("リンク")
                    .font(.headline)
                Spacer()
                Text("\(links.count)/4")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach($links) { $link in
                HStack(spacing: 12) {
                    Picker("", selection: $link.kind) {
                        Text("GitHub").tag(Link.Kind.github)
                        Text("X").tag(Link.Kind.x)
                        Text("Bluesky").tag(Link.Kind.bluesky)
                        Text("Mastodon").tag(Link.Kind.mastodon)
                        Text("Web").tag(Link.Kind.web)
                    }
                    .frame(width: 120)

                    TextField("yui-sato", text: $link.value)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.URL)

                    Button {
                        links.removeAll { $0.id == link.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if links.count < 4 {
                Button {
                    links.append(LinkItem(kind: .github, value: ""))
                } label: {
                    Label("リンクを追加", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - デザインセクション
private struct DesignSection: View {
    @Binding var paletteID: Int
    @Binding var patternID: Int

    // 配色の定義（仮）
    private let palettes: [[Color]] = [
        [.mint, .orange], // 朝霧
        [.pink, .orange], // 夕焼け
        [.blue, .indigo], // 深海
        [.green, .yellow], // 新緑
        [.purple, .pink], // 藤色
        [.black, .gray], // 墨
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("デザイン")
                .font(.headline)

            // 文字の配置（今回は省略、後で実装）
            VStack(alignment: .leading, spacing: 8) {
                Text("文字の配置")
                    .font(.subheadline)
                // TODO: 左揃え、中央、縦書きの選択UI
            }

            // 配色
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("配色")
                        .font(.subheadline)
                    Text("朝霧")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    ForEach(0..<6, id: \.self) { index in
                        Button {
                            paletteID = index
                        } label: {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: palettes[index],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                                .overlay {
                                    if paletteID == index {
                                        Circle()
                                            .stroke(Color.primary, lineWidth: 3)
                                    }
                                }
                        }
                    }
                }
            }

            // 模様
            VStack(alignment: .leading, spacing: 8) {
                Text("模様")
                    .font(.subheadline)

                HStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { index in
                        Button {
                            patternID = index
                        } label: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 50, height: 50)
                                .overlay {
                                    Text(patternName(index))
                                        .font(.caption2)
                                }
                                .overlay {
                                    if patternID == index {
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.primary, lineWidth: 2)
                                    }
                                }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func patternName(_ id: Int) -> String {
        switch id {
        case 0: return "なし"
        case 1: return "ドット"
        case 2: return "方眼"
        case 3: return "斜線"
        case 4: return "波紋"
        default: return ""
        }
    }
}

#Preview {
    CardEditView(store: MyCardStore())
}
