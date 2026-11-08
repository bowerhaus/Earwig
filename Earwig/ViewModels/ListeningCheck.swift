import Foundation
import Observation

/// The Listening check (PRD §4.3, §8.5; plan 005, decision 12): the listener on its own, with no
/// engine, showing what it hears and how late, the input level, the route and the speech
/// assets. Say Test plays a line of the sample in the presenter's voice through the earpiece
/// while listening, to show whether the mic hears the earpiece.
@MainActor
@Observable
final class ListeningCheck {
    /// The sample's first spoken phrase: made up, so it can be quoted (the repo is public).
    static let testPhrase: String = {
        let steps = ScriptParser.parse(SampleScript.harbourWalk).steps
        return steps.first.flatMap { PhraseList(lines: $0.lines).spoken.first?.phrase.text } ?? "Welcome to the harbour."
    }()

    let session = AudioSessionManager()
    let audio = AudioEngineHost()
    let listener: Listener
    private(set) var problem: String?
    private(set) var isSayingTest = false
    /// Set when the screen goes, so a `start()` still waiting stops instead of listening on
    /// with no screen (review C4, plan 005).
    @ObservationIgnored private var stopped = false

    init() {
        listener = Listener(audio: audio)
        session.onEvent = { Log.event($0) }
        audio.onEvent = { Log.event($0) }
        listener.onEvent = { Log.event("listening check: \($0)") }
    }

    func start() async {
        problem = nil
        guard await session.requestMicrophone() else {
            problem = "Earwig needs the microphone. Allow it in Settings › Privacy & Security › Microphone."
            return
        }
        guard !stopped else { return }
        do {
            try session.configure()
            try audio.start()
        } catch {
            problem = "The audio could not start: \(error.localizedDescription)"
            return
        }
        await listener.checkAssets()
        guard !stopped else { return await tearDown() }
        let context = Self.testPhrase.split(whereSeparator: \.isWhitespace).map { $0.trimmingCharacters(in: .punctuationCharacters) }
        // A listening failure shows in the state row.
        await listener.start(contextWords: context, fastResults: true)
        if stopped { await tearDown() }
    }

    func stop() async {
        stopped = true
        await tearDown()
    }

    private func tearDown() async {
        audio.stop(.voice)
        await listener.stop()
        audio.stop()
        session.deactivate()
        isSayingTest = false
    }

    /// Plays the test phrase in the presenter's voice while listening goes on.
    func sayTest(with renderer: ScriptRenderer) async {
        guard !isSayingTest else { return }
        isSayingTest = true
        do {
            let rendered = try await renderer.renderPresenter(Self.testPhrase)
            Log.event("listening check: say test on \(session.route.summary)")
            try audio.play(rendered.buffer, on: .voice, delay: 0) { [weak self] in self?.isSayingTest = false }
        } catch {
            problem = "Say Test could not play: \(error.localizedDescription)"
            isSayingTest = false
        }
    }
}
