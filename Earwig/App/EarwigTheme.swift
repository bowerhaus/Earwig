import SwiftUI

/// One look for the whole app, the same whatever the phone's light or dark setting (plan 002,
/// decision 11). `scheme` is the system scheme that suits it, so system controls read on it.
struct EarwigPalette {
    let name: String
    let scheme: ColorScheme
    let background: Color
    /// Rows and cards.
    let surface: Color
    let text: Color
    let secondaryText: Color
    /// The voice's phrase, the selected step, buttons.
    let accent: Color
    /// Directions and cues: never spoken by the presenter.
    let cue: Color
    let warning: Color
    let good: Color
    let caution: Color
}

extension EarwigPalette {
    /// Warm paper and ink, with a brick accent and a teal for cues.
    static let paper = EarwigPalette(
        name: "Paper",
        scheme: .light,
        background: Color(hex: 0xF3EDE2),
        surface: Color(hex: 0xFBF8F2),
        text: Color(hex: 0x1E1B18),
        secondaryText: Color(hex: 0x6B6359),
        accent: Color(hex: 0xB4441F),
        cue: Color(hex: 0x2F6D78),
        warning: Color(hex: 0xC0262D),
        good: Color(hex: 0x2E7D4F),
        caution: Color(hex: 0xB86E00)
    )

    /// The earwig's own colours: dark shell brown with a copper accent and sage cues.
    static let copper = EarwigPalette(
        name: "Copper",
        scheme: .dark,
        background: Color(hex: 0x17120E),
        surface: Color(hex: 0x261D17),
        text: Color(hex: 0xF5EDE3),
        secondaryText: Color(hex: 0xA89A8B),
        accent: Color(hex: 0xE08A3C),
        cue: Color(hex: 0x93B09F),
        warning: Color(hex: 0xFF5C4D),
        good: Color(hex: 0x7CC98B),
        caution: Color(hex: 0xF2B544)
    )

    /// Deep harbour blue with a signal yellow, like a studio prompter.
    static let harbour = EarwigPalette(
        name: "Harbour",
        scheme: .dark,
        background: Color(hex: 0x0D1B2A),
        surface: Color(hex: 0x16283B),
        text: Color(hex: 0xF2F5F8),
        secondaryText: Color(hex: 0x9AAABB),
        accent: Color(hex: 0xFFC845),
        cue: Color(hex: 0x7FB8D0),
        warning: Color(hex: 0xFF6B5E),
        good: Color(hex: 0x6FD39A),
        caution: Color(hex: 0xFF9F43)
    )

    static let candidates = [paper, copper, harbour]

    /// The chosen palette. While Andy picks one, the `-EarwigPalette <name>` launch argument
    /// shows another.
    static let current: EarwigPalette = {
        let name = UserDefaults.standard.string(forKey: "EarwigPalette")?.lowercased()
        return candidates.first { $0.name.lowercased() == name } ?? .copper
    }()
}

/// Every colour Earwig uses (PRD §10). Views never define their own.
enum EarwigTheme {
    static let palette = EarwigPalette.current

    static var scheme: ColorScheme { palette.scheme }
    static var background: Color { palette.background }
    static var surface: Color { palette.surface }
    static var text: Color { palette.text }
    static var secondaryText: Color { palette.secondaryText }
    static var accent: Color { palette.accent }
    static var cue: Color { palette.cue }
    /// Something is wrong for a take: hands-free profile, wrong mic, failure.
    static var warning: Color { palette.warning }
    static var good: Color { palette.good }
    static var caution: Color { palette.caution }
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
