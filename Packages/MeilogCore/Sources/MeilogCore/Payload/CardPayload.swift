import Foundation

/// CardPayload の encode / decode（AirDrop 用 JSON 形式）
public enum CardPayload {
    /// JSON Data から CardEnvelope を decode する
    ///
    /// - Parameter data: JSON データ
    /// - Returns: デコードされた CardEnvelope
    /// - Throws: CardPayloadError
    public static func decode(_ data: Data) throws -> CardEnvelope {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(CardEnvelope.self, from: data)
        } catch {
            throw CardPayloadError.malformed
        }
    }

    /// CardEnvelope を JSON Data に encode する
    ///
    /// - Parameter envelope: エンコードする CardEnvelope
    /// - Returns: JSON データ
    /// - Throws: CardPayloadError
    public static func encode(_ envelope: CardEnvelope) throws -> Data {
        // 制約チェック
        guard !envelope.card.name.isEmpty, envelope.card.name.count <= 40 else {
            throw CardPayloadError.constraintViolation
        }
        if let title = envelope.card.title, title.count > 60 {
            throw CardPayloadError.constraintViolation
        }
        if envelope.card.links.count > 5 {
            throw CardPayloadError.constraintViolation
        }
        for link in envelope.card.links {
            if link.value.count > 100 {
                throw CardPayloadError.constraintViolation
            }
        }
        if let event = envelope.event {
            guard !event.name.isEmpty, event.name.count <= 60 else {
                throw CardPayloadError.constraintViolation
            }
            if let venue = event.venue, venue.count > 60 {
                throw CardPayloadError.constraintViolation
            }
        }

        // JSON エンコード
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            return try encoder.encode(envelope)
        } catch {
            throw CardPayloadError.malformed
        }
    }
}
