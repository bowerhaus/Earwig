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

/// What a take is followed by, judged by ear in stage 5 (plan 005, decision 11): the lead, the
/// pacing and the start mode, kept in `UserDefaults` and read into `FollowSettings` for a take.
struct TakeSettings {
    static let leadRange = 2...6
    /// Andy's pick by ear in device check 6 of plan 005, over 3. The engine's own default stays
    /// 3, which its tests and simulated takes are written for.
    static let defaultLead = 5
    static let leadKey = "lead"
    static let pacingKey = "pacing"
    static let voiceSpeedKey = "voiceSpeed"
    /// The voice's speeds to choose from, as multiples of its rendering.
    static let voiceSpeeds = [0.8, 0.85, 0.9, 0.95, 1.0]
    /// Andy, device check 6 of plan 005: the voice at 1.0x is "still too quick" with phrase-gated
    /// pacing; after takes at 0.85x and 0.9x he settled on 0.95x, with lead 5 and hybrid (#14).
    static let defaultVoiceSpeed = 0.95
    /// Andy's pick in device check 6: tones only. The engine's own default stays the slate with
    /// its reply, which its tests are written for.
    static let defaultStartMode = StartMode.tonesOnly
    static let startModeKey = "startMode"

    let defaults: UserDefaults

    /// Words the voice runs ahead; `defaultLead` unless set, kept within `leadRange`.
    var lead: Int {
        get {
            guard defaults.object(forKey: Self.leadKey) != nil else { return Self.defaultLead }
            return min(max(defaults.integer(forKey: Self.leadKey), Self.leadRange.lowerBound), Self.leadRange.upperBound)
        }
        nonmutating set { defaults.set(min(max(newValue, Self.leadRange.lowerBound), Self.leadRange.upperBound), forKey: Self.leadKey) }
    }

    var pacing: PacingMode {
        get { defaults.string(forKey: Self.pacingKey).flatMap(PacingMode.init) ?? FollowSettings().pacing }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.pacingKey) }
    }

    var startMode: StartMode {
        get { defaults.string(forKey: Self.startModeKey).flatMap(StartMode.init) ?? Self.defaultStartMode }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.startModeKey) }
    }

    /// The voice's base speed: the player plays the engine's speeds times this (#14). One of
    /// `voiceSpeeds`, `defaultVoiceSpeed` unless set.
    var voiceSpeed: Double {
        get {
            guard defaults.object(forKey: Self.voiceSpeedKey) != nil else { return Self.defaultVoiceSpeed }
            let stored = defaults.double(forKey: Self.voiceSpeedKey)
            return Self.voiceSpeeds.min { abs($0 - stored) < abs($1 - stored) } ?? Self.defaultVoiceSpeed
        }
        nonmutating set { defaults.set(newValue, forKey: Self.voiceSpeedKey) }
    }

    /// The engine's settings for a take: the defaults with these three.
    var followSettings: FollowSettings {
        var settings = FollowSettings()
        settings.lead = lead
        settings.pacing = pacing
        settings.start = startMode
        return settings
    }

    /// The lead in seconds at the default speaking rate, for the Settings screen.
    static func seconds(forLead lead: Int) -> TimeInterval {
        Double(lead) / FollowSettings().defaultRate
    }
}

extension PacingMode {
    var label: String {
        switch self {
        case .hybrid: "Hybrid"
        case .phraseGated: "Phrase-gated"
        }
    }
}

extension StartMode {
    var label: String {
        switch self {
        case .slateWithReply: "Slate with a reply"
        case .slate: "Slate alone"
        case .tonesOnly: "Tones only"
        }
    }
}

/// Settings kept in `UserDefaults` (PRD §6.1), until the Settings screen of stage 7 gathers them.
enum AppSettings {
    /// The lead, pacing and start mode.
    static var take: TakeSettings { TakeSettings(defaults: .standard) }

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
