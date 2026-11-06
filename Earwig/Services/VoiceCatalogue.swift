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

    init(identifier: String, name: String, language: String, quality: Quality, gender: Gender) {
        self.identifier = identifier
        self.name = name
        self.language = language
        self.quality = quality
        self.gender = gender
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
    }

    /// "Stephanie (Enhanced)".
    var displayName: String { "\(name) (\(quality.label))" }

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
    static let downloadHint = "Download voices in Settings › Accessibility › Spoken Content › Voices › English."

    /// The installed voices Earwig would use: no Personal Voice (stage 7) and no novelty voices.
    static func installed() -> [VoiceInfo] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { !$0.voiceTraits.contains(.isPersonalVoice) && !$0.voiceTraits.contains(.isNoveltyVoice) }
            .map(VoiceInfo.init)
    }

    /// The default choice from the installed voices, or `nil` when there is no English voice.
    static func choose(from voices: [VoiceInfo]) -> VoiceChoice? {
        guard let presenter = presenter(from: voices) else { return nil }
        let cue = cue(from: voices, presenter: presenter) ?? presenter
        return VoiceChoice(presenter: presenter, cue: cue, presenterIsPreferred: isPreferred(presenter))
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
