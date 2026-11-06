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
    /// Text on the accent, as on the Start pill: white on a light palette's accent, the
    /// card colour on a dark one's.
    var onAccent: Color { scheme == .light ? .white : surface }
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

    /// Harbour blue as the ground, not a tint of black, with a signal yellow.
    static let harbour = EarwigPalette(
        name: "Harbour",
        scheme: .dark,
        background: Color(hex: 0x0F2F55),
        surface: Color(hex: 0x163F70),
        text: Color(hex: 0xF2F5F8),
        secondaryText: Color(hex: 0xA9BBD0),
        accent: Color(hex: 0xFFC845),
        cue: Color(hex: 0x8CD3EA),
        warning: Color(hex: 0xFF6B5E),
        good: Color(hex: 0x6FD39A),
        caution: Color(hex: 0xFF9F43)
    )

    /// Saturated cobalt all over, like a swatch card, with a buttercup accent.
    static let cobalt = EarwigPalette(
        name: "Cobalt",
        scheme: .dark,
        background: Color(hex: 0x1F3FB8),
        surface: Color(hex: 0x17309A),
        text: Color(hex: 0xFFFFFF),
        secondaryText: Color(hex: 0xC2CCF5),
        accent: Color(hex: 0xFFD24A),
        cue: Color(hex: 0xA8DBFF),
        warning: Color(hex: 0xFF8A7A),
        good: Color(hex: 0x7FE0A4),
        caution: Color(hex: 0xFFB454)
    )

    /// Bottle green, the colour of the cliff path, with amber and sea-glass cues.
    static let bottle = EarwigPalette(
        name: "Bottle",
        scheme: .dark,
        background: Color(hex: 0x0E3B31),
        surface: Color(hex: 0x0A2E27),
        text: Color(hex: 0xF1F6F2),
        secondaryText: Color(hex: 0xA3C4B6),
        accent: Color(hex: 0xFFB347),
        cue: Color(hex: 0x9FD9CF),
        warning: Color(hex: 0xFF6F61),
        good: Color(hex: 0x8BE0A4),
        caution: Color(hex: 0xFFC857)
    )

    /// A clear sky blue as the ground with white cards on it, deep blue slates, clay cues.
    static let sky = EarwigPalette(
        name: "Sky",
        scheme: .light,
        background: Color(hex: 0x5CB8F3),
        surface: Color(hex: 0xFFFFFF),
        text: Color(hex: 0x14222F),
        secondaryText: Color(hex: 0x5B7083),
        accent: Color(hex: 0x1468C0),
        cue: Color(hex: 0xB8601A),
        warning: Color(hex: 0xC8262E),
        good: Color(hex: 0x2B8A4E),
        caution: Color(hex: 0xB86E00)
    )

    /// Sky with pale blue cards instead of white.
    static let skyTint = EarwigPalette(
        name: "SkyTint",
        scheme: .light,
        background: Color(hex: 0x5CB8F3),
        surface: Color(hex: 0xD6ECFC),
        text: Color(hex: 0x14222F),
        secondaryText: Color(hex: 0x4F6578),
        accent: Color(hex: 0x1468C0),
        cue: Color(hex: 0xB8601A),
        warning: Color(hex: 0xC8262E),
        good: Color(hex: 0x2B8A4E),
        caution: Color(hex: 0xB86E00)
    )

    /// Sky with deeper blue cards and white text: no white surfaces at all.
    static let skyDeep = EarwigPalette(
        name: "SkyDeep",
        scheme: .dark,
        background: Color(hex: 0x5CB8F3),
        surface: Color(hex: 0x1F6FB8),
        text: Color(hex: 0xFFFFFF),
        secondaryText: Color(hex: 0xC6E0F5),
        accent: Color(hex: 0xFFD24A),
        cue: Color(hex: 0xFFC9A0),
        warning: Color(hex: 0xFF8A7A),
        good: Color(hex: 0x7FE0A4),
        caution: Color(hex: 0xFFB454)
    )

    /// Sky with mid-blue cards: between the pale and the deep.
    static let skyMid = EarwigPalette(
        name: "SkyMid",
        scheme: .dark,
        background: Color(hex: 0x5CB8F3),
        surface: Color(hex: 0x2B82CC),
        text: Color(hex: 0xFFFFFF),
        secondaryText: Color(hex: 0xD2E7F8),
        accent: Color(hex: 0xFFD24A),
        cue: Color(hex: 0xFFD3AE),
        warning: Color(hex: 0xFF8A7A),
        good: Color(hex: 0x7FE0A4),
        caution: Color(hex: 0xFFB454)
    )

    static let candidates = [paper, copper, harbour, cobalt, bottle, sky, skyTint, skyDeep, skyMid]

    /// The chosen palette. While Andy picks one, the `-EarwigPalette <name>` launch argument
    /// shows another.
    static let current: EarwigPalette = {
        let name = UserDefaults.standard.string(forKey: "EarwigPalette")?.lowercased()
        return candidates.first { $0.name.lowercased() == name } ?? .harbour
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
    static var onAccent: Color { palette.onAccent }
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
