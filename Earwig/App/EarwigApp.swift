import SwiftData
import SwiftUI

@main
struct EarwigApp: App {
    private let container = ModelContainerFactory.persistent()

    var body: some Scene {
        WindowGroup {
            ScriptsView()
                .tint(EarwigTheme.accent)
                .preferredColorScheme(EarwigTheme.scheme)
        }
        .modelContainer(container)
    }
}
