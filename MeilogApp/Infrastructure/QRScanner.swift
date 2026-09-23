@preconcurrency import AVFoundation
import SwiftUI

/// QR コードスキャナー
@MainActor
@Observable
final class QRScanner: NSObject {
    /// カメラの権限状態
    enum AuthorizationStatus {
        case notDetermined
        case authorized
        case denied
    }

    /// スキャン結果
    var scannedCode: String?

    /// カメラ権限の状態
    private(set) var authorizationStatus: AuthorizationStatus = .notDetermined

    @ObservationIgnored
    nonisolated(unsafe) private let captureSession = AVCaptureSession()
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var isSessionConfigured = false

    /// カメラ権限をリクエストする
    func requestAuthorization() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorizationStatus = granted ? .authorized : .denied
        case .authorized:
            authorizationStatus = .authorized
        case .denied, .restricted:
            authorizationStatus = .denied
        @unknown default:
            authorizationStatus = .denied
        }
    }

    /// スキャンを開始する
    func startScanning() throws {
        guard authorizationStatus == .authorized else {
            throw QRScannerError.notAuthorized
        }

        // セッションがまだ設定されていない場合のみ設定
        if !isSessionConfigured {
            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
                throw QRScannerError.noCameraAvailable
            }

            let videoInput: AVCaptureDeviceInput
            do {
                videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            } catch {
                throw QRScannerError.inputFailed
            }

            captureSession.beginConfiguration()

            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            } else {
                captureSession.commitConfiguration()
                throw QRScannerError.inputFailed
            }

            let metadataOutput = AVCaptureMetadataOutput()

            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            } else {
                captureSession.commitConfiguration()
                throw QRScannerError.outputFailed
            }

            captureSession.commitConfiguration()
            isSessionConfigured = true
        }

        // セッションを開始
        DispatchQueue.global(qos: .userInitiated).async { [captureSession] in
            captureSession.startRunning()
        }
    }

    /// スキャンを停止する
    func stopScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [captureSession] in
            captureSession.stopRunning()
        }
    }

    /// プレビューレイヤーを取得する
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        if let existing = videoPreviewLayer {
            return existing
        }

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        videoPreviewLayer = layer
        return layer
    }

    /// スキャン結果をクリアする
    func clearScannedCode() {
        scannedCode = nil
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRScanner: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {

            Task { @MainActor in
                self.scannedCode = stringValue
                self.stopScanning()
            }
        }
    }
}

// MARK: - Error

enum QRScannerError: Error, LocalizedError {
    case notAuthorized
    case noCameraAvailable
    case inputFailed
    case outputFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "カメラの権限が許可されていません"
        case .noCameraAvailable:
            return "カメラが利用できません"
        case .inputFailed:
            return "カメラの入力設定に失敗しました"
        case .outputFailed:
            return "カメラの出力設定に失敗しました"
        }
    }
}
