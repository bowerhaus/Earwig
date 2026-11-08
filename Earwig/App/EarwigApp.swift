import SwiftData
import SwiftUI

@main
struct EarwigApp: App {
    private let container = ModelContainerFactory.persistent()
    /// Renders the start step of the open script, held in memory while the app runs.
    @State private var renderer = ScriptRenderer.live()
    /// The splash shows once per process, on a cold launch: set false when it finishes and never
    /// reset, and not tied to the scene phase, so a return from the background or an unlock
    /// mid-take shows nothing (plan 007, decision 7).
    @State private var showsSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ScriptsView()
                if showsSplash {
                    SplashView { showsSplash = false }
                }
            }
            .environment(renderer)
            .tint(EarwigTheme.accent)
            .preferredColorScheme(EarwigTheme.scheme)
        }
        .modelContainer(container)
    }
}
