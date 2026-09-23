import SwiftUI

/// スプラッシュスクリーン
struct SplashView: View {
    @State private var animationPhase = 0
    @Environment(\.colorScheme) private var colorScheme

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            // 背景
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: Space.xl) {
                // カードアニメーション
                ZStack {
                    // 後ろのカード（ベージュ/ホワイト）
                    CardShape()
                        .fill(.white.opacity(0.9))
                        .frame(width: 120, height: 160)
                        .overlay {
                            CardShape()
                                .stroke(cardStrokeColor, lineWidth: 1)
                        }
                        .rotation3DEffect(
                            .degrees(backCardRotation),
                            axis: (x: 0, y: 1, z: 0)
                        )
                        .offset(x: backCardOffset.width, y: backCardOffset.height)

                    // 前のカード（グリーン）
                    CardShape()
                        .fill(cardColor)
                        .frame(width: 120, height: 160)
                        .overlay {
                            // カード内の線
                            VStack {
                                Spacer()
                                HStack(spacing: Space.xxs) {
                                    Rectangle()
                                        .fill(.white.opacity(0.3))
                                        .frame(width: 40, height: 2)
                                    Spacer()
                                }
                                .padding(.leading, Space.md)
                                .padding(.bottom, Space.lg)
                            }
                        }
                        .rotation3DEffect(
                            .degrees(frontCardRotation),
                            axis: (x: 0, y: 1, z: 0)
                        )
                        .offset(x: frontCardOffset.width, y: frontCardOffset.height)
                }
                .frame(height: 200)

                // ロゴ
                Text("Meilog")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .foregroundStyle(logoColor)
                    .opacity(animationPhase >= 2 ? 1 : 0)
            }
        }
        .task {
            await playAnimation()
        }
    }

    // MARK: - Animation

    private func playAnimation() async {
        // フェーズ1: カードが2枚重なっている
        animationPhase = 0
        try? await Task.sleep(for: .milliseconds(200))

        // フェーズ2: 重なり具合が変わる（スムーズなspring）
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            animationPhase = 1
        }
        try? await Task.sleep(for: .milliseconds(600))

        // フェーズ3: 各前面とロゴが現れる（より速く）
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            animationPhase = 2
        }
        try? await Task.sleep(for: .milliseconds(700))

        // 完了
        onComplete()
    }

    // MARK: - Computed Properties

    private var backgroundColor: Color {
        Color("SplashBackground")
    }

    private var cardColor: Color {
        Color(red: 0.20, green: 0.35, blue: 0.30)
    }

    private var cardStrokeColor: Color {
        colorScheme == .light ? Color.black.opacity(0.1) : Color.white.opacity(0.2)
    }

    private var logoColor: Color {
        colorScheme == .light ? Color(red: 0.20, green: 0.35, blue: 0.30) : Color.white
    }

    private var frontCardOffset: CGSize {
        switch animationPhase {
        case 0: return CGSize(width: -20, height: 10)
        case 1: return CGSize(width: -10, height: 5)
        default: return CGSize(width: 0, height: 0)
        }
    }

    private var backCardOffset: CGSize {
        switch animationPhase {
        case 0: return CGSize(width: 20, height: -10)
        case 1: return CGSize(width: 30, height: -15)
        default: return CGSize(width: 40, height: -20)
        }
    }

    private var frontCardRotation: Double {
        switch animationPhase {
        case 0: return -15
        case 1: return -8
        default: return 0
        }
    }

    private var backCardRotation: Double {
        switch animationPhase {
        case 0: return 15
        case 1: return 20
        default: return 25
        }
    }
}

/// カードシェイプ（角丸長方形）
private struct CardShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: Radius.card)
    }
}

#Preview("Light") {
    SplashView(onComplete: {})
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    SplashView(onComplete: {})
        .preferredColorScheme(.dark)
}
