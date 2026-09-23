import UniformTypeIdentifiers

extension UTType {
    /// Meilog カード用のカスタム UTType (.meilog 拡張子)
    static let meilogCard = UTType(exportedAs: "com.example.meilog.card", conformingTo: .json)
}
