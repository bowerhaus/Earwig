import SwiftUI

/// Every colour Earwig uses (PRD §10). Views never define their own.
enum EarwigTheme {
    static let accent = Color.accentColor
    /// Something is wrong for a take: hands-free profile, wrong mic, failure.
    static let warning = Color.red
    static let good = Color.green
    static let caution = Color.orange
    /// Cues, directions and secondary detail.
    static let muted = Color.secondary
}
