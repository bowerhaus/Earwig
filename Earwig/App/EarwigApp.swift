import os
import SwiftData
import SwiftUI
import UIKit

@main
struct EarwigApp: App {
    private let container = ModelContainerFactory.persistent()
    /// Renders the start step of the open script, held in memory while the app runs.
    @State private var renderer = ScriptRenderer.live()
    /// The splash shows once per process, on a cold launch: set false when it finishes and never
    /// reset, and not tied to the scene phase, so a return from the background or an unlock
    /// mid-take shows nothing (plan 007, decision 7).
    @State private var showsSplash = true
    /// The earwig's occasional walks across the screen, shared by the screens (plan 014).
    @State private var visits = EarwigVisits()

    init() {
        // White titles, large and inline, in the light scheme (plan 011, decision 16).
        let white = UIColor(EarwigTheme.text)
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: white]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: white]
        // The samples are in the store before the list first shows (plan 011, decision 3).
        do {
            try SampleSeeder(context: container.mainContext).seed()
        } catch {
            Logger(subsystem: "com.bowerhaus.Earwig", category: "Samples").error("Could not seed the samples: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ScriptsView()
                if showsSplash {
                    SplashView {
                        showsSplash = false
                        visits.ready = true
                    }
                }
            }
            .environment(renderer)
            .environment(visits)
            .tint(EarwigTheme.accent)
            .preferredColorScheme(EarwigTheme.scheme)
        }
        .modelContainer(container)
    }
}
