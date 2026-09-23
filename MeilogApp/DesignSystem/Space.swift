import SwiftUI

/// スペーシング定義（8ptグリッド）
///
/// 画面の余白やコンポーネント間のスペーシングに使用する。
/// View 内で数値リテラルを直接書かず、この enum を使うこと。
///
/// 基準は 8pt。4pt は アイコンと文字の間など詰めたい箇所だけに使う。
/// 画面の左右マージンは `.md`（16pt）に統一する。
enum Space {
    /// 4pt - アイコンと文字の間など、詰めたい箇所のみ
    static let xxs: CGFloat = 4

    /// 8pt - 小さな要素間
    static let xs: CGFloat = 8

    /// 12pt - 関連する要素間
    static let sm: CGFloat = 12

    /// 16pt - セクション内の要素間、画面の左右マージン
    static let md: CGFloat = 16

    /// 24pt - セクション間
    static let lg: CGFloat = 24

    /// 32pt - 大きなセクション間
    static let xl: CGFloat = 32

    /// 40pt - 画面上部の余白など
    static let xxl: CGFloat = 40
}
