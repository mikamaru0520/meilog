import Foundation
import OSLog
import MeilogCore

/// 自分のカードと直近のイベントを管理する Store
@MainActor
@Observable
final class MyCardStore {
    /// 自分のカード（初回起動時は nil）
    private(set) var myCard: Card?

    /// 直近のイベント
    private(set) var recentEvent: MeetupEvent?

    private let userDefaults: UserDefaults
    private let myCardKey = "myCard"
    private let recentEventKey = "recentEvent"
    private let logger = Logger(subsystem: "com.example.meilog", category: "MyCardStore")

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.myCard = loadMyCard()
        self.recentEvent = loadRecentEvent()
    }

    /// 自分のカードを保存する
    func saveMyCard(_ card: Card) {
        myCard = card

        do {
            let data = try JSONEncoder().encode(card)
            userDefaults.set(data, forKey: myCardKey)
        } catch {
            logger.error("Failed to save my card: \(error.localizedDescription)")
        }
    }

    /// 直近のイベントを保存する
    func saveRecentEvent(_ event: MeetupEvent?) {
        recentEvent = event

        if let event = event {
            do {
                let data = try JSONEncoder().encode(event)
                userDefaults.set(data, forKey: recentEventKey)
            } catch {
                logger.error("Failed to save recent event: \(error.localizedDescription)")
            }
        } else {
            userDefaults.removeObject(forKey: recentEventKey)
        }
    }

    /// 初回起動かどうか
    var isFirstLaunch: Bool {
        myCard == nil
    }

    // MARK: - Private

    private func loadMyCard() -> Card? {
        guard let data = userDefaults.data(forKey: myCardKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(Card.self, from: data)
        } catch {
            logger.error("Failed to load my card: \(error.localizedDescription)")
            return nil
        }
    }

    private func loadRecentEvent() -> MeetupEvent? {
        guard let data = userDefaults.data(forKey: recentEventKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(MeetupEvent.self, from: data)
        } catch {
            logger.error("Failed to load recent event: \(error.localizedDescription)")
            return nil
        }
    }
}
