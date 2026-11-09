import AVFoundation
import Observation

/// Where heard words come from: the `Listener`, or a fake in tests (plan 005, decision 3).
@MainActor
protocol HeardSource: AnyObject {
    /// Each result as the engine hears it, with the host time it arrived.
    var onHeard: ((FollowEvent, TimeInterval) -> Void)? { get set }
    /// Listening restarted itself and the interim block was lost.
    var onRestart: (() -> Void)? { get set }
    /// Listening stopped mid-take and will not restart itself, with why (#18).
    var onGaveUp: ((String) -> Void)? { get set }
    /// The speech assets' download, 0 to 1, while getting ready; `nil` when not downloading.
    var downloadProgress: Double? { get }
    /// Starts listening with the take's words as contextual strings. `nil` once listening,
    /// otherwise why not.
    func listen(contextWords: [String]) async -> String?
    func stopListening() async
}

extension Listener: HeardSource {
    var downloadProgress: Double? {
        if case .downloading(let fraction) = state { return fraction }
        return nil
    }

    func listen(contextWords: [String]) async -> String? {
        await start(contextWords: contextWords, fastResults: true)
        switch state {
        case .listening: return nil
        case .failed(let message): return message
        default: return "Listening did not start."
        }
    }

    func stopListening() async { await stop() }
}

/// The audio session as a take uses it: `AudioSessionManager`, or a fake in tests.
@MainActor
protocol TakeSession: AnyObject {
    var route: AudioRoute { get }
    var onInterruption: ((Bool) -> Void)? { get set }
    var onDeviceLost: (() -> Void)? { get set }
    func requestMicrophone() async -> Bool
    func configure() throws
    func deactivate()
}

extension AudioSessionManager: TakeSession {}

/// The audio engine as a take uses it: `AudioEngineHost`, or a fake in tests.
@MainActor
protocol TakeOutput: PlayerOutput {
    /// The engine restarted itself mid-take; what was playing was cut off.
    var onRestarted: (() -> Void)? { get set }
    func start() throws
    func stop()
}

extension AudioEngineHost: TakeOutput {}

/// Where a take is recorded: the script's takes in SwiftData, or a fake in tests.
@MainActor
protocol TakeRecorder: AnyObject {
    /// The slate is about to play: the take exists from now, as stopped (decision 6).
    func started(at date: Date)
    func finished(duration: TimeInterval, outcome: TakeOutcome)
    /// The take's recording is finished; `nil` when it came to nothing (plan 010).
    func recordingFinished(_ result: RecordingResult?)
}

extension TakeRecorder {
    func recordingFinished(_ result: RecordingResult?) {}
}

/// Everything one take is built from, gathered on the Script screen.
struct TakeSetup {
    var stepNumber: Int
    var stepTitle: String
    var take: Int
    var phraseList: PhraseList
    var script: FollowScript
    /// The step's audio; the slate is rendered while getting ready.
    var audio: TakeAudio
    var slateText: String
    var slateWords: [ScriptWord]
    var settings: FollowSettings
    var contextWords: [String]
    /// The voice's base speed (#14).
    var voiceSpeed = 1.0
    /// With the voice or the screen only, fixed for the take (plan 008, decision 6).
    var mode = TakeMode.voice
    /// Whether, with the voice, its phrase is lit in the scrolling text.
    var lightsVoice = false
    /// Whether the take is recorded, and how: what will be recorded, after any fallback (plan 010).
    var recording = TakeRecordingMode.off
    /// What was chosen, before any fallback, for Next Take to keep.
    var chosenRecording = TakeRecordingMode.off
    var videoQuality = VideoQuality.hd1080
    /// Whether a video take shows the camera behind the scrolling text.
    var cameraBehindText = false
    /// Said on Finished when the recording is not what was chosen (too little room for video).
    var recordingNote: String?

    /// A video take waits on the camera's preview for Start (plan 010, decision 4).
    var waitsForGo: Bool { recording == .video }

    /// The recording on the take summary's line (decision 10).
    var recordingLogName: String {
        switch recording {
        case .off: "off"
        case .sound: "sound"
        case .video: "video \(videoQuality.label)"
        }
    }

    /// The engine's settings: voiced exactly when the take has the ear, so the engine and the
    /// host cannot disagree about it (review C3).
    var engineSettings: FollowSettings {
        var engine = settings
        engine.voiced = mode.voiced
        return engine
    }

    /// The step's words and the slate's, each once, as written, for the analyser's context.
    static func contextWords(phraseList: PhraseList, slateText: String) -> [String] {
        let tokens = phraseList.spoken.flatMap { $0.phrase.tokens.map(\.text) } + slateText.split(whereSeparator: \.isWhitespace).map(String.init)
        var seen = Set<String>()
        return tokens
            .map { $0.trimmingCharacters(in: .punctuationCharacters.union(.symbols)) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}

/// One take, from Start to its end (plan 005, decisions 2 to 6, 9, 10, 13): it gets the session,
/// the audio engine, listening and the slate ready in that order, then runs the follow engine,
/// ticking it twenty times a second with the player's progress, passing it what is heard and
/// what the player reports, and passing its commands to the player. The take is recorded when
/// the slate plays. Its parts sit behind protocols so the whole loop runs in tests on a clock
/// the test controls.
@MainActor
@Observable
final class TakeHost: Identifiable {
    enum Phase: Equatable {
        case gettingReady
        case running
        case finished(FollowOutcome)
        case failed(String)
    }

    static let tickInterval: TimeInterval = 0.05

    let setup: TakeSetup
    /// What the Prompt screen needs of the setup, built once (its screen words most of all).
    @ObservationIgnored private(set) lazy var summaryForScreen = setup.summary
    private(set) var phase: Phase = .gettingReady
    private(set) var snapshot = FollowSnapshot()
    /// Why the take stopped, when it was not the presenter or a call: listening gave up (#18).
    private(set) var stopReason: String?
    /// The take's recording once its file is finished; `nil` when not recorded (plan 010).
    private(set) var recording: RecordingResult?
    /// What went wrong with the recording, for Finished: the video stopping early, or a failure.
    private(set) var recordingNote: String?
    /// Host time at which recording started, for the time shown while recording.
    private(set) var recordingSince: TimeInterval?
    /// A video take is ready and waits on the camera's preview for `go()` (plan 010, decision 4).
    private(set) var readyToGo = false
    /// Everything is let go, the recording's file finished: Next Take may start another.
    private(set) var isTornDown = false
    /// The camera is running, so the framing preview can show (review C5).
    private(set) var cameraReady = false
    /// The video stopped early; the sound carries on (decision 9).
    private(set) var videoStopped = false
    /// The camera, for the framing preview.
    var camera: CameraCapture? { capture?.camera }
    /// The recording chosen for this take, which Next Take keeps (plan 010, decision 1).
    var chosenRecording: TakeRecordingMode { setup.chosenRecording }

    var route: AudioRoute { session.route }
    var downloadProgress: Double? { heard.downloadProgress }

    @ObservationIgnored private let session: TakeSession
    @ObservationIgnored private let output: TakeOutput
    @ObservationIgnored private let heard: HeardSource
    @ObservationIgnored private let recorder: TakeRecorder
    @ObservationIgnored private let capture: TakeCapture?
    @ObservationIgnored private let renderSlate: (String) async throws -> AVAudioPCMBuffer
    @ObservationIgnored private let clock: () -> TimeInterval
    @ObservationIgnored private let ticks: Bool
    @ObservationIgnored private let log: (String) -> Void

    @ObservationIgnored private var engine: FollowEngine
    @ObservationIgnored private var player: Player?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var summary: TakeSummary
    @ObservationIgnored private var startedAt: TimeInterval?
    /// The engine's clock never goes backwards.
    @ObservationIgnored private var lastTime = -TimeInterval.infinity
    @ObservationIgnored private var ended = false
    @ObservationIgnored private var heldSlate: AVAudioPCMBuffer?

    init(setup: TakeSetup, session: TakeSession, output: TakeOutput, heard: HeardSource, recorder: TakeRecorder,
         capture: TakeCapture? = nil,
         renderSlate: @escaping (String) async throws -> AVAudioPCMBuffer,
         clock: @escaping () -> TimeInterval = { HostClock.now }, ticks: Bool = true, log: @escaping (String) -> Void = Log.event) {
        self.setup = setup
        self.session = session
        self.output = output
        self.heard = heard
        self.recorder = recorder
        self.capture = capture
        self.renderSlate = renderSlate
        self.clock = clock
        self.ticks = ticks
        self.log = log
        recordingNote = setup.recordingNote
        engine = FollowEngine(script: setup.script, settings: setup.engineSettings, slateWords: setup.slateWords)
        summary = TakeSummary(wordCount: setup.script.words.count)
    }

    // MARK: - Getting ready

    /// Gets ready and starts the take; on a failure shows why and records nothing.
    func start() async {
        guard phase == .gettingReady, player == nil, !ended else { return }
        log("take: getting ready, step \(setup.stepNumber) take \(setup.take), lead \(setup.settings.lead), \(setup.settings.pacing.rawValue), voice \(setup.voiceSpeed)x, start \(setup.settings.start.rawValue)")
        guard await session.requestMicrophone() else {
            return await fail("Earwig needs the microphone to follow you. Allow it in Settings › Privacy & Security › Microphone.")
        }
        guard !ended else { return }
        do {
            try session.configure()
            try output.start()
        } catch {
            return await fail("The audio could not start: \(error.localizedDescription)")
        }
        guard await readyListeningAndCamera() else { return }
        // With tones only no slate is played, so none is rendered (review C3).
        var slate: AVAudioPCMBuffer?
        if setup.settings.start != .tonesOnly {
            do {
                slate = try await renderSlate(setup.slateText)
            } catch {
                return await fail("The slate could not be rendered: \(error.localizedDescription)")
            }
            guard !ended else { return await tearDown() }
        }
        guard setup.waitsForGo else { return begin(slate: slate) }
        heldSlate = slate
        readyToGo = true
        log("take: ready; waiting on the preview for Start")
    }

    /// Start on the framing preview: the take begins (plan 010, decision 4).
    func go() {
        guard readyToGo, phase == .gettingReady, !ended else { return }
        readyToGo = false
        let slate = heldSlate
        heldSlate = nil
        begin(slate: slate)
    }

    /// The camera for a video take, first so the preview shows while the rest gets ready
    /// (review C5), then listening; `false` once failed or torn down.
    private func readyListeningAndCamera() async -> Bool {
        if let capture {
            if let problem = await capture.prepare() {
                await fail(problem)
                return false
            }
            cameraReady = true
            guard !ended else {
                await tearDown()
                return false
            }
        }
        if let problem = await heard.listen(contextWords: setup.contextWords) {
            await fail("Listening could not start: \(problem)")
            return false
        }
        guard !ended else {
            await tearDown()
            return false
        }
        return true
    }

    private func begin(slate: AVAudioPCMBuffer?) {
        var audio = setup.audio
        audio.slate = slate
        let player = Player(output: output, audio: audio, baseSpeed: setup.voiceSpeed)
        player.onEvent = { [weak self] in self?.send($0) }
        player.onLog = { [weak self] in self?.log($0) }
        self.player = player
        heard.onHeard = { [weak self] event, at in self?.heard(event, at: at) }
        heard.onRestart = { [weak self] in
            self?.log("take: listening restarted; settling the block")
            self?.send(.final([]))
        }
        heard.onGaveUp = { [weak self] in self?.listeningGaveUp($0) }
        session.onInterruption = { [weak self] began in
            guard began else { return }
            self?.log("take: interrupted; stopping")
            self?.send(.stop)
        }
        session.onDeviceLost = { [weak self] in self?.deviceLost() }
        output.onRestarted = { [weak self] in self?.engineRestarted() }

        recorder.started(at: Date())
        startedAt = clock()
        startRecording()
        phase = .running
        log("take: started, \(slate == nil ? "no slate" : "slate “\(setup.slateText)”"), route \(session.route.summary)")
        send(.start)
        if ticks { startTicking() }
    }

    private func fail(_ message: String) async {
        log("take: failed to get ready: \(message)")
        phase = .failed(message)
        await tearDown()
    }

    // MARK: - Running

    /// A manual control or the tap.
    func control(_ event: FollowEvent) {
        guard phase == .running else { return }
        summary.used(event)
        log("take: control \(event)")
        send(event)
    }

    /// Passes the player's progress to the engine and ticks it. Twenty times a second.
    func tick() {
        guard phase == .running else { return }
        if let progress = player?.progress() { send(progress) }
        guard phase == .running else { return }
        let now = time()
        apply(engine.tick(at: now))
        publish(at: now)
    }

    private func heard(_ event: FollowEvent, at time: TimeInterval) {
        switch event {
        case .interim(let text): log("heard interim: \(text)")
        case .final(let words):
            let now = self.time()
            log("heard final: " + words.map { String(format: "%@ (%.2f s)", $0.text, now - $0.start) }.joined(separator: " "))
        default: break
        }
        send(event, at: time)
    }

    private func send(_ event: FollowEvent, at stamp: TimeInterval? = nil) {
        guard phase == .running else { return }
        let now = time(stamp)
        switch event {
        case .voiceProgress, .interim, .final: break
        default: log("event: \(event)")
        }
        apply(engine.handle(event, at: now))
        publish(at: now)
    }

    private func apply(_ commands: [FollowCommand]) {
        for command in commands {
            log("command: \(command)")
            player?.handle(command)
            if case .finished(let outcome) = command { finish(outcome) }
        }
    }

    private func publish(at now: TimeInterval) {
        let next = engine.snapshot
        if next.status != snapshot.status { log("status: \(next.status.rawValue)") }
        if let wait = summary.record(next, at: now) { log(String(format: "waited %.2f s after phrase %d", wait, (snapshot.voicePhrase ?? 0) + 1)) }
        if next != snapshot { snapshot = next }
    }

    private func time(_ stamp: TimeInterval? = nil) -> TimeInterval {
        lastTime = max(lastTime, stamp ?? clock())
        return lastTime
    }

    // MARK: - Route, listening and engine

    /// Listening stopped and will not come back: the take cannot follow, so it stops, saying why
    /// (plan 006, decision 2).
    private func listeningGaveUp(_ reason: String) {
        guard phase == .running else { return }
        log("take: \(reason); stopping")
        stopReason = reason
        send(.stop)
    }

    /// The earpiece went: hold, so the voice is not heard by the room or the mic (decision 9).
    /// With no voice there is nothing to keep from the room, so the take goes on (plan 008).
    private func deviceLost() {
        guard phase == .running else { return }
        log("take: output device lost; route \(session.route.summary)")
        guard setup.mode.voiced, [.speaking, .waiting, .lost].contains(snapshot.status) else { return }
        send(.hold)
    }

    /// The audio engine restarted and cut off what was playing, whose end will never come: the
    /// slate is skipped, the tones played again, and the voice re-anchored by Hold twice.
    private func engineRestarted() {
        guard phase == .running else { return }
        log("take: audio engine restarted mid-take (status \(snapshot.status.rawValue))")
        switch snapshot.status {
        case .slate: send(.tap)
        case .tones: send(.restart)
        case .speaking, .waiting, .lost:
            send(.hold)
            send(.hold)
        default: break
        }
    }

    // MARK: - Recording

    /// Recording starts as the take is recorded, at its slate (plan 010, decision 3).
    private func startRecording() {
        guard let capture else { return }
        capture.onVideoStopped = { [weak self] reason in
            guard let self else { return }
            let at = self.recordingSince.map { self.clock() - $0 } ?? 0
            self.recordingNote = "Video stopped at \(Self.minutesAndSeconds(at)): \(reason)."
            self.videoStopped = true
            self.log("take: video stopped: \(reason)")
        }
        capture.onFailed = { [weak self] reason in
            self?.recordingNote = "Recording stopped: \(reason)."
            // Nothing is being recorded now: the dot goes (review C6).
            self?.recordingSince = nil
            self?.log("take: recording failed: \(reason)")
        }
        let now = clock()
        recordingSince = now
        capture.start(at: now)
    }

    static func minutesAndSeconds(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    // MARK: - The end

    private func finish(_ outcome: FollowOutcome) {
        guard case .running = phase else { return }
        let now = time()
        let duration = now - (startedAt ?? now)
        summary.record(engine.snapshot, at: now)
        snapshot = engine.snapshot
        phase = .finished(outcome)
        recorder.finished(duration: duration, outcome: TakeOutcome(rawValue: outcome.rawValue) ?? .stopped)
        log(summary.line(duration: duration, outcome: outcome, mode: setup.mode, note: stopReason == nil ? nil : "not listening",
                         recording: setup.recordingLogName))
        Task { await tearDown() }
    }

    /// The screen is going: a take still running is stopped and recorded so. Finishing and
    /// failing tear down; getting ready sees `ended` at its next step and tears down there.
    func end() {
        guard !ended else { return }
        if phase == .running { control(.stop) }
        ended = true
        if phase == .gettingReady { log("take: closed while getting ready") }
        // Ready on the preview, getting ready has returned: nothing else will tear down.
        if readyToGo {
            readyToGo = false
            Task { await tearDown() }
        }
    }

    private func tearDown() async {
        if let capture {
            capture.onVideoStopped = nil
            capture.onFailed = nil
            let result = await capture.finish()
            recording = result
            if startedAt != nil { recorder.recordingFinished(result) }
        }
        ticker?.cancel()
        ticker = nil
        player?.stopAll()
        player = nil
        heard.onHeard = nil
        heard.onRestart = nil
        heard.onGaveUp = nil
        session.onInterruption = nil
        session.onDeviceLost = nil
        output.onRestarted = nil
        await heard.stopListening()
        output.stop()
        session.deactivate()
        isTornDown = true
    }

    private func startTicking() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            var last = HostClock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int(Self.tickInterval * 1000)))
                // A tick this late means the main thread was held: said, for the console.
                let now = HostClock.now
                if now - last > 0.5 { self?.log(String(format: "take: main thread held %.2f s", now - last - Self.tickInterval)) }
                last = now
                self?.tick()
            }
        }
    }
}
