import SwiftUI

/// 角丸定義
///
/// UI要素の角丸に使用する。
/// View 内で数値リテラルを直接書かず、この enum を使うこと。
enum Radius {
    /// 12pt - コントロール（ボタン、テキストフィールドなど）
    static let control: CGFloat = 12

    /// 16pt - カード
    static let card: CGFloat = 16

    /// 24pt - シート、モーダル
    static let sheet: CGFloat = 24

    /// pill - 高さの半分（完全な角丸）
    ///
    /// 使用例:
    /// ```swift
    /// RoundedRectangle(cornerRadius: height / 2)
    /// ```
    /// または
    /// ```swift
    /// .clipShape(Capsule())
    /// ```
}
