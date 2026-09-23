import SwiftUI
import UIKit
import MeilogCore

/// QRコード表示モーダル
struct QRCodeModalView: View {
    @Environment(\.dismiss) private var dismiss
    let store: MyCardStore

    @State private var qrImage: UIImage?
    @State private var isGenerating = false
    @State private var rendezvous: String?
    @State private var originalBrightness: CGFloat = UIScreen.main.brightness

    var body: some View {
        ZStack {
            // 常に白背景（ダークモードでも）
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ナビゲーションバー
                HStack {
                    Text("QRコード")
                        .font(Typography.sectionHeader)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Colors.textSecondary)
                    }
                    .accessibilityLabel("閉じる")
                }
                .padding(Space.md)

                ScrollView {
                    VStack(spacing: Space.lg) {
                        // QRコード表示エリア
                        if let qrImage = qrImage, let card = store.myCard {
                            VStack(spacing: Space.lg) {
                                // QRコード + アバターオーバーレイ
                                ZStack {
                                    Image(uiImage: qrImage)
                                        .interpolation(.none)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 300, maxHeight: 300)

                                    // 中央にアバター
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
                                                    .font(.title.bold())
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .overlay {
                                            Circle()
                                                .stroke(Color.white, lineWidth: 4)
                                        }
                                }
                                .padding(Space.xxl)
                                .background(.white)
                                .cornerRadius(Radius.sheet)
                                .cardShadow()

                                // 名前と肩書き
                                VStack(spacing: Space.xxs) {
                                    Text(card.name)
                                        .font(Typography.cardName)
                                    if let title = card.title {
                                        Text(title)
                                            .font(Typography.cardTitle)
                                            .foregroundStyle(Colors.textSecondary)
                                    }
                                }
                            }
                            .padding(.top, Space.lg)
                        } else if isGenerating {
                            ProgressView("QR コード生成中...")
                                .frame(height: 400)
                                .frame(maxWidth: .infinity)
                        } else {
                            // 生成エラー時
                            VStack(spacing: Space.md) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundStyle(Colors.warning)
                                Text("QR コードの生成に失敗しました")
                                Button("再試行") {
                                    Task {
                                        await generateQRCode()
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            .frame(height: 400)
                        }

                        // イベント情報セクション
                        if let event = store.recentEvent {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                HStack {
                                    VStack(alignment: .leading, spacing: Space.xxs) {
                                        Text("このQRに入るイベント")
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
                        VStack(spacing: Space.xs) {
                            Text("相手の Meilog で読み取ってもらってください。")
                                .font(Typography.body)
                                .foregroundStyle(Colors.textSecondary)
                            Text("表示中は画面を明るくしています。")
                                .font(Typography.body)
                                .foregroundStyle(Colors.textSecondary)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.md)
                        .padding(.bottom, 100)
                    }
                }

                // 固定フッター
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        // TODO: QR読み取り画面へ
                    } label: {
                        Label("相手のQRを読み取る", systemImage: "qrcode.viewfinder")
                            .font(Typography.button)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(Space.md)
                    .background(.regularMaterial)

                    Text("表示中だけ、近くの相手にアイコン画像を送れます")
                        .font(Typography.caption)
                        .foregroundStyle(Colors.textSecondary)
                        .padding(.bottom)
                }
            }
        }
        .preferredColorScheme(.light) // 常にライトモード
        .task {
            // 画面表示時の処理
            await onAppear()
        }
        .onDisappear {
            onDisappear()
        }
    }

    private func onAppear() async {
        // 元の明るさを保存
        originalBrightness = UIScreen.main.brightness

        // 明るさを上げる（暗い会場での読み取り成功率向上）
        UIScreen.main.brightness = 1.0

        // スリープを無効化（QR表示中に画面が消えないように）
        UIApplication.shared.isIdleTimerDisabled = true

        // rendezvous を生成（MultipeerConnectivity 用）
        rendezvous = Rendezvous.generate()

        // QR コード生成
        await generateQRCode()

        // TODO: MultipeerConnectivity でアドバタイズ開始
        // if let rendezvous = rendezvous, let avatar = store.myCard?.avatar {
        //     await avatarAdvertiser.start(rendezvous: rendezvous, avatar: avatar)
        // }
    }

    private func onDisappear() {
        // 明るさを元に戻す
        UIScreen.main.brightness = originalBrightness

        // スリープ無効化を解除
        UIApplication.shared.isIdleTimerDisabled = false

        // TODO: MultipeerConnectivity でアドバタイズ停止
        // await avatarAdvertiser.stop()
    }

    private func generateQRCode() async {
        guard let card = store.myCard else { return }

        isGenerating = true
        defer { isGenerating = false }

        let envelope = CardEnvelope(
            card: card,
            event: store.recentEvent,
            rendezvous: rendezvous
        )

        do {
            let image = try await QRCodeGenerator.generateQRCode(from: envelope)
            qrImage = image
        } catch {
            print("Failed to generate QR code: \(error.localizedDescription)")
            qrImage = nil
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
    return QRCodeModalView(store: store)
}
