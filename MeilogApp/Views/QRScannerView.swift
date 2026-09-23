import SwiftUI
import SwiftData
import AVFoundation
import MeilogCore

/// QR スキャナー画面
struct QRScannerView: View {
    @Bindable var scanner: QRScanner
    @Bindable var store: EncounterListStore
    @Environment(\.dismiss) private var dismiss

    @State private var error: Error?
    @State private var showingError = false
    @State private var showingSuccess = false
    @State private var receivedCardName: String?

    var body: some View {
        ZStack {
            // カメラプレビュー
            CameraPreview(scanner: scanner)
                .ignoresSafeArea()

            // オーバーレイ
            VStack {
                Spacer()

                Text("QRコードをカメラに映してください")
                    .font(Typography.sectionHeader)
                    .padding(Space.md)
                    .background(.ultraThinMaterial)
                    .cornerRadius(Radius.control)
                    .padding(Space.md)
            }
        }
        .navigationTitle("QR 読み取り")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    dismiss()
                }
            }
        }
        .task {
            await scanner.requestAuthorization()

            if scanner.authorizationStatus == .authorized {
                do {
                    // セッションをセットアップしてから開始
                    try scanner.setupSession()
                    try scanner.startScanning()
                } catch {
                    self.error = error
                    showingError = true
                }
            } else {
                error = QRScannerError.notAuthorized
                showingError = true
            }
        }
        .onDisappear {
            scanner.stopScanning()
        }
        .onChange(of: scanner.scannedCode) { _, newValue in
            guard let code = newValue else { return }
            handleScannedCode(code)
        }
        .alert("エラー", isPresented: $showingError, presenting: error) { _ in
            Button("OK") {
                dismiss()
            }
        } message: { error in
            Text(error.localizedDescription)
        }
        .alert("カードを受け取りました", isPresented: $showingSuccess) {
            Button("OK") {
                scanner.clearScannedCode()
                dismiss()
            }
        } message: {
            if let name = receivedCardName {
                Text("\(name) さんのカードを受け取りました")
            }
        }
    }

    private func handleScannedCode(_ code: String) {
        do {
            let envelope = try CardPayload.decode(code)

            // Intent を送信
            store.send(.cardReceived(
                envelope,
                now: Date(),
                newID: UUID(),
                calendar: Calendar.current
            ))

            receivedCardName = envelope.card.name
            showingSuccess = true
        } catch {
            self.error = error
            showingError = true
        }
    }
}

/// カメラプレビュー用のカスタムUIView
private class CameraPreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()

        // レイアウト時にプレビューレイヤーのframeを更新
        if let previewLayer = previewLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = bounds
            CATransaction.commit()
        }
    }
}

/// カメラプレビュー
private struct CameraPreview: UIViewRepresentable {
    let scanner: QRScanner

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = scanner.getPreviewLayer()
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        // layoutSubviews で自動的に更新されるため、ここでは何もしない
    }
}

#Preview {
    NavigationStack {
        QRScannerView(
            scanner: QRScanner(),
            store: EncounterListStore(
                repository: SwiftDataEncounterRepository(
                    modelContainer: try! ModelContainer(for: EncounterEntity.self)
                ),
                myCardStore: MyCardStore()
            )
        )
    }
}
