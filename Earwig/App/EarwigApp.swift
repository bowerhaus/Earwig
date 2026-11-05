import SwiftUI

@main
struct EarwigApp: App {
    var body: some Scene {
        WindowGroup {
            // The Scripts screen arrives in stage 2 (PRD §12).
            Text("Earwig")
                .font(.largeTitle.bold())
                .foregroundStyle(EarwigTheme.accent)
        }
    }
}
