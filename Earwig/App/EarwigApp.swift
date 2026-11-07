import SwiftData
import SwiftUI

@main
struct EarwigApp: App {
    private let container = ModelContainerFactory.persistent()
    /// Renders the start step of the open script, held in memory while the app runs.
    @State private var renderer = ScriptRenderer.live()

    var body: some Scene {
        WindowGroup {
            ScriptsView()
                .environment(renderer)
                .tint(EarwigTheme.accent)
                .preferredColorScheme(EarwigTheme.scheme)
        }
        .modelContainer(container)
    }
}
