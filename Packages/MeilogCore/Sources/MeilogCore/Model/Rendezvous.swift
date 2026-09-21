import Foundation

/// Rendezvous 関連のユーティリティ
public enum Rendezvous {
    /// Rendezvous 文字列を生成する（英数字8文字）
    ///
    /// - Returns: ランダムな英数字8文字の文字列
    public static func generate() -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<8).map { _ in characters[Int.random(in: 0..<characters.count)] })
    }

    /// Rendezvous が有効かどうかを検証する
    ///
    /// - Parameter rendezvous: 検証する文字列
    /// - Returns: 英数字8文字の場合 true
    public static func isValid(_ rendezvous: String) -> Bool {
        guard rendezvous.count == 8 else { return false }
        return rendezvous.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }
}
