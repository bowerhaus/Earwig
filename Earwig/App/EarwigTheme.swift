import SwiftUI

/// Every colour Earwig uses (PRD §10). Views never define their own.
///
/// One look for the whole app, the same whatever the phone's light or dark setting (plan
/// 002, decision 11): a clear sky blue as the ground, mid-blue cards with white text, a
/// buttercup accent for the slate numerals and the voice's phrase, and peach for cues and
/// directions, which the presenter never says. Andy's pick from nine candidates.
enum EarwigTheme {
    /// The system scheme that suits the palette, so system controls read on it.
    static let scheme: ColorScheme = .dark

    static let background = Color(hex: 0x5CB8F3)
    /// Rows and cards.
    static let surface = Color(hex: 0x2B82CC)
    static let text = Color(hex: 0xFFFFFF)
    static let secondaryText = Color(hex: 0xD2E7F8)
    /// The voice's phrase, the start step, the slate numerals, buttons.
    static let accent = Color(hex: 0xFFD24A)
    /// Text on the accent, as on the Start pill.
    static let onAccent = surface
    /// Directions and cues: never spoken by the presenter.
    static let cue = Color(hex: 0xFFD3AE)
    /// Something is wrong for a take: hands-free profile, wrong mic, failure.
    static let warning = Color(hex: 0xFF8A7A)
    static let good = Color(hex: 0x7FE0A4)
    static let caution = Color(hex: 0xFFB454)
}

extension Color {
    /// A colour from a 0xRRGGBB value. For `EarwigTheme` only.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
