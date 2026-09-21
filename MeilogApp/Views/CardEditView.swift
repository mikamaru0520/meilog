import SwiftUI
import MeilogCore

/// カード編集画面
struct CardEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: MyCardStore

    @State private var name: String
    @State private var title: String
    @State private var paletteID: Int
    @State private var patternID: Int

    private let cardID: UUID

    init(store: MyCardStore) {
        self.store = store

        // 既存のカードがあれば編集、なければ新規作成
        if let existing = store.myCard {
            _name = State(initialValue: existing.name)
            _title = State(initialValue: existing.title ?? "")
            _paletteID = State(initialValue: existing.style.paletteID)
            _patternID = State(initialValue: existing.style.patternID)
            cardID = existing.id
        } else {
            _name = State(initialValue: "")
            _title = State(initialValue: "")
            _paletteID = State(initialValue: 0)
            _patternID = State(initialValue: 0)
            cardID = UUID()
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("名前", text: $name)
                        .textContentType(.name)

                    TextField("肩書き（任意）", text: $title)
                        .textContentType(.jobTitle)
                }

                Section("デザイン") {
                    Stepper("パレット ID: \(paletteID)", value: $paletteID, in: 0...10)
                    Stepper("パターン ID: \(patternID)", value: $patternID, in: 0...10)
                }

                Section {
                    Text("リンクの編集は後のバージョンで実装予定")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .navigationTitle("カード編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveCard()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !name.isEmpty && name.count <= 40 && title.count <= 60
    }

    private func saveCard() {
        let card = Card(
            id: cardID,
            name: name,
            title: title.isEmpty ? nil : title,
            links: [],  // リンクは後で実装
            style: CardStyle(paletteID: paletteID, patternID: patternID),
            avatar: nil
        )

        store.saveMyCard(card)
    }
}

#Preview {
    CardEditView(store: MyCardStore())
}
