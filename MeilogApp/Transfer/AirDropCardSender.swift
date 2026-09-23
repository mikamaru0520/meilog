import SwiftUI
import UniformTypeIdentifiers
import MeilogCore

/// AirDrop でカードを送信するヘルパー
struct AirDropCardSender {
    /// CardEnvelope を一時ファイルとして保存し、AirDrop 用の URL を返す
    ///
    /// - Parameter envelope: 送信する CardEnvelope
    /// - Returns: 一時ファイルの URL
    /// - Throws: エンコードまたはファイル書き込みエラー
    static func prepareSharingFile(for envelope: CardEnvelope) throws -> URL {
        // JSON にエンコード
        let data = try CardPayload.encode(envelope)

        // 一時ディレクトリにファイルを作成
        let fileName = "\(envelope.card.name).meilog"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)

        // ファイルに書き込み
        try data.write(to: tempURL)

        return tempURL
    }
}

/// AirDrop シートを表示するための UIViewControllerRepresentable
struct AirDropSheet: UIViewControllerRepresentable {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        // 完了時のハンドラ
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            if completed {
                // 送信完了
                dismiss()
            }
        }

        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // 更新不要
    }
}
