import SwiftUI
import Translation
import UIKit

// MARK: - Theme
private enum N {
    static let bg    = Color(red: 0.04, green: 0.04, blue: 0.10)
    static let panel = Color(red: 0.09, green: 0.09, blue: 0.16)
    static let card  = Color(red: 0.12, green: 0.12, blue: 0.20)
    static let neon  = Color(red: 0.0,  green: 0.85, blue: 1.0)
    static let neon2 = Color(red: 0.6,  green: 0.2,  blue: 1.0)
    static let text  = Color.white
    static let sub   = Color(white: 0.55)
    static let line  = Color(white: 0.15)
}

// MARK: - ContentView
struct ContentView: View {
    @EnvironmentObject private var adMobStartup: AdMobStartup
    @State private var inputText = ""
    @State private var selectedCategory: NumberCategory = .trivia
    @State private var fact: NumberFact?
    @State private var japaneseText = ""
    @State private var isLoading = false
    @State private var showResult = false
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var englishToTranslate = ""

    var body: some View {
        ZStack {
            N.bg.ignoresSafeArea()
            GridDecoration().ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                if AdRuntime.allowsAds && adMobStartup.isReady {
                    BannerAdView(adUnitID: "ca-app-pub-9404799280370656/7006688247")
                        .frame(height: 50)
                }

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        numberInputSection
                        categorySelector
                        searchButton
                        if showResult, let f = fact {
                            resultCard(f)
                        }
                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .scrollIndicators(.hidden)

                if AdRuntime.allowsAds && adMobStartup.isReady {
                    BannerAdView(adUnitID: "ca-app-pub-9404799280370656/9156769478")
                        .frame(height: 50)
                }
            }
        }
        .preferredColorScheme(.dark)
        .translationTask(translationConfig) { session in
            do {
                let response = try await session.translate(englishToTranslate)
                await MainActor.run {
                    japaneseText = response.targetText
                }
            } catch {
                await MainActor.run {
                    japaneseText = "翻訳できませんでした"
                }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("N U M B E R S")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(6)
                .foregroundColor(N.neon)
            Text("その数字のお話")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(N.text)
            Text("あなたの気になる数字を入れてみよう")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(N.sub)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Number Input
    private var numberInputSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(N.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(inputText.isEmpty ? N.line : N.neon.opacity(0.7), lineWidth: inputText.isEmpty ? 1 : 1.5)
                )
                .shadow(color: inputText.isEmpty ? .clear : N.neon.opacity(0.2), radius: 12)

            HStack(spacing: 12) {
                Image(systemName: "number")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(inputText.isEmpty ? N.sub : N.neon)
                    .frame(width: 28)

                TextField("数字を入力…", text: $inputText)
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundColor(N.text)
                    .keyboardType(.numberPad)
                    .tint(N.neon)

                if !inputText.isEmpty {
                    Button { inputText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(N.sub)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
    }

    // MARK: - Category Selector
    private var categorySelector: some View {
        HStack(spacing: 10) {
            ForEach(NumberCategory.allCases) { cat in
                Button { selectedCategory = cat } label: {
                    VStack(spacing: 5) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 18, weight: .bold))
                        Text(cat.label)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(selectedCategory == cat ? .black : N.sub)
                    .background(selectedCategory == cat ? N.neon : N.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selectedCategory == cat ? .clear : N.line, lineWidth: 1)
                    )
                    .shadow(color: selectedCategory == cat ? N.neon.opacity(0.35) : .clear, radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Search Button
    private var searchButton: some View {
        Button {
            guard let num = Int(inputText) else { return }
            Task { await loadFact(number: num) }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(canSearch ? N.neon : N.panel)
                    .shadow(color: canSearch ? N.neon.opacity(0.4) : .clear, radius: 16, y: 6)
                    .frame(height: 56)

                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView().tint(.black)
                        Text("調査中…")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .black))
                        Text("調べる")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                    }
                    .foregroundColor(canSearch ? .black : N.sub)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!canSearch || isLoading)
    }

    private var canSearch: Bool { Int(inputText) != nil }

    // MARK: - Load Fact
    private func loadFact(number: Int) async {
        isLoading = true
        withAnimation(.easeOut(duration: 0.2)) { showResult = false }
        do {
            let f = try await fetchNumberFact(number: number, category: selectedCategory)
            await MainActor.run {
                fact = f
                japaneseText = ""
                englishToTranslate = f.english
                translationConfig = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "en"),
                    target: Locale.Language(identifier: "ja")
                )
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showResult = true }
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    // MARK: - Result Card
    private func resultCard(_ f: NumberFact) -> some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [N.neon2.opacity(0.6), N.neon.opacity(0.3)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                VStack(spacing: 4) {
                    Text("\(f.number)")
                        .font(.system(size: 72, weight: .black, design: .monospaced))
                        .foregroundColor(N.text)
                        .shadow(color: N.neon.opacity(0.5), radius: 20)
                    Text(f.category.label)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundColor(N.neon.opacity(0.9))
                }
                .padding(.vertical, 28)
            }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("English", systemImage: "globe")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .foregroundColor(N.neon.opacity(0.8))
                    Text(f.english)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(N.text.opacity(0.9))
                        .lineSpacing(4)
                }

                Divider().background(N.line)

                VStack(alignment: .leading, spacing: 6) {
                    Label("日本語", systemImage: "textformat")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .foregroundColor(N.neon2.opacity(0.9))
                    if japaneseText.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView().tint(N.neon2)
                            Text("翻訳中…")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(N.sub)
                        }
                    } else {
                        Text(japaneseText)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(N.text.opacity(0.9))
                            .lineSpacing(5)
                    }
                }
            }
            .padding(20)
            .background(N.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(N.line, lineWidth: 1)
        )
        .shadow(color: N.neon.opacity(0.1), radius: 20, y: 8)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }
}

// MARK: - Grid Decoration
private struct GridDecoration: View {
    var body: some View {
        Canvas { (ctx: inout GraphicsContext, size: CGSize) in
            let spacing: CGFloat = 40
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
            var y: CGFloat = 0
            while y <= size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
            ctx.stroke(path, with: .color(Color.white.opacity(0.03)), lineWidth: 0.5)
        }
    }
}
