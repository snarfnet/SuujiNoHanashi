import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

@MainActor
final class AdMobStartup: ObservableObject {
    static let shared = AdMobStartup()

    @Published private(set) var isReady = false
    private var isStarting = false

    func start() {
        guard !isReady, !isStarting else { return }
        isStarting = true
        requestTrackingAuthorizationIfNeeded { [weak self] in
            MobileAds.shared.start { _ in
                Task { @MainActor in
                    self?.isReady = true
                    self?.isStarting = false
                }
            }
        }
    }

    private func requestTrackingAuthorizationIfNeeded(_ completion: @escaping () -> Void) {
        guard #available(iOS 14, *), ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            completion()
            return
        }
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}

@main
struct SuujiNoHanashiApp: App {
    @StateObject private var adMobStartup = AdMobStartup.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(adMobStartup)
                .task {
                    adMobStartup.start()
                }
        }
    }
}
