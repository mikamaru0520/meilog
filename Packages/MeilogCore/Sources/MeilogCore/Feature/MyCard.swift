import Foundation

// MARK: - State

/// 自分のカードと直近のイベントの State
public struct MyCardState: Equatable, Sendable {
    /// 自分のカード（初回起動時は nil）
    public var card: Card?

    /// 直近のイベント
    public var recentEvent: MeetupEvent?

    public init(
        card: Card? = nil,
        recentEvent: MeetupEvent? = nil
    ) {
        self.card = card
        self.recentEvent = recentEvent
    }

    /// 初回起動かどうか
    public var isFirstLaunch: Bool {
        card == nil
    }
}

// MARK: - Intent

/// 自分のカード管理の Intent
public enum MyCardIntent: Sendable {
    /// 画面が表示された
    case appeared

    /// 永続化層から読み込み完了
    case loaded(card: Card?, recentEvent: MeetupEvent?)

    /// カードを保存
    case cardSaved(Card)

    /// 直近のイベントを保存
    case recentEventSaved(MeetupEvent?)
}

// MARK: - Effect

/// 自分のカード管理の Effect
public enum MyCardEffect: Equatable, Sendable {
    /// 永続化層から読み込む
    case load

    /// カードを永続化する
    case persistCard(Card)

    /// 直近のイベントを永続化する
    case persistRecentEvent(MeetupEvent?)
}

// MARK: - Reducer

/// MyCard の reduce 関数
///
/// - Parameters:
///   - state: 現在の State
///   - intent: Intent
/// - Returns: 新しい State と Effect の配列
public func reduce(
    _ state: MyCardState,
    _ intent: MyCardIntent
) -> (MyCardState, [MyCardEffect]) {
    var newState = state
    var effects: [MyCardEffect] = []

    switch intent {
    case .appeared:
        // 起動時にロード
        effects.append(.load)

    case .loaded(let card, let recentEvent):
        // 読み込み完了
        newState.card = card
        newState.recentEvent = recentEvent

    case .cardSaved(let card):
        // カードを保存
        newState.card = card
        effects.append(.persistCard(card))

    case .recentEventSaved(let event):
        // 直近のイベントを保存
        newState.recentEvent = event
        effects.append(.persistRecentEvent(event))
    }

    return (newState, effects)
}
