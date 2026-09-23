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

        // ファイル名をサニタイズ（/, \, :, * などを除去）
        let sanitizedName = envelope.card.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "*", with: "-")
            .replacingOccurrences(of: "?", with: "-")
            .replacingOccurrences(of: "\"", with: "-")
            .replacingOccurrences(of: "<", with: "-")
            .replacingOccurrences(of: ">", with: "-")
            .replacingOccurrences(of: "|", with: "-")
            .trimmingCharacters(in: .whitespaces)

        // 一時ディレクトリにファイルを作成
        let fileName = "\(sanitizedName).meilog"
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
            // 一時ファイルをクリーンアップ
            try? FileManager.default.removeItem(at: url)

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
