import AVFoundation

/// A synthesis voice as Earwig chooses between them: plain values, so the choice is tested on
/// made-up lists.
struct VoiceInfo: Equatable, Sendable {
    enum Quality: Int, Comparable, Sendable {
        case compact = 1, enhanced, premium

        static func < (a: Quality, b: Quality) -> Bool { a.rawValue < b.rawValue }

        var label: String {
            switch self {
            case .compact: "Compact"
            case .enhanced: "Enhanced"
            case .premium: "Premium"
            }
        }
    }

    enum Gender: Sendable {
        case female, male, unspecified
    }

    var identifier: String
    var name: String
    /// BCP 47, as `en-GB`.
    var language: String
    var quality: Quality
    var gender: Gender
    /// The presenter's own voice, made in Settings, Accessibility, Personal Voice.
    var isPersonal = false

    init(identifier: String, name: String, language: String, quality: Quality, gender: Gender, isPersonal: Bool = false) {
        self.identifier = identifier
        self.name = name
        self.language = language
        self.quality = quality
        self.gender = gender
        self.isPersonal = isPersonal
    }

    init(_ voice: AVSpeechSynthesisVoice) {
        identifier = voice.identifier
        name = Self.baseName(voice.name)
        language = voice.language
        quality = switch voice.quality {
        case .premium: .premium
        case .enhanced: .enhanced
        default: .compact
        }
        gender = switch voice.gender {
        case .female: .female
        case .male: .male
        default: .unspecified
        }
        isPersonal = voice.voiceTraits.contains(.isPersonalVoice)
    }

    /// "Stephanie (Enhanced)", or "Andy (Personal Voice)".
    var displayName: String { "\(name) (\(isPersonal ? "Personal Voice" : quality.label))" }

    /// The name without a trailing "(Enhanced)" or "(Premium)": iOS 27 puts the quality in a
    /// voice's name ("Stephanie (Enhanced)"), where iOS 26 did not.
    static func baseName(_ name: String) -> String {
        guard name.hasSuffix(")"), let open = name.range(of: " (", options: .backwards) else { return name }
        let base = name[..<open.lowerBound].trimmingCharacters(in: .whitespaces)
        return base.isEmpty ? name : base
    }
}

/// The presenter's and the cue voice until Settings chooses them (plan 004, decision 5).
struct VoiceChoice: Equatable, Sendable {
    var presenter: VoiceInfo
    var cue: VoiceInfo
    /// Whether the presenter's voice is the one wanted (Stephanie), not a fallback.
    var presenterIsPreferred: Bool
}

enum VoiceCatalogue {
    /// Plan 001's pick: Stephanie (Enhanced, en-GB).
    static let preferredName = "Stephanie"
    static let preferredLanguage = "en-GB"
    /// The base speaking rate, an `AVSpeechUtterance` rate (PRD §4.2).
    static let rate: Float = 0.5
    /// Where a voice is downloaded, for a message.
    static let downloadHint = "Download voices in Settings › Accessibility › Read & Speak › Voices › English."

    /// The installed voices Earwig would use, no novelty voices. Personal Voices are listed only
    /// once the app is allowed to use them.
    static func installed() -> [VoiceInfo] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { !$0.voiceTraits.contains(.isNoveltyVoice) }
            .map(VoiceInfo.init)
    }

    /// The choice from the installed voices, or `nil` when there is no English voice. A presenter
    /// voice picked by hand (`presenterID`) is used while it is installed; else the default. A cue
    /// voice picked by hand (`cueID`, plan 012) likewise; else Automatic, `cue(from:presenter:)`.
    /// A Personal Voice is never the default and never the cue voice.
    static func choose(from voices: [VoiceInfo], presenterID: String? = nil, cueID: String? = nil) -> VoiceChoice? {
        let picked = presenterID.flatMap { id in voices.first { $0.identifier == id } }
        let standard = voices.filter { !$0.isPersonal }
        guard let presenter = picked ?? presenter(from: standard) else { return nil }
        let pickedCue = cueID.flatMap { id in standard.first { $0.identifier == id } }
        let cue = pickedCue ?? cue(from: standard, presenter: presenter) ?? presenter
        return VoiceChoice(presenter: presenter, cue: cue, presenterIsPreferred: picked != nil || isPreferred(presenter))
    }

    /// The choice from the installed voices with the voices picked in Settings.
    static func chosen(from voices: [VoiceInfo] = installed()) -> VoiceChoice? {
        choose(from: voices, presenterID: AppSettings.presenterVoiceID, cueID: AppSettings.cueVoiceID)
    }

    /// The cue voices worth offering beside Automatic: English voices of Enhanced quality or
    /// better, British first, never a Personal Voice (plan 012, decision 2).
    static func cueOptions(from voices: [VoiceInfo]) -> [VoiceInfo] {
        presenterOptions(from: voices).filter { !$0.isPersonal }
    }

    /// The presenter voices worth offering: Personal Voices, then English voices of Enhanced
    /// quality or better, British first.
    static func presenterOptions(from voices: [VoiceInfo]) -> [VoiceInfo] {
        let personal = voices.filter(\.isPersonal)
        let good = voices.filter { !$0.isPersonal && isEnglish($0) && $0.quality >= .enhanced }
            .sorted { ($0.language == preferredLanguage ? 0 : 1, $0.name) < ($1.language == preferredLanguage ? 0 : 1, $1.name) }
        return personal + good
    }

    /// Stephanie (Enhanced or better, en-GB); else the best en-GB voice; else the best English.
    static func presenter(from voices: [VoiceInfo]) -> VoiceInfo? {
        if let stephanie = best(voices.filter(isPreferred)) { return stephanie }
        return best(voices.filter { $0.language == preferredLanguage }) ?? best(voices.filter(isEnglish))
    }

    /// The best en-GB voice that is not the presenter's, the other gender first so a cue is
    /// clearly not a line; else the same from any English voice.
    static func cue(from voices: [VoiceInfo], presenter: VoiceInfo) -> VoiceInfo? {
        let others = voices.filter { $0.identifier != presenter.identifier }
        func pick(_ candidates: [VoiceInfo]) -> VoiceInfo? {
            let otherGender = candidates.filter { $0.gender != presenter.gender && $0.gender != .unspecified && presenter.gender != .unspecified }
            return best(otherGender) ?? best(candidates)
        }
        return pick(others.filter { $0.language == preferredLanguage }) ?? pick(others.filter(isEnglish))
    }

    private static func isPreferred(_ voice: VoiceInfo) -> Bool {
        voice.name == preferredName && voice.language == preferredLanguage && voice.quality >= .enhanced
    }

    private static func isEnglish(_ voice: VoiceInfo) -> Bool {
        voice.language.hasPrefix("en")
    }

    /// The highest quality; among equals, by name so the choice is stable.
    private static func best(_ voices: [VoiceInfo]) -> VoiceInfo? {
        voices.max { a, b in (a.quality, b.name) < (b.quality, a.name) }
    }
}
