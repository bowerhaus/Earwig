import Foundation

/// What the Prompt screen shows in Ear mode (PRD §8.3; plan 005, decision 7), worked out from the
/// take host's phase, the engine's snapshot and the route. Plain values in, text and states out,
/// so it is tested without audio.
struct PromptViewModel: Equatable {
    /// A route icon's state (decision 9).
    enum RouteState: Equatable {
        /// Not judged: the session is only set up while a take runs, and before and after it
        /// the phone reports no input.
        case unknown
        case good
        /// On the phone's speaker: the take runs, but the mic will hear the voice.
        case caution
        case wrong
    }

    /// One token of the text shown: a word or a bracketed cue, whether the voice is saying it,
    /// and whether the voice has yet to give it.
    struct Token: Equatable {
        var text: String
        var isVoiceWord = false
        var isAhead = false
        var isCue = false
    }

    let phase: TakeHost.Phase
    let snapshot: FollowSnapshot
    let route: AudioRoute
    let setup: TakeSetup.Summary
    let downloadProgress: Double?
    /// Why the take stopped, when listening gave up (#18).
    let stopReason: String?

    init(phase: TakeHost.Phase, snapshot: FollowSnapshot, route: AudioRoute, setup: TakeSetup.Summary,
         downloadProgress: Double? = nil, stopReason: String? = nil) {
        self.phase = phase
        self.snapshot = snapshot
        self.route = route
        self.setup = setup
        self.downloadProgress = downloadProgress
        self.stopReason = stopReason
    }

    @MainActor
    init(host: TakeHost) {
        self.init(phase: host.phase, snapshot: host.snapshot, route: host.route, setup: host.setup.summary,
                  downloadProgress: host.downloadProgress, stopReason: host.stopReason)
    }

    // MARK: - Top

    var stepText: String { setup.title.isEmpty ? "Step \(setup.number)" : "Step \(setup.number) · \(setup.title)" }

    var takeText: String { "Take \(setup.take)" }

    var earpiece: RouteState {
        guard phase == .running else { return .unknown }
        if route.isHandsFree { return .wrong }
        return route.isSpeaker ? .caution : .good
    }

    var mic: RouteState {
        guard phase == .running else { return .unknown }
        return route.inputIsBuiltInMic && !route.isHandsFree ? .good : .wrong
    }

    /// Said under the route icons when one is not good.
    var routeNote: String? {
        guard phase == .running else { return nil }
        if route.isHandsFree { return "The earpiece is in hands-free mode: reconnect it." }
        if mic == .wrong { return "Not listening on the iPhone's mic." }
        if earpiece == .caution { return "Speaker: the mic will hear the voice." }
        return nil
    }

    // MARK: - Middle

    var status: String {
        switch phase {
        case .gettingReady: return "Getting ready"
        case .failed: return "Can't start"
        case .finished: return "Finished"
        case .running:
            switch snapshot.status {
            case .idle: return "Getting ready"
            case .slate: return "Slate"
            case .tones: return "Tones"
            case .speaking: return "Speaking"
            case .waiting: return "Waiting"
            case .lost: return "Lost"
            case .held: return "Held"
            case .finished: return "Finished"
            }
        }
    }

    /// What to do or what is happening, under the status word.
    var instruction: String? {
        switch phase {
        case .gettingReady:
            if let downloadProgress { return String(format: "Downloading speech for listening: %.0f%%", downloadProgress * 100) }
            return "Listening and the slate"
        case .failed(let message):
            return message
        case .finished(let outcome):
            if outcome == .completed { return "Completed" }
            return stopReason.map { "Stopped: \($0)" } ?? "Stopped"
        case .running:
            switch snapshot.status {
            case .slate:
                switch setup.start {
                case .slateWithReply: return "Say the slate, or tap"
                case .slate: return "Say the slate to the camera"
                case .tonesOnly: return nil
                }
            case .lost: return "Say a line of the script"
            case .held: return "Release Hold to go on"
            default: return nil
            }
        }
    }

    /// Whether a tap in the middle starts the take from the slate.
    var tapStarts: Bool { phase == .running && snapshot.status == .slate }

    /// While the voice speaks, its phrase with the word it is saying marked. While it waits, is
    /// lost or held, the whole sentence it stopped in, so the presenter can see where to start
    /// again (device check 3); the part the voice has not given yet is marked ahead.
    var phrase: [Token] {
        guard phase == .running, let index = snapshot.voicePhrase, setup.phraseList.phrases.indices.contains(index),
              [.speaking, .waiting, .lost, .held].contains(snapshot.status) else { return [] }
        let shown = snapshot.status == .speaking ? index...index : setup.phraseList.sentence(containing: index)
        return shown.flatMap { tokens(of: $0, ahead: $0 > index) }
    }

    private func tokens(of index: Int, ahead: Bool) -> [Token] {
        let stepPhrase = setup.phraseList.phrases[index]
        if stepPhrase.kind == .cue { return [Token(text: "[\(stepPhrase.phrase.text)]", isAhead: ahead, isCue: true)] }
        var word = setup.firstWord.indices.contains(index) ? setup.firstWord[index] : 0
        return stepPhrase.phrase.tokens.map { token in
            guard token.word != nil else { return Token(text: token.text, isAhead: ahead) }
            defer { word += 1 }
            return Token(text: token.text, isVoiceWord: word == snapshot.voiceWord && snapshot.status == .speaking, isAhead: ahead)
        }
    }

    /// The device check's numbers (decision 7): lead error, speed, the measured delay and rate.
    var diagnostics: String? {
        guard phase == .running, [.speaking, .waiting, .lost, .held].contains(snapshot.status) else { return nil }
        let error = snapshot.error.map { String(format: "%+.1f", $0) } ?? "–"
        return String(format: "lead error %@ · speed %.2f× · delay %.2f s · rate %.1f w/s", error, snapshot.speed, snapshot.delay, snapshot.rate)
    }

    // MARK: - Bottom

    private var following: Bool { phase == .running && [.speaking, .waiting, .lost, .held].contains(snapshot.status) }

    var holdEnabled: Bool { following }
    var isHeld: Bool { phase == .running && snapshot.status == .held }
    var backEnabled: Bool { following }
    var forwardEnabled: Bool { following }
    var restartEnabled: Bool { phase == .running && snapshot.status != .idle }
    var stopEnabled: Bool { phase == .running }

    /// While getting ready the take can only be called off.
    var canCancel: Bool { phase == .gettingReady }

    /// Next Take and Done replace the controls once the take is over or could not start.
    var isOver: Bool {
        switch phase {
        case .finished, .failed: true
        default: false
        }
    }

    var canTakeAgain: Bool {
        if case .finished = phase { return true }
        return false
    }
}

extension TakeSetup {
    /// What the Prompt screen needs of a take's setup, comparable.
    struct Summary: Equatable {
        var number: Int
        var title: String
        var take: Int
        var start: StartMode
        var phraseList: PhraseList
        var firstWord: [Int]
    }

    var summary: Summary {
        Summary(number: stepNumber, title: stepTitle, take: take, start: settings.start, phraseList: phraseList, firstWord: script.firstWord)
    }
}
