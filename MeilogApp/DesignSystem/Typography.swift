import SwiftUI

/// タイポグラフィ定義
///
/// 役割ごとにフォントを定義する。Dynamic Type に必ず対応すること。
/// 固定サイズの `.font(.system(size:))` は使わない。
///
/// 本文相当は最低 15pt 以上。カード上の小さい文字も 11pt を下限にする。
enum Typography {
    // MARK: - カード上のテキスト

    /// カード上の名前（大）
    static let cardName: Font = .title2.bold()

    /// カード上の肩書き
    static let cardTitle: Font = .subheadline

    /// カード上のリンク
    static let cardLink: Font = .caption

    // MARK: - UI要素

    /// セクションヘッダー
    static let sectionHeader: Font = .headline

    /// フィールドラベル
    static let fieldLabel: Font = .subheadline

    /// キャプション・説明文
    static let caption: Font = .caption

    /// 本文
    static let body: Font = .body

    /// ボタンラベル
    static let button: Font = .headline

    // MARK: - カスタムフォント使用例
    // カスタムフォントを使う場合は .custom(_:size:relativeTo:) で Dynamic Type に追従させる
    //
    // 例:
    // static let cardNameCustom: Font = .custom("YourFont-Bold", size: 22, relativeTo: .title2)
}

/// Typography の拡張 - Font.Weight の定義
extension Typography {
    enum Weight {
        static let regular: Font.Weight = .regular
        static let medium: Font.Weight = .medium
        static let semibold: Font.Weight = .semibold
        static let bold: Font.Weight = .bold
    }
}
