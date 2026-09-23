import SwiftUI

/// 影定義
///
/// UI要素の影に使用する。多用しない。
enum Shadow {
    /// カード用の影
    ///
    /// 使用例:
    /// ```swift
    /// RoundedRectangle(cornerRadius: Radius.card)
    ///     .shadow(color: Shadow.card.color, radius: Shadow.card.radius, y: Shadow.card.y)
    /// ```
    struct Card {
        let color: Color
        let radius: CGFloat
        let y: CGFloat
    }

    /// カード用の影
    static let card = Card(
        color: .black.opacity(0.1),
        radius: 12,
        y: 4
    )
}

/// View拡張 - 影を簡単に適用するヘルパー
extension View {
    /// カード用の影を適用する
    ///
    /// 使用例:
    /// ```swift
    /// RoundedRectangle(cornerRadius: Radius.card)
    ///     .cardShadow()
    /// ```
    func cardShadow() -> some View {
        self.shadow(
            color: Shadow.card.color,
            radius: Shadow.card.radius,
            y: Shadow.card.y
        )
    }
}
