import SwiftUI

/// カードの配色定義
///
/// CardStyle.paletteID から実際の色を取得するために使用する。
/// 未知の ID は 0 番（朝霧）にフォールバックする。
enum Palette {
    /// パレット定義
    struct Definition {
        let id: Int
        let name: String
        let colors: [Color]
    }

    // MARK: - 定義済みパレット

    /// 0: 朝霧（ミント → オレンジ）
    static let asagiri = Definition(
        id: 0,
        name: "朝霧",
        colors: [.mint, .orange]
    )

    /// 1: 夕焼け（ピンク → オレンジ）
    static let yuuyake = Definition(
        id: 1,
        name: "夕焼け",
        colors: [.pink, .orange]
    )

    /// 2: 深海（ブルー → インディゴ）
    static let shinkai = Definition(
        id: 2,
        name: "深海",
        colors: [.blue, .indigo]
    )

    /// 3: 新緑（グリーン → イエロー）
    static let shinryoku = Definition(
        id: 3,
        name: "新緑",
        colors: [.green, .yellow]
    )

    /// 4: 藤色（パープル → ピンク）
    static let fujiiro = Definition(
        id: 4,
        name: "藤色",
        colors: [.purple, .pink]
    )

    /// 5: 墨（ブラック → グレー）
    static let sumi = Definition(
        id: 5,
        name: "墨",
        colors: [.black, .gray]
    )

    // MARK: - パレット一覧

    /// すべてのパレット
    static let all: [Definition] = [
        asagiri,
        yuuyake,
        shinkai,
        shinryoku,
        fujiiro,
        sumi
    ]

    // MARK: - アクセサ

    /// パレットIDから色を取得する
    ///
    /// - Parameter id: パレットID
    /// - Returns: 色の配列。未知のIDの場合は 0 番（朝霧）を返す
    static func colors(for id: Int) -> [Color] {
        guard id >= 0 && id < all.count else {
            return asagiri.colors
        }
        return all[id].colors
    }

    /// パレットIDから名前を取得する
    ///
    /// - Parameter id: パレットID
    /// - Returns: パレット名。未知のIDの場合は「朝霧」を返す
    static func name(for id: Int) -> String {
        guard id >= 0 && id < all.count else {
            return asagiri.name
        }
        return all[id].name
    }
}
