@testable import Earwig
import SwiftUI
import Testing
import UIKit

/// The launch screen is the theme's sky blue alone, so the splash can fade in from it with no
/// handover to see, and the mark it shows is in the catalogue (plan 007, decisions 5 to 7).
@MainActor
struct LaunchSplashTests {

    private var launchScreen: [String: Any] {
        Bundle.main.object(forInfoDictionaryKey: "UILaunchScreen") as? [String: Any] ?? [:]
    }

    @Test func theLaunchScreenIsTheBackgroundAlone() {
        #expect(launchScreen["UIColorName"] as? String == SplashView.launchBackground)
        #expect(launchScreen["UIImageName"] == nil, "a picture would hand over to the overlay with a jerk")
    }

    @Test func theMarkIsInTheCatalogue() {
        #expect(UIImage(named: SplashView.markImage) != nil)
    }

    /// The colour set exists only because the launch screen needs one; views take the theme's.
    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func theLaunchBackgroundIsTheThemes(style: UIUserInterfaceStyle) throws {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let launch = try #require(UIColor(named: SplashView.launchBackground)).resolvedColor(with: traits)
        let theme = UIColor(EarwigTheme.background).resolvedColor(with: traits)
        #expect(components(launch) == components(theme))
    }

    /// Half as long again as plan 007's 0.95 s (Andy, plan 014), and still brief.
    @Test func theSplashIsBrief() {
        #expect(abs(SplashTiming.total - 1.425) < 1e-9)
    }

    /// Red, green, blue and alpha in 8-bit steps, so float noise doesn't count.
    private func components(_ colour: UIColor) -> [Int] {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        colour.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha].map { Int(($0 * 255).rounded()) }
    }
}
