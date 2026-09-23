import SwiftUI
import SwiftData
import UIKit

// AppDelegate でキーボードをプレロードする
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("[AppDelegate] Preloading keyboard...")

        // ダミーの UITextField を作成してキーボードをプレロード
        // これにより、実際のTextFieldで初回キーボード表示が速くなる
        DispatchQueue.main.async {
            guard let windowScene = application.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }
            let lagFreeField = UITextField()
            window.addSubview(lagFreeField)
            lagFreeField.becomeFirstResponder()
            lagFreeField.resignFirstResponder()
            lagFreeField.removeFromSuperview()
            print("[AppDelegate] Keyboard preloaded")
        }

        return true
    }
}

@main
struct MeilogApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showingSplash = true
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: EncounterEntity.self)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .modelContainer(modelContainer)
                    .opacity(showingSplash ? 0 : 1)

                if showingSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSplash = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }
}
