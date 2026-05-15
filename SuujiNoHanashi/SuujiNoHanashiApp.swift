import SwiftUI
import GoogleMobileAds

@MainActor
final class AdMobStartup: ObservableObject {
    static let shared = AdMobStartup()

    @Published private(set) var isReady = false
    private var isStarting = false

    func start() {
        guard AdRuntime.allowsAds else { return }
        guard !isReady, !isStarting else { return }
        isStarting = true

        MobileAds.shared.start { [weak self] _ in
            Task { @MainActor in
                guard AdRuntime.allowsAds else {
                    self?.isReady = false
                    self?.isStarting = false
                    return
                }
                self?.isReady = true
                self?.isStarting = false
            }
        }
    }
}

@main
struct SuujiNoHanashiApp: App {
    @StateObject private var adMobStartup = AdMobStartup.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(adMobStartup)
                .onChange(of: scenePhase) {
                    guard scenePhase == .active else { return }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        adMobStartup.start()
                    }
                }
        }
    }
}
