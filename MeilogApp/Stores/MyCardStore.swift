import Foundation
import OSLog
import MeilogCore

/// 自分のカードと直近のイベントを管理する Store（MVI パターン）
@MainActor
@Observable
final class MyCardStore {
    private(set) var state = MyCardState()

    private let userDefaults: UserDefaults
    private let myCardKey = "myCard"
    private let recentEventKey = "recentEvent"
    private let logger = Logger(subsystem: "com.example.meilog", category: "MyCardStore")

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Intent を送信する
    func send(_ intent: MyCardIntent) {
        let (newState, effects) = reduce(state, intent)
        state = newState

        for effect in effects {
            run(effect)
        }
    }

    /// 自分のカード（State から取得）
    var myCard: Card? {
        state.card
    }

    /// 直近のイベント（State から取得）
    var recentEvent: MeetupEvent? {
        state.recentEvent
    }

    /// 初回起動かどうか（State から取得）
    var isFirstLaunch: Bool {
        state.isFirstLaunch
    }

    // 後方互換性のためのメソッド（View が直接呼ぶ）
    func saveMyCard(_ card: Card) {
        send(.cardSaved(card))
    }

    func saveRecentEvent(_ event: MeetupEvent?) {
        send(.recentEventSaved(event))
    }

    // MARK: - Private

    private func run(_ effect: MyCardEffect) {
        switch effect {
        case .load:
            let card = loadMyCard()
            let event = loadRecentEvent()
            send(.loaded(card: card, recentEvent: event))

        case .persistCard(let card):
            do {
                let data = try JSONEncoder().encode(card)
                userDefaults.set(data, forKey: myCardKey)
            } catch {
                logger.error("Failed to save my card: \(error.localizedDescription)")
            }

        case .persistRecentEvent(let event):
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
    }

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
