import Foundation

/// CardPayload の encode / decode エラー
public enum CardPayloadError: Error, Equatable {
    /// JSON の形式が不正、必須キーの欠落など
    case malformed
    /// 文字数・件数などの制約違反
    case constraintViolation
}
