import Foundation

/// What the Prompt screen shows (PRD §8.3; plan 005, decision 7), worked out from the
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

    /// A word of the scrolling text with how it is shown (plan 008, decision 4).
    struct ScreenToken: Equatable {
        var word: ScreenWord
        /// In the voice's phrase, and the word the voice is saying.
        var inVoicePhrase = false
        var isVoiceWord = false
        /// Before following starts, every word is dimmed.
        var isWaiting = false

        /// Heard already: before `heard`, the word after the last one heard, as the screen shows
        /// it. Dimmed, the only mark of the presenter's place: a block on one word showed the
        /// recogniser's second of delay as a word marker always behind (Andy, device check 2).
        func isHeard(before heard: Int?) -> Bool {
            guard let heard, let index = word.word, !isWaiting else { return false }
            return index < heard
        }
    }

    let phase: TakeHost.Phase
    let snapshot: FollowSnapshot
    let route: AudioRoute
    let setup: TakeSetup.Summary
    let downloadProgress: Double?
    /// Why the take stopped, when listening gave up (#18).
    let stopReason: String?
    /// The take's recording (plan 010): what it is, since when, what went wrong, and once the
    /// take is let go, its file.
    let recording: Recording

    struct Recording: Equatable {
        var since: TimeInterval?
        var note: String?
        var result: RecordingResult?
        var readyToGo = false
        var isTornDown = false
    }

    init(phase: TakeHost.Phase, snapshot: FollowSnapshot, route: AudioRoute, setup: TakeSetup.Summary,
         downloadProgress: Double? = nil, stopReason: String? = nil, recording: Recording = Recording()) {
        self.phase = phase
        self.snapshot = snapshot
        self.route = route
        self.setup = setup
        self.downloadProgress = downloadProgress
        self.stopReason = stopReason
        self.recording = recording
    }

    @MainActor
    init(host: TakeHost) {
        self.init(phase: host.phase, snapshot: host.snapshot, route: host.route, setup: host.summaryForScreen,
                  downloadProgress: host.downloadProgress, stopReason: host.stopReason,
                  recording: Recording(since: host.recordingSince, note: host.recordingNote, result: host.recording,
                                       readyToGo: host.readyToGo, isTornDown: host.isTornDown))
    }

    // MARK: - Recording

    /// A video take frames on the camera's preview until Start (decision 4).
    var isFraming: Bool { setup.recording == .video && phase == .gettingReady }

    /// The dot and the time while the take is recorded (decision 5).
    var showsRecordingDot: Bool { recording.since != nil && phase == .running }

    /// Video stopped early: the dot shows sound only.
    var recordingSoundOnly: Bool { setup.recording == .sound || recording.note?.hasPrefix("Video stopped") == true }

    /// The take was recorded and its file is still being finished.
    var isSavingRecording: Bool {
        guard case .finished = phase, setup.recording != .off else { return false }
        return !recording.isTornDown
    }

    /// Play Video, when there is a picture to play (decision 7).
    var canPlayVideo: Bool { recording.result?.video == true && (recording.result?.videoStoppedAt ?? 1) > 0 }

    /// Play Sound or Play Back: there is a file.
    var canPlaySound: Bool { recording.result != nil }

    /// Said on Finished about the recording, when it is not what was chosen.
    var recordingText: String? {
        guard isOver else { return nil }
        if let note = recording.note { return note }
        guard case .finished = phase, setup.recording != .off, recording.isTornDown, recording.result == nil else { return nil }
        return "Nothing was recorded."
    }

    // MARK: - Top

    var stepText: String { setup.title.isEmpty ? "Step \(setup.number)" : "Step \(setup.number) · \(setup.title)" }

    var takeText: String { "Take \(setup.take)" }

    /// Not judged with no voice: nothing plays but the slate and the tones, so the speaker or no
    /// earpiece is fine (plan 008, decision 10).
    var earpiece: RouteState {
        guard phase == .running, setup.mode.voiced else { return .unknown }
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
        if route.isHandsFree, setup.mode.voiced { return "The earpiece is in hands-free mode: reconnect it." }
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
            case .reading: return "Reading"
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

    // MARK: - The scrolling text

    /// Where the presenter is, for the scroll: the engine's place for the screen.
    /// While following, never before the first word.
    var place: Double { following ? max(snapshot.presenterPlace, 0) : -1 }

    /// The step's words as the screen shows them now.
    var screenTokens: [ScreenToken] {
        let voicing = following && setup.mode.voiced && setup.lightsVoice
        return setup.screenWords.map { word in
            var token = ScreenToken(word: word, isWaiting: !following)
            guard following, !word.isCue else { return token }
            if voicing, word.phrase == snapshot.voicePhrase {
                token.inVoicePhrase = true
                token.isVoiceWord = snapshot.status == .speaking && word.word != nil && word.word == snapshot.voiceWord
            }
            return token
        }
    }

    /// The device check's numbers (decision 7): lead error, speed, the measured delay and rate.
    var diagnostics: String? {
        guard following else { return nil }
        let error = snapshot.error.map { String(format: "%+.1f", $0) } ?? "–"
        return String(format: "lead error %@ · speed %.2f× · delay %.2f s · rate %.1f w/s", error, snapshot.speed, snapshot.delay, snapshot.rate)
    }

    // MARK: - Bottom

    private var following: Bool { phase == .running && [.speaking, .waiting, .reading, .lost, .held].contains(snapshot.status) }

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

    /// Not while the recording's file is being finished: the next take would want the mic.
    var canTakeAgain: Bool {
        if case .finished = phase { return !isSavingRecording }
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
        /// The step's words for the screen, built once per take.
        var screenWords: [ScreenWord]
        var mode = TakeMode.voice
        var lightsVoice = false
        var recording = TakeRecordingMode.off
    }

    var summary: Summary {
        Summary(number: stepNumber, title: stepTitle, take: take, start: settings.start,
                screenWords: ScreenText.words(phraseList: phraseList, firstWord: script.firstWord), mode: mode, lightsVoice: lightsVoice,
                recording: recording)
    }
}
