import Foundation

/// CardEnvelope を JSON にエンコード・デコードする（Network.framework 用）
public enum CardPayload {
    /// CardEnvelope を JSON Data にエンコードする
    ///
    /// - Parameter envelope: エンコードする CardEnvelope
    /// - Returns: JSON Data
    /// - Throws: `CardPayloadError.constraintViolation` 制約違反時
    public static func encode(_ envelope: CardEnvelope) throws -> Data {
        // 制約チェック
        try validateConstraints(envelope)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970

        do {
            return try encoder.encode(envelope)
        } catch {
            throw CardPayloadError.malformed
        }
    }

    /// JSON Data から CardEnvelope にデコードする
    ///
    /// - Parameter data: JSON Data
    /// - Returns: デコードされた CardEnvelope
    /// - Throws: `CardPayloadError.malformed` または `CardPayloadError.constraintViolation`
    public static func decode(_ data: Data) throws -> CardEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let envelope: CardEnvelope
        do {
            envelope = try decoder.decode(CardEnvelope.self, from: data)
        } catch {
            throw CardPayloadError.malformed
        }

        // デコード後も制約チェック
        try validateConstraints(envelope)

        return envelope
    }

    // MARK: - Private

    /// CardEnvelope の制約をチェックする
    private static func validateConstraints(_ envelope: CardEnvelope) throws {
        let card = envelope.card

        // card.name: 1〜40 文字
        guard !card.name.isEmpty, card.name.count <= 40 else {
            throw CardPayloadError.constraintViolation
        }

        // card.title: 60 文字まで（省略可）
        if let title = card.title, title.count > 60 {
            throw CardPayloadError.constraintViolation
        }

        // card.links: 4 件まで
        guard card.links.count <= 4 else {
            throw CardPayloadError.constraintViolation
        }

        // card.links[].value: 100 文字まで
        for link in card.links {
            guard link.value.count <= 100 else {
                throw CardPayloadError.constraintViolation
            }
        }

        // event.name: 1〜60 文字
        if let event = envelope.event {
            guard !event.name.isEmpty, event.name.count <= 60 else {
                throw CardPayloadError.constraintViolation
            }

            // event.venue: 60 文字まで（省略可）
            if let venue = event.venue, venue.count > 60 {
                throw CardPayloadError.constraintViolation
            }
        }
    }
}
