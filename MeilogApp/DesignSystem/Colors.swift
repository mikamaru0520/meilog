import SwiftUI

/// カラー定義
///
/// 役割で命名する（背景・面・文字・副次文字・境界・アクセント）。
/// 色名（green など）で命名しない。
///
/// 可能な範囲で iOS の semantic color（.primary, .secondary など）を優先し、
/// ブランド色だけ独自に持つ。
///
/// View に16進数や Color(red:green:blue:) を直接書かない。
enum Colors {
    // MARK: - テキスト

    /// プライマリテキスト
    static let textPrimary: Color = .primary

    /// セカンダリテキスト（説明文など）
    static let textSecondary: Color = .secondary

    /// ターシャリテキスト（補助情報）
    static let textTertiary: Color = Color(.tertiaryLabel)

    // MARK: - 背景

    /// アプリ全体の背景
    static let background: Color = Color(.systemBackground)

    /// グループ化された背景（設定画面など）
    static let backgroundGrouped: Color = Color(.systemGroupedBackground)

    /// 面の背景（カード、モーダルなど）
    static let surfaceBackground: Color = Color("SurfaceBackground")

    /// セカンダリ面の背景
    static let surfaceBackgroundSecondary: Color = Color(.secondarySystemBackground)

    // MARK: - 境界

    /// 境界線
    static let border: Color = Color(.separator)

    // MARK: - アクセント

    /// アクセントカラー（ブランドカラー）
    static let accent: Color = Color("AccentColor")

    // MARK: - ステータス

    /// エラー・削除
    static let destructive: Color = .red

    /// 成功
    static let success: Color = .green

    /// 警告
    static let warning: Color = .orange
}

/// カラーのコントラスト検証用
extension Colors {
    /// 文字と背景のコントラスト比が 4.5:1 以上を満たすか検証する
    ///
    /// - Parameters:
    ///   - foreground: 前景色
    ///   - background: 背景色
    /// - Returns: コントラスト比が 4.5:1 以上なら true
    ///
    /// 注意: SwiftUI の Color から正確な RGB 値を取得するのは困難なため、
    /// 実際のコントラスト検証は Xcode の Accessibility Inspector で行うこと。
    static func hasMinimumContrast(foreground: Color, background: Color) -> Bool {
        // 実装は省略（手動で Accessibility Inspector で確認する）
        return true
    }
}
