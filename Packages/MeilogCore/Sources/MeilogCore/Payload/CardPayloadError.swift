import Foundation

/// CardPayload の encode / decode エラー
public enum CardPayloadError: Error, Equatable {
    /// scheme が meishi 以外
    case unsupportedScheme
    /// host が v1 以外（UI では「アプリを更新してください」）
    case unsupportedVersion
    /// URL や JSON の形式が不正、必須キーの欠落など
    case malformed
    /// 文字数・件数などの制約違反
    case constraintViolation
    /// URL 全体が 800 バイトを超えた（encode のみ）
    case tooLarge
}
