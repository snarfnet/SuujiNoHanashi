import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    var adUnitID: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        guard AdRuntime.allowsAds else { return }
        guard !context.coordinator.didLoad else { return }

        DispatchQueue.main.async {
            guard AdRuntime.allowsAds else { return }
            guard !context.coordinator.didLoad else { return }

            let rootViewController = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .compactMap { $0.keyWindow }
                .first?.rootViewController
                ?? uiView.window?.rootViewController

            guard let rootViewController else { return }
            uiView.rootViewController = rootViewController
            uiView.load(Request())
            context.coordinator.didLoad = true
        }
    }

    final class Coordinator {
        var didLoad = false
    }
}
