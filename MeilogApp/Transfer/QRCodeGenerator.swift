import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import MeilogCore

/// QR コード生成
enum QRCodeGenerator {
    /// CardEnvelope から QR コード画像を生成する
    ///
    /// - Parameters:
    ///   - envelope: エンコードする CardEnvelope
    ///   - correctionLevel: 誤り訂正レベル（"L", "M", "Q", "H"）。デフォルトは "M"
    /// - Returns: QR コード画像（UIImage）
    /// - Throws: CardPayloadError
    static func generateQRCode(
        from envelope: CardEnvelope,
        correctionLevel: String = "M"
    ) throws -> UIImage {
        // CardPayload.encode で URL 文字列を生成
        let urlString = try CardPayload.encode(envelope)

        guard let data = urlString.data(using: .utf8) else {
            throw CardPayloadError.malformed
        }

        // CIQRCodeGenerator で QR コードを生成
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = correctionLevel

        guard let outputImage = filter.outputImage else {
            throw CardPayloadError.malformed
        }

        // QR コードを拡大（デフォルトのサイズは小さすぎるため）
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw CardPayloadError.malformed
        }

        return UIImage(cgImage: cgImage)
    }

    /// QR コードの中央にアイコン画像を合成する
    ///
    /// - Parameters:
    ///   - qrImage: ベースとなる QR コード画像
    ///   - icon: 中央に載せるアイコン画像
    ///   - iconSizeRatio: QR コード全体に対するアイコンのサイズ比率（0.0〜1.0）。デフォルトは 0.2
    /// - Returns: アイコンを合成した QR コード画像
    static func embedIcon(
        in qrImage: UIImage,
        icon: UIImage,
        iconSizeRatio: CGFloat = 0.2
    ) -> UIImage {
        let qrSize = qrImage.size
        let iconSize = CGSize(
            width: qrSize.width * iconSizeRatio,
            height: qrSize.height * iconSizeRatio
        )

        UIGraphicsBeginImageContextWithOptions(qrSize, false, qrImage.scale)
        defer { UIGraphicsEndImageContext() }

        // QR コードを描画
        qrImage.draw(in: CGRect(origin: .zero, size: qrSize))

        // アイコンを中央に描画
        let iconOrigin = CGPoint(
            x: (qrSize.width - iconSize.width) / 2,
            y: (qrSize.height - iconSize.height) / 2
        )
        icon.draw(in: CGRect(origin: iconOrigin, size: iconSize))

        guard let compositeImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return qrImage
        }

        return compositeImage
    }
}
