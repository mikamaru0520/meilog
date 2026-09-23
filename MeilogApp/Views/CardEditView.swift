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
                    .font(Typography.sectionHeader)
                Spacer()
                Button("保存") {
                    saveCard()
                    dismiss()
                }
                .disabled(!isValid)
            }
            .padding(Space.md)

            Divider()

            // コンテンツ
            ScrollView {
                VStack(spacing: Space.lg) {
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
                    HStack(alignment: .top, spacing: Space.xs) {
                        Image(systemName: "lock.fill")
                            .font(Typography.caption)
                            .foregroundStyle(Colors.textSecondary)
                        Text("カードはこの編集中に保存されます。QRコードに入るのは名前・肩書き・リンク・デザインだけです。")
                            .font(Typography.caption)
                            .foregroundStyle(Colors.textSecondary)
                    }
                    .padding(.horizontal, Space.md)

                    // 保存ボタン
                    Button {
                        saveCard()
                        dismiss()
                    } label: {
                        Text("カードを保存")
                            .font(Typography.button)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(Space.md)
                            .background(isValid ? Colors.success : Colors.textSecondary)
                            .cornerRadius(Radius.control)
                    }
                    .disabled(!isValid)
                    .padding(.horizontal, Space.md)
                    .padding(.bottom, Space.md)
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

    var body: some View {
        VStack(spacing: Space.sm) {
            // カードプレビュー
            RoundedRectangle(cornerRadius: Radius.card)
                .fill(
                    LinearGradient(
                        colors: Palette.colors(for: paletteID).map { $0.opacity(0.4) },
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
                    VStack(spacing: Space.xs) {
                        // アバター
                        Circle()
                            .fill(Colors.textPrimary)
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
                                        .font(Typography.cardName)
                                        .foregroundStyle(.white)
                                }
                            }

                        // 名前と肩書き
                        if !name.isEmpty {
                            Text(name)
                                .font(Typography.cardName)
                        }
                        if !title.isEmpty {
                            Text(title)
                                .font(Typography.cardTitle)
                                .foregroundStyle(Colors.textSecondary)
                        }

                        // リンク表示
                        ForEach(links.prefix(4), id: \.value) { link in
                            Text(link.value)
                                .font(Typography.cardLink)
                                .foregroundStyle(Colors.textSecondary)
                        }
                    }
                    .padding(Space.md)
                }
                .padding(.horizontal, Space.md)

            Text("QRコードで相手に届く見た目です")
                .font(Typography.caption)
                .foregroundStyle(Colors.textSecondary)
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

// MARK: - プロフィールセクション
private struct ProfileSection: View {
    @Binding var name: String
    @Binding var title: String
    @Binding var avatarData: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("プロフィール")
                .font(Typography.sectionHeader)

            // アバター
            HStack(spacing: Space.sm) {
                Circle()
                    .fill(Colors.textPrimary)
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
                                .font(Typography.cardName)
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
                .font(Typography.caption)
                .foregroundStyle(Colors.textSecondary)

            // 名前
            VStack(alignment: .leading, spacing: Space.xxs) {
                HStack {
                    Text("名前")
                        .font(Typography.fieldLabel)
                    Text("必須")
                        .font(Typography.caption)
                        .foregroundStyle(Colors.destructive)
                    Spacer()
                    Text("\(name.count)/40")
                        .font(Typography.caption)
                        .foregroundStyle(Colors.textSecondary)
                }
                TextField("佐藤 ゆい", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
            }

            // 肩書き
            VStack(alignment: .leading, spacing: Space.xxs) {
                HStack {
                    Text("肩書き")
                        .font(Typography.fieldLabel)
                    Text("任意")
                        .font(Typography.caption)
                        .foregroundStyle(Colors.textSecondary)
                    Spacer()
                    Text("\(title.count)/60")
                        .font(Typography.caption)
                        .foregroundStyle(Colors.textSecondary)
                }
                TextField("iOSエンジニア", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.jobTitle)
            }
        }
        .padding(.horizontal, Space.md)
    }
}

// MARK: - リンクセクション
private struct LinksSection: View {
    @Binding var links: [LinkItem]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text("リンク")
                    .font(Typography.sectionHeader)
                Spacer()
                Text("\(links.count)/4")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.textSecondary)
            }

            ForEach($links) { $link in
                HStack(spacing: Space.sm) {
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
                            .foregroundStyle(Colors.textSecondary)
                    }
                    .accessibilityLabel("リンクを削除")
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
        .padding(.horizontal, Space.md)
    }
}

// MARK: - デザインセクション
private struct DesignSection: View {
    @Binding var paletteID: Int
    @Binding var patternID: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("デザイン")
                .font(Typography.sectionHeader)

            // 文字の配置（今回は省略、後で実装）
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("文字の配置")
                    .font(Typography.fieldLabel)
                // TODO: 左揃え、中央、縦書きの選択UI
            }

            // 配色
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack {
                    Text("配色")
                        .font(Typography.fieldLabel)
                    Text(Palette.name(for: paletteID))
                        .font(Typography.caption)
                        .foregroundStyle(Colors.textSecondary)
                }

                HStack(spacing: Space.sm) {
                    ForEach(0..<Palette.all.count, id: \.self) { index in
                        Button {
                            paletteID = index
                        } label: {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: Palette.colors(for: index),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                                .overlay {
                                    if paletteID == index {
                                        Circle()
                                            .stroke(Colors.textPrimary, lineWidth: 3)
                                    }
                                }
                        }
                        .accessibilityLabel(Palette.name(for: index))
                    }
                }
            }

            // 模様
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("模様")
                    .font(Typography.fieldLabel)

                HStack(spacing: Space.sm) {
                    ForEach(0..<5, id: \.self) { index in
                        Button {
                            patternID = index
                        } label: {
                            RoundedRectangle(cornerRadius: Radius.control / 2)
                                .fill(Colors.textSecondary.opacity(0.1))
                                .frame(width: 50, height: 50)
                                .overlay {
                                    Text(patternName(index))
                                        .font(Typography.caption)
                                }
                                .overlay {
                                    if patternID == index {
                                        RoundedRectangle(cornerRadius: Radius.control / 2)
                                            .stroke(Colors.textPrimary, lineWidth: 2)
                                    }
                                }
                        }
                        .accessibilityLabel("模様: \(patternName(index))")
                    }
                }
            }
        }
        .padding(.horizontal, Space.md)
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
