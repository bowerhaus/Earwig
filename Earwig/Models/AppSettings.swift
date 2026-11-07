import Foundation

/// How a `[direction]` inside a line reaches the presenter during a take (device check 2 of
/// plan 004: a spoken direction leaves its own length as a gap in the take).
enum InlineDirections: String, CaseIterable, Sendable {
    /// A low chime at that point, ringing on as the voice carries on.
    case chime
    /// Read in the cue voice at that point; the take waits for it.
    case spoken

    var label: String {
        switch self {
        case .chime: "Chime"
        case .spoken: "Spoken"
        }
    }
}

/// Settings kept in `UserDefaults` (PRD §6.1), until the Settings screen of stage 7 gathers them.
enum AppSettings {
    static let inlineDirectionsKey = "inlineDirections"
    static let presenterVoiceKey = "presenterVoice"

    /// The presenter's voice picked by hand, by identifier; `nil` for the default (Stephanie).
    static var presenterVoiceID: String? {
        get { UserDefaults.standard.string(forKey: presenterVoiceKey) }
        set { UserDefaults.standard.set(newValue, forKey: presenterVoiceKey) }
    }

    static var inlineDirections: InlineDirections {
        get { UserDefaults.standard.string(forKey: inlineDirectionsKey).flatMap(InlineDirections.init) ?? .chime }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: inlineDirectionsKey) }
    }
}
