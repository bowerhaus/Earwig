import AVFoundation
import Observation
import SwiftData

/// The Script screen (PRD §8.2): the start step and its rendering, the cues switch, Listen, a
/// new version, delete.
@MainActor
@Observable
final class ScriptDetailViewModel {
    let script: Script
    var error: String?
    /// Set after Paste new version, for a short confirmation.
    var notice: String?
    /// The play-through behind Listen, while its sheet is up.
    var preview: StepPreview?
    /// The take on the Prompt screen, while it is up.
    var take: TakeHost?

    init(script: Script) {
        self.script = script
    }

    /// Rebuilds the steps if they came from an older parser, then renders the start step.
    func appeared(in context: ModelContext, renderer: ScriptRenderer) {
        if ScriptImporter(context: context).refreshIfStale(script) { try? context.save() }
        renderStartStep(with: renderer)
    }

    func select(step index: Int, in context: ModelContext, renderer: ScriptRenderer) {
        guard index != script.lastStep else { return }
        script.lastStep = index
        try? context.save()
        renderStartStep(with: renderer)
    }

    func setCues(_ on: Bool, in context: ModelContext) {
        script.cuesOn = on
        try? context.save()
    }

    /// The step a take starts from, if the script has it.
    var startStep: Step? {
        let steps = script.orderedSteps
        return steps.indices.contains(script.lastStep) ? steps[script.lastStep] : steps.first
    }

    /// Renders the start step's missing phrases (plan 004, decision 2).
    func renderStartStep(with renderer: ScriptRenderer) {
        guard let step = startStep else { return }
        renderer.prepare(script: script.persistentModelID, step: script.lastStep, phrases: step.phraseList)
    }

    /// The rendering state for this script's start step.
    func renderState(_ renderer: ScriptRenderer) -> ScriptRenderer.State {
        guard renderer.target == AnyHashable(script.persistentModelID) else { return .idle }
        return switch renderer.state {
        case .rendering(let step, _, _), .ready(let step), .failed(let step, _):
            step == script.lastStep ? renderer.state : .idle
        case .idle:
            .idle
        }
    }

    /// Opens Listen on the start step, with the next take's slate (no take is recorded).
    func listen(with renderer: ScriptRenderer) {
        guard let step = startStep else { return }
        let take = script.nextTakeNumber(forStep: script.lastStep)
        preview = StepPreview(
            phraseList: step.phraseList,
            renderer: renderer,
            slateText: Slate.text(for: step, take: take, cuesOn: script.cuesOn),
            cuesOn: script.cuesOn,
            inline: AppSettings.inlineDirections
        )
    }

    /// Opens the Prompt screen on a take of the start step, numbered after the step's last take
    /// (plan 005, decisions 3 and 8). The take is recorded once its slate plays.
    /// `mode` is the take's, from the setting unless given (Next Take keeps the last take's).
    /// Screen Only needs nothing rendered: the engine follows the presenter alone (plan 008,
    /// decision 7).
    func startTake(with renderer: ScriptRenderer, in context: ModelContext, mode given: TakeMode? = nil, recording chosen: TakeRecordingMode? = nil) {
        // One take at a time: a second Start (the card's and the row's) does not orphan one.
        guard take == nil, let step = startStep else { return }
        let mode = given ?? AppSettings.take.mode
        let stepIndex = script.lastStep
        // With cues off, inline directions are not played (PRD §4.2): the take has no cue phrases.
        let all = step.phraseList
        let keep = all.phrases.indices.filter { script.cuesOn || all.phrases[$0].kind == .spoken }
        let phraseList = PhraseList(parserVersion: all.parserVersion, phrases: keep.map { all.phrases[$0] })
        let number = script.nextTakeNumber(forStep: stepIndex)
        let built: (script: FollowScript, audio: TakeAudio)
        do {
            if mode.voiced {
                guard let allRendered = renderer.rendered(all) else {
                    error = "The step is not rendered yet."
                    return
                }
                built = try TakeAudio.build(phraseList: phraseList, rendered: keep.map { allRendered[$0] }, inline: AppSettings.inlineDirections)
            } else {
                built = try TakeAudio.voiceless(phraseList: phraseList)
            }
        } catch {
            self.error = error.localizedDescription
            return
        }
        let slateText = Slate.text(for: step, take: number, cuesOn: script.cuesOn)
        var setup = TakeSetup(
            stepNumber: step.number,
            stepTitle: step.title,
            take: number,
            phraseList: phraseList,
            script: built.script,
            audio: built.audio,
            slateText: slateText,
            slateWords: Slate.replyWords(for: step, take: number),
            settings: AppSettings.take.followSettings,
            contextWords: TakeSetup.contextWords(phraseList: phraseList, slateText: slateText),
            voiceSpeed: AppSettings.take.voiceSpeed,
            mode: mode,
            lightsVoice: AppSettings.take.lightsVoice
        )
        let session = AudioSessionManager()
        session.onEvent = { Log.event($0) }
        let output = AudioEngineHost()
        output.onEvent = { Log.event($0) }
        let listener = Listener(audio: output)
        listener.onEvent = { Log.event($0) }
        var heard: HeardSource = listener
        #if DEBUG
        // `-EarwigNoListen YES`: a take that hears nothing, for the simulator, which cannot
        // transcribe en-GB.
        if UserDefaults.standard.bool(forKey: "EarwigNoListen") { heard = SilentHeardSource() }
        // `-EarwigReads YES`: a take that hears the step read at 2.5 words a second, so the
        // simulator shows the screen following (plan 008).
        if UserDefaults.standard.bool(forKey: "EarwigReads") { heard = ReadingHeardSource(phraseList: phraseList) }
        // `-EarwigListenGivesUp YES`: listening gives up ten seconds into the take, to see the
        // take stop and say why on the phone (plan 006, decision 7).
        if UserDefaults.standard.bool(forKey: "EarwigListenGivesUp") { heard = GivingUpHeardSource(heard) }
        #endif
        let recording = takeRecording(stepNumber: step.number, take: number, chosen: chosen, output: output)
        setup.chosenRecording = recording.chosen
        setup.recording = recording.mode
        setup.videoQuality = AppSettings.take.videoQuality
        setup.cameraBehindText = AppSettings.take.cameraBehindText
        setup.recordingNote = recording.note
        take = TakeHost(
            setup: setup,
            session: session,
            output: output,
            heard: heard,
            recorder: ScriptTakeRecorder(script: script, stepIndex: stepIndex, number: number, context: context, recording: recording.place),
            capture: recording.capture,
            renderSlate: { text in try await renderer.renderCue(text).buffer }
        )
    }

    /// The number the start step's next take will have.
    var nextTakeNumber: Int { script.nextTakeNumber(forStep: script.lastStep) }

    /// What a take records, from Settings or as chosen (plan 010, decisions 1 and 6): sound alone
    /// when there is too little room for video, nothing when no file can be made.
    private struct TakeRecordingChoice {
        var chosen: TakeRecordingMode
        var mode: TakeRecordingMode
        var note: String?
        var capture: TakeCapture?
        var place: ScriptTakeRecorder.Recording?
    }

    private func takeRecording(stepNumber: Int, take number: Int, chosen given: TakeRecordingMode?, output: AudioEngineHost) -> TakeRecordingChoice {
        let chosen = given ?? AppSettings.take.recording
        var choice = TakeRecordingChoice(chosen: chosen, mode: chosen)
        #if DEBUG
        // `-EarwigRecordVideo YES`: film the take whatever Settings says (plan 010, device check 1).
        if UserDefaults.standard.bool(forKey: "EarwigRecordVideo") { choice.mode = .video }
        #endif
        let store = RecordingStore.standard
        if choice.mode == .video, let free = store.freeSpace(), free < RecordingStore.minimumFreeForVideo {
            choice.mode = .sound
            choice.note = "Less than 1 GB free, so only the sound was recorded."
        }
        guard choice.mode != .off else { return choice }
        let video = choice.mode == .video
        do {
            let url = try store.url(scriptTitle: script.title, step: stepNumber, take: number, video: video)
            choice.capture = TakeRecording(url: url, video: video, quality: AppSettings.take.videoQuality, audio: output)
            choice.place = store.relativePath(of: url).map { ScriptTakeRecorder.Recording(path: $0, keep: AppSettings.take.keepsRecordings) }
        } catch {
            Log.event("recording: no file: \(error.localizedDescription)")
            choice.mode = .off
            choice.note = "The take could not be recorded: \(error.localizedDescription)"
        }
        return choice
    }

    /// Closes the Prompt screen; a take still running is stopped and recorded so.
    func endTake() {
        take?.end()
        take = nil
    }

    /// The same step again, as the next take.
    func nextTake(with renderer: ScriptRenderer, in context: ModelContext) {
        let mode = take?.setup.mode
        let recording = take?.chosenRecording
        take?.end()
        take = nil
        startTake(with: renderer, in: context, mode: mode, recording: recording)
    }

    /// The presenter voices to pick from, and whether Personal Voice may still be asked for.
    var presenterOptions: [VoiceInfo] { VoiceCatalogue.presenterOptions(from: VoiceCatalogue.installed()) }
    var canAskForPersonalVoice: Bool { AVSpeechSynthesizer.personalVoiceAuthorizationStatus == .notDetermined }

    /// Uses a presenter voice picked by hand and renders the start step in it.
    func usePresenter(_ identifier: String, renderer: ScriptRenderer) {
        AppSettings.presenterVoiceID = identifier
        renderer.use(VoiceCatalogue.choose(from: VoiceCatalogue.installed(), presenterID: identifier))
        renderStartStep(with: renderer)
    }

    /// Asks once to use the presenter's Personal Voice; it is then listed among the voices.
    func askForPersonalVoice() async {
        let status = await AVSpeechSynthesizer.requestPersonalVoiceAuthorization()
        Log.event("personal voice: \(status == .authorized ? "authorised" : "not authorised (\(status.rawValue))")")
        personalVoiceAsked += 1
    }

    /// Bumped when Personal Voice has been asked for, so the menu lists the voices again.
    var personalVoiceAsked = 0

    func pasteNewVersion(_ text: String?, in context: ModelContext, renderer: ScriptRenderer) {
        guard let text, !text.isEmpty else {
            error = ScriptImporter.ImportError.noSteps.localizedDescription
            return
        }
        do {
            let result = try ScriptImporter(context: context).replace(script, with: text)
            try context.save()
            notice = result.outcome == .unchanged ? "That is the version already here." : "Updated to the new version."
            renderStartStep(with: renderer)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(in context: ModelContext) {
        context.delete(script)
        try? context.save()
    }
}

#if DEBUG
/// Hears nothing: a take in the simulator runs its slate, tones and voice for the layout.
@MainActor
final class SilentHeardSource: HeardSource {
    var onHeard: ((FollowEvent, TimeInterval) -> Void)?
    var onRestart: (() -> Void)?
    var onGaveUp: ((String) -> Void)?
    var downloadProgress: Double? { nil }
    func listen(contextWords: [String]) async -> String? { nil }
    func stopListening() async {}
}

/// Reads the step aloud as heard words, for the simulator, which cannot transcribe en-GB: four
/// seconds after listening starts (past the tones), the step's words one every 0.4 s as one
/// growing interim block, settled by a final at each sentence end (plan 008, `-EarwigReads`).
@MainActor
final class ReadingHeardSource: HeardSource {
    var onHeard: ((FollowEvent, TimeInterval) -> Void)?
    var onRestart: (() -> Void)?
    var onGaveUp: ((String) -> Void)?
    var downloadProgress: Double? { nil }
    private let words: [String]
    private var reading: Task<Void, Never>?

    init(phraseList: PhraseList) {
        words = phraseList.spoken.flatMap { $0.phrase.tokens.filter { $0.word != nil }.map(\.text) }
    }

    func listen(contextWords: [String]) async -> String? {
        reading = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self else { return }
            var block: [(text: String, start: TimeInterval)] = []
            for word in words {
                guard !Task.isCancelled else { return }
                block.append((word, HostClock.now - 0.4))
                onHeard?(.interim(block.map(\.text).joined(separator: " ")), HostClock.now)
                if PhraseSplitter.endsSentence(word) {
                    try? await Task.sleep(for: .seconds(0.5))
                    onHeard?(.final(block.map { FinalWord(text: $0.text, start: $0.start) }), HostClock.now)
                    block = []
                }
                try? await Task.sleep(for: .seconds(0.4))
            }
        }
        return nil
    }

    func stopListening() async {
        reading?.cancel()
        reading = nil
    }
}

/// Listens as the source it wraps, then gives up ten seconds after listening starts, as the
/// `Listener` does after two failures in ten seconds: it stops listening and says so.
@MainActor
final class GivingUpHeardSource: HeardSource {
    private let inner: HeardSource
    private var timer: Task<Void, Never>?
    /// The wrapped source's own give-up is passed on too (review C3).
    var onGaveUp: ((String) -> Void)? {
        didSet { inner.onGaveUp = onGaveUp }
    }

    init(_ inner: HeardSource) { self.inner = inner }

    var onHeard: ((FollowEvent, TimeInterval) -> Void)? {
        get { inner.onHeard }
        set { inner.onHeard = newValue }
    }

    var onRestart: (() -> Void)? {
        get { inner.onRestart }
        set { inner.onRestart = newValue }
    }

    var downloadProgress: Double? { inner.downloadProgress }

    func listen(contextWords: [String]) async -> String? {
        if let problem = await inner.listen(contextWords: contextWords) { return problem }
        timer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, let self else { return }
            Log.event("debug: listening gives up (-EarwigListenGivesUp)")
            await inner.stopListening()
            onGaveUp?("listening stopped (Debug: -EarwigListenGivesUp)")
        }
        return nil
    }

    func stopListening() async {
        timer?.cancel()
        timer = nil
        await inner.stopListening()
    }
}
#endif
