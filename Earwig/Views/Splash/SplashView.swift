import SwiftUI

/// Seconds for the launch splash (plan 007, decision 7), tuned on the phone.
enum SplashTiming {
    /// The mark and the name fade in from the launch screen's plain sky blue.
    static let appear = 0.25
    static let hold = 0.4
    /// The whole overlay fades out onto the Scripts screen.
    static let fade = 0.3

    static var total: Double { appear + hold + fade }
}

/// The cold-launch splash: the launch screen's sky blue, over which the mark and the name fade
/// in and out, all in under a second. `EarwigApp` shows it once per process and never again, so
/// a return from the background or an unlock mid-take shows nothing. Fades are not motion, so
/// Reduce Motion changes nothing.
struct SplashView: View {
    /// The mark image in the asset catalogue, drawn by `scripts/app_icon/make_app_icon.py` for a
    /// 160 pt box; the same mark is the app icon and the logo.
    static let markImage = "EarwigMark"
    /// The colour set the launch screen shows, pinned to `EarwigTheme.background` by a test.
    static let launchBackground = "LaunchBackground"
    static let markSize: CGFloat = 150

    /// Called once the fade-out is over, so the app can drop the overlay.
    let onFinished: () -> Void

    @State private var shown = false
    @State private var fading = false

    var body: some View {
        ZStack {
            EarwigTheme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(Self.markImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.markSize, height: Self.markSize)
                Text("Earwig")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(EarwigTheme.text)
            }
            .opacity(shown ? 1 : 0)
        }
        .opacity(fading ? 0 : 1)
        // Swallows taps for its second, so a tap on launch cannot land on the list beneath.
        .contentShape(Rectangle())
        .onTapGesture {}
        .accessibilityHidden(true)
        .task { await play() }
    }

    private func play() async {
        withAnimation(.easeOut(duration: SplashTiming.appear)) { shown = true }
        // A cancelled sleep means the view is already gone; finishing then is harmless.
        try? await Task.sleep(for: .seconds(SplashTiming.appear + SplashTiming.hold))
        withAnimation(.easeOut(duration: SplashTiming.fade)) { fading = true }
        try? await Task.sleep(for: .seconds(SplashTiming.fade))
        onFinished()
    }
}

#Preview {
    SplashView {}
}
