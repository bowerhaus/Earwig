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

/// How a take reaches the presenter (PRD §4.6; plan 008, decision 6): the script always scrolls
/// on the Prompt screen, with the voice reading it into the earpiece or without. Chosen before
/// the take and fixed for it. Andy, after trying them on the phone: Ear alone showed less than
/// the voice with the text, at no gain, so the two left are these.
enum TakeMode: String, CaseIterable, Sendable {
    case voice
    case screen

    /// A mode as saved, including the three of the first build: Ear and Both are the voice.
    init?(stored: String) {
        switch stored {
        case "voice", "ear", "both": self = .voice
        case "screen": self = .screen
        default: return nil
        }
    }

    /// Whether the voice reads the script.
    var voiced: Bool { self == .voice }

    /// The short name, beside its icon on the Script screen.
    var label: String {
        switch self {
        case .voice: "With Voice"
        case .screen: "Screen Only"
        }
    }

    var systemImage: String {
        switch self {
        case .voice: "ear"
        case .screen: "text.alignleft"
        }
    }

    /// The name in the take summary's line.
    var logName: String { rawValue }
}

/// Whether a take is recorded, and how (plan 010, decision 1). Chosen before the take, fixed
/// for it, kept by Next Take.
enum TakeRecordingMode: String, CaseIterable, Sendable {
    case off
    case sound
    case video

    var label: String {
        switch self {
        case .off: "Off"
        case .sound: "Sound"
        case .video: "Video"
        }
    }

    var systemImage: String {
        switch self {
        case .off: "circle.slash"
        case .sound: "waveform"
        case .video: "video"
        }
    }
}

/// A video take's size, at 30 frames a second (plan 010, decision 8): 1080p for checking a
/// performance, 4K for a take meant for use.
enum VideoQuality: String, CaseIterable, Sendable {
    case hd1080
    case uhd4K

    var label: String {
        switch self {
        case .hd1080: "1080p"
        case .uhd4K: "4K"
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
    static let modeKey = "takeMode"
    /// The voice, as before Screen mode, for the beach (plan 008, decision 6).
    static let defaultMode = TakeMode.voice
    static let lightsVoiceKey = "lightsVoicePhrase"
    static let textSizeKey = "textSize"
    /// The Prompt screen's text size in points (plan 008, decision 8).
    static let textSizeRange = 24.0...72.0
    static let defaultTextSize = 40.0
    static let recordingKey = "recording"
    static let videoQualityKey = "videoQuality"
    static let keepsRecordingsKey = "keepsRecordings"
    static let cameraBehindTextKey = "cameraBehindText"
    /// The camera behind the text during a video take, on unless set (Andy, check 3).
    static let defaultCameraBehindText = true
    static let textOverCameraKey = "textOverCamera"
    /// How bright the scrolling text is over the camera, as an opacity (Andy, check 4b).
    static let textOverCameraRange = 0.1...1.0
    static let defaultTextOverCamera = 0.35

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

    var mode: TakeMode {
        get { defaults.string(forKey: Self.modeKey).flatMap(TakeMode.init(stored:)) ?? Self.defaultMode }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.modeKey) }
    }

    /// Whether, with the voice, its phrase is lit in the scrolling text. Off unless set: Andy,
    /// trying both on the mount (device check 3 of plan 008).
    var lightsVoice: Bool {
        get { defaults.bool(forKey: Self.lightsVoiceKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.lightsVoiceKey) }
    }

    /// Whether a take is recorded, and how; off unless set (plan 010, decision 1).
    var recording: TakeRecordingMode {
        get { defaults.string(forKey: Self.recordingKey).flatMap(TakeRecordingMode.init) ?? .off }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.recordingKey) }
    }

    /// A video take's size; 1080p unless set (decision 8).
    var videoQuality: VideoQuality {
        get { defaults.string(forKey: Self.videoQualityKey).flatMap(VideoQuality.init) ?? .hd1080 }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.videoQualityKey) }
    }

    /// Whether every recording is kept; off unless set, when only the last is (decision 6).
    var keepsRecordings: Bool {
        get { defaults.bool(forKey: Self.keepsRecordingsKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.keepsRecordingsKey) }
    }

    /// Whether a video take shows the camera behind the scrolling text; on unless set.
    var cameraBehindText: Bool {
        get { defaults.object(forKey: Self.cameraBehindTextKey) as? Bool ?? Self.defaultCameraBehindText }
        nonmutating set { defaults.set(newValue, forKey: Self.cameraBehindTextKey) }
    }

    /// The scrolling text's opacity over the camera, kept within `textOverCameraRange`.
    var textOverCamera: Double {
        get {
            guard defaults.object(forKey: Self.textOverCameraKey) != nil else { return Self.defaultTextOverCamera }
            return Self.clampTextOverCamera(defaults.double(forKey: Self.textOverCameraKey))
        }
        nonmutating set { defaults.set(Self.clampTextOverCamera(newValue), forKey: Self.textOverCameraKey) }
    }

    static func clampTextOverCamera(_ opacity: Double) -> Double {
        min(max(opacity, textOverCameraRange.lowerBound), textOverCameraRange.upperBound)
    }

    /// The Prompt screen's text size, kept within `textSizeRange`.
    var textSize: Double {
        get {
            guard defaults.object(forKey: Self.textSizeKey) != nil else { return Self.defaultTextSize }
            return Self.clampTextSize(defaults.double(forKey: Self.textSizeKey))
        }
        nonmutating set { defaults.set(Self.clampTextSize(newValue), forKey: Self.textSizeKey) }
    }

    static func clampTextSize(_ size: Double) -> Double {
        min(max(size, textSizeRange.lowerBound), textSizeRange.upperBound)
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

    /// The engine's settings for a take: the defaults with these three. Whether it is voiced
    /// comes from the take's mode (`TakeSetup.engineSettings`).
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

/// Settings kept in `UserDefaults` (PRD §6.1) that are not the take's.
enum AppSettings {
    /// The lead, pacing and start mode.
    static var take: TakeSettings { TakeSettings(defaults: .standard) }

    static let inlineDirectionsKey = "inlineDirections"
    static let presenterVoiceKey = "presenterVoice"
    static let cueVoiceKey = "cueVoice"
    static let showsTakeDetailsKey = "showsTakeDetails"

    /// The presenter's voice picked by hand, by identifier; `nil` for the default (Stephanie).
    static var presenterVoiceID: String? {
        get { UserDefaults.standard.string(forKey: presenterVoiceKey) }
        set { UserDefaults.standard.set(newValue, forKey: presenterVoiceKey) }
    }

    /// The cue voice picked by hand, by identifier; `nil` for Automatic (plan 012, decision 2).
    static var cueVoiceID: String? {
        get { UserDefaults.standard.string(forKey: cueVoiceKey) }
        set { UserDefaults.standard.set(newValue, forKey: cueVoiceKey) }
    }

    /// Whether a take shows the engine's line under its status; off unless set (#36).
    static var showsTakeDetails: Bool {
        get { UserDefaults.standard.bool(forKey: showsTakeDetailsKey) }
        set { UserDefaults.standard.set(newValue, forKey: showsTakeDetailsKey) }
    }

    static var inlineDirections: InlineDirections {
        get { UserDefaults.standard.string(forKey: inlineDirectionsKey).flatMap(InlineDirections.init) ?? .chime }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: inlineDirectionsKey) }
    }
}
