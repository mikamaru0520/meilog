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
                        .font(.headline)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()

                ScrollView {
                    VStack(spacing: 24) {
                        // QRコード表示エリア
                        if let qrImage = qrImage, let card = store.myCard {
                            VStack(spacing: 24) {
                                // QRコード + アバターオーバーレイ
                                ZStack {
                                    Image(uiImage: qrImage)
                                        .interpolation(.none)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 300, maxHeight: 300)

                                    // 中央にアバター
                                    Circle()
                                        .fill(Color.primary)
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
                                .padding(40)
                                .background(.white)
                                .cornerRadius(24)
                                .shadow(color: .black.opacity(0.1), radius: 12, y: 4)

                                // 名前と肩書き
                                VStack(spacing: 4) {
                                    Text(card.name)
                                        .font(.title2.bold())
                                    if let title = card.title {
                                        Text(title)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.top, 24)
                        } else if isGenerating {
                            ProgressView("QR コード生成中...")
                                .frame(height: 400)
                                .frame(maxWidth: .infinity)
                        } else {
                            // 生成エラー時
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundStyle(.orange)
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
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("このQRに入るイベント")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(event.name)
                                            .font(.headline)
                                    }
                                    Spacer()
                                    Button("変更") {
                                        // TODO: イベント選択
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding()
                            .background(.regularMaterial)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }

                        // 説明文
                        VStack(spacing: 8) {
                            Text("相手の Meilog で読み取ってもらってください。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("表示中は画面を明るくしています。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
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
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding()
                    .background(.regularMaterial)

                    Text("表示中だけ、近くの相手にアイコン画像を送れます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
