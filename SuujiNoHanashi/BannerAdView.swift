import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    var adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        guard uiView.rootViewController == nil else { return }
        DispatchQueue.main.async {
            let rootVC = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .compactMap { $0.keyWindow }
                .first?.rootViewController
                ?? uiView.window?.rootViewController
            guard let rootVC else { return }
            uiView.rootViewController = rootVC
            uiView.load(Request())
        }
    }
}
