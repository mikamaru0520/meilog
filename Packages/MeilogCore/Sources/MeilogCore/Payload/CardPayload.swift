import Foundation

/// CardPayload の encode / decode
public enum CardPayload {
    /// URL から CardEnvelope を decode する
    ///
    /// - Parameter urlString: `meilog://v1/card?d=...` 形式の URL
    /// - Returns: デコードされた CardEnvelope
    /// - Throws: CardPayloadError
    public static func decode(_ urlString: String) throws -> CardEnvelope {
        guard let url = URL(string: urlString) else {
            throw CardPayloadError.malformed
        }

        // scheme チェック
        guard url.scheme == "meilog" else {
            throw CardPayloadError.unsupportedScheme
        }

        // version チェック
        guard url.host == "v1" else {
            throw CardPayloadError.unsupportedVersion
        }

        // path チェック
        guard url.path == "/card" else {
            throw CardPayloadError.malformed
        }

        // query パラメータ d を取得
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let dataParam = queryItems.first(where: { $0.name == "d" })?.value else {
            throw CardPayloadError.malformed
        }

        // base64url デコード（パディングなし）
        guard let jsonData = Data(base64URLEncoded: dataParam) else {
            throw CardPayloadError.malformed
        }

        // JSON デコード
        let dto: PayloadDTO
        do {
            dto = try JSONDecoder().decode(PayloadDTO.self, from: jsonData)
        } catch {
            throw CardPayloadError.malformed
        }

        // DTO → ドメインモデル変換
        let card = try dto.card.toDomain()
        let event = try dto.event?.toDomain()

        return CardEnvelope(card: card, event: event, rendezvous: dto.rendezvous)
    }

    /// CardEnvelope から URL を生成する
    ///
    /// - Parameter envelope: エンコードする CardEnvelope
    /// - Returns: `meilog://v1/card?d=...` 形式の URL 文字列
    /// - Throws: CardPayloadError
    public static func encode(_ envelope: CardEnvelope) throws -> String {
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
        if let rendezvous = envelope.rendezvous {
            // rendezvous は英数字8文字
            guard Rendezvous.isValid(rendezvous) else {
                throw CardPayloadError.constraintViolation
            }
        }

        // ドメインモデル → DTO 変換
        let dto = PayloadDTO(
            card: envelope.card.toDTO(),
            event: envelope.event?.toDTO(),
            rendezvous: envelope.rendezvous
        )

        // JSON エンコード
        let jsonData: Data
        do {
            jsonData = try JSONEncoder().encode(dto)
        } catch {
            throw CardPayloadError.malformed
        }

        // base64url エンコード（パディングなし）
        let base64String = jsonData.base64URLEncodedString()

        // URL 組み立て
        let urlString = "meilog://v1/card?d=\(base64String)"

        // サイズチェック
        guard urlString.utf8.count <= 800 else {
            throw CardPayloadError.tooLarge
        }

        return urlString
    }
}

// MARK: - Base64URL ヘルパー

extension Data {
    /// base64url デコード（RFC 4648 §5、パディングなし）
    init?(base64URLEncoded string: String) {
        // base64url → base64 変換
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // パディング追加
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64) else {
            return nil
        }
        self = data
    }

    /// base64url エンコード（パディングなし）
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
