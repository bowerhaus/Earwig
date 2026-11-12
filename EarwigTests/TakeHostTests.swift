import AVFoundation
@testable import Earwig
import Foundation
import Testing

/// The take loop against fakes on a clock the test moves (plan 005, step 3). Made-up text only.
@MainActor
struct TakeHostTests {

    final class Calls {
        var list: [String] = []
    }

    final class TestClock {
        var now: TimeInterval = 100
    }

    final class FakeSession: TakeSession {
        let calls: Calls
        var route = AudioRoute()
        var onInterruption: ((Bool) -> Void)?
        var onDeviceLost: (() -> Void)?
        var microphone = true
        var deactivated = 0

        init(calls: Calls) { self.calls = calls }

        func requestMicrophone() async -> Bool {
            calls.list.append("microphone")
            return microphone
        }

        func configure() throws { calls.list.append("configure") }

        func deactivate() { deactivated += 1 }
    }

    final class FakeHeard: HeardSource {
        let calls: Calls
        var onHeard: ((FollowEvent, TimeInterval) -> Void)?
        var onRestart: (() -> Void)?
        var onGaveUp: ((String) -> Void)?
        var downloadProgress: Double?
        var failure: String?
        var context: [String] = []
        var stopped = 0

        init(calls: Calls) { self.calls = calls }

        func listen(contextWords: [String]) async -> String? {
            calls.list.append("listen")
            context = contextWords
            return failure
        }

        func stopListening() async { stopped += 1 }
    }

    final class FakeRecorder: TakeRecorder {
        var started: [Date] = []
        var finished: [(duration: TimeInterval, outcome: TakeOutcome)] = []
        var recordings: [RecordingResult?] = []

        func started(at date: Date) { started.append(date) }

        func finished(duration: TimeInterval, outcome: TakeOutcome) { finished.append((duration, outcome)) }

        func recordingFinished(_ result: RecordingResult?) { recordings.append(result) }
    }

    /// A take's recording (plan 010).
    final class FakeCapture: TakeCapture {
        let video: Bool
        var onVideoStopped: ((String) -> Void)?
        var onFailed: ((String) -> Void)?
        var problem: String?
        var prepared = 0
        var startedAt: [TimeInterval] = []
        var finishes = 0
        var result: RecordingResult?
        var camera: CameraCapture? { nil }

        init(video: Bool) {
            self.video = video
            result = RecordingResult(url: URL(filePath: "/tmp/Step 1 Take 2.\(video ? "mov" : "m4a")"), video: video, duration: 3)
        }

        func prepare() async -> String? {
            prepared += 1
            return problem
        }

        func start(at hostTime: TimeInterval) { startedAt.append(hostTime) }

        func finish() async -> RecordingResult? {
            finishes += 1
            return startedAt.isEmpty ? nil : result
        }
    }

    private let calls = Calls()
    private let clock = TestClock()
    private let output = FakeOutput()
    private let session: FakeSession
    private let heard: FakeHeard
    private let recorder = FakeRecorder()

    /// Two phrases, a word every 0.4 s: words 0 to 3, then 4 to 9.
    private static let lines = ["We follow the footpath", "down to the end of the fields."]

    init() {
        session = FakeSession(calls: calls)
        heard = FakeHeard(calls: calls)
        output.calls = { [calls] in calls.list.append($0) }
    }

    private func host(start: StartMode = .slateWithReply, slateText: String = "Step 1, take 2.", slateFails: Bool = false,
                      mode: TakeMode = .voice, capture: FakeCapture? = nil) -> TakeHost {
        let phrases = Self.lines.map { line in
            let words = ScriptWords.words(in: line)
            return FollowPhrase(kind: .spoken, words: words, wordStarts: words.indices.map { Double($0) * 0.4 }, duration: Double(words.count) * 0.4)
        }
        let audio = TakeAudio(phrases: phrases.map { TakeAudio.Phrase(kind: .spoken, buffer: silence(seconds: $0.duration)) }, slate: nil, tones: silence(seconds: Tones.duration))
        var settings = FollowSettings()
        settings.start = start
        var setup = TakeSetup(
            stepNumber: 1, stepTitle: "The footpath", take: 2,
            phraseList: PhraseList(lines: Self.lines),
            script: FollowScript(phrases: phrases), audio: audio,
            slateText: slateText, slateWords: Slate.replyWords(number: 1, shotID: nil, take: 2),
            settings: settings, contextWords: ["We", "follow"]
        )
        setup.mode = mode
        if !mode.voiced { setup.audio.phrases = [] }
        if let capture { setup.recording = capture.video ? .video : .sound }
        let calls = calls
        return TakeHost(
            setup: setup, session: session, output: output, heard: heard, recorder: recorder, capture: capture,
            renderSlate: { _ in
                calls.list.append("slate")
                if slateFails { throw VoiceRenderer.RenderError.conversion }
                return silence(seconds: 1.5)
            },
            clock: { [clock] in clock.now }, ticks: false, log: { _ in }
        )
    }

    /// Moves the clock on, ticking the host every 50 ms, with whatever is playing moving on as
    /// it would (the voice at its speed). Buffers are ended by the tests.
    private func pass(_ seconds: TimeInterval, _ host: TakeHost) {
        for _ in 0..<Int((seconds / TakeHost.tickInterval).rounded()) {
            clock.now += TakeHost.tickInterval
            for (channel, position) in output.positions {
                output.positions[channel] = position + TakeHost.tickInterval * (channel == .voice ? output.speed : 1)
            }
            host.tick()
        }
    }

    private func hear(_ event: FollowEvent) {
        heard.onHeard?(event, clock.now)
    }

    /// The presenter's finals for words of the script, spoken from `start`, a word every 0.4 s.
    private func finals(_ words: [String], spokenFrom start: TimeInterval) -> FollowEvent {
        .final(words.enumerated().map { FinalWord(text: $1, start: start + Double($0) * 0.4) })
    }

    /// Gets through the slate and its reply to the first phrase playing.
    private func throughTheSlate(_ host: TakeHost) async {
        await host.start()
        pass(1.5, host)
        output.end(.cue)
        pass(1, host)
        hear(finals(["1", "take", "2"], spokenFrom: clock.now - 1.5))
        pass(0.1, host)
        output.end(.tone)
        pass(0.1, host)
    }

    @Test func gettingReadyListensBeforeTheSlate() async {
        let host = host()
        await host.start()
        #expect(calls.list == ["microphone", "configure", "output.start", "listen", "slate"])
        #expect(host.phase == .running)
        #expect(host.snapshot.status == .slate)
        #expect(output.played.map(\.channel) == [.cue])
        #expect(heard.context == ["We", "follow"])
        #expect(recorder.started.count == 1)
    }

    /// Waits for the take to let everything go, which runs in a task of its own.
    private func tornDown(_ host: TakeHost) async {
        for _ in 0..<50 where !host.isTornDown { await Task.yield() }
    }

    // MARK: - Recording (plan 010)

    @Test func aSoundTakeIsRecordedFromTheSlateToTheEnd() async {
        let capture = FakeCapture(video: false)
        let host = host(capture: capture)
        await host.start()
        #expect(capture.prepared == 1)
        #expect(host.cameraReady)
        #expect(capture.startedAt == [100])
        #expect(host.recordingSince == 100)
        #expect(recorder.started.count == 1)
        pass(0.5, host)
        host.control(.stop)
        await tornDown(host)
        #expect(capture.finishes == 1)
        #expect(host.recording == capture.result)
        #expect(recorder.recordings == [capture.result])
        #expect(session.deactivated == 1)
    }

    @Test func aVideoTakeWaitsOnThePreviewForStart() async {
        let capture = FakeCapture(video: true)
        let host = host(capture: capture)
        await host.start()
        #expect(host.phase == .gettingReady)
        #expect(host.readyToGo)
        #expect(output.played.isEmpty)
        #expect(recorder.started.isEmpty)
        #expect(capture.startedAt.isEmpty)
        clock.now = 104
        host.go()
        #expect(!host.readyToGo)
        #expect(host.phase == .running)
        #expect(output.played.map(\.channel) == [.cue])
        #expect(recorder.started.count == 1)
        #expect(capture.startedAt == [104])
    }

    @Test func cancellingOnThePreviewRecordsNothingAndLetsEverythingGo() async {
        let capture = FakeCapture(video: true)
        let host = host(capture: capture)
        await host.start()
        host.end()
        await tornDown(host)
        #expect(recorder.started.isEmpty)
        #expect(capture.finishes == 1)
        #expect(host.recording == nil)
        #expect(recorder.recordings.isEmpty)
        #expect(session.deactivated == 1)
        host.go()
        #expect(host.phase == .gettingReady)
    }

    @Test func aCameraThatCannotStartRecordsNoTake() async {
        let capture = FakeCapture(video: true)
        capture.problem = "Earwig needs the camera."
        let host = host(capture: capture)
        await host.start()
        #expect(host.phase == .failed("Earwig needs the camera."))
        #expect(recorder.started.isEmpty)
        #expect(!calls.list.contains("slate"))
        #expect(!calls.list.contains("listen"))
        await tornDown(host)
        #expect(capture.finishes == 1)
        #expect(session.deactivated == 1)
    }

    @Test func aRecordingThatCameToNothingIsGivenBackAsNothing() async {
        let capture = FakeCapture(video: false)
        capture.result = nil
        let host = host(capture: capture)
        await host.start()
        host.control(.stop)
        await tornDown(host)
        #expect(recorder.recordings == [nil])
        #expect(host.recording == nil)
    }

    @Test func theVideoStoppingOrTheRecordingFailingLeavesTheTakeRunning() async {
        let capture = FakeCapture(video: true)
        let host = host(capture: capture)
        await host.start()
        host.go()
        pass(83, host)
        capture.onVideoStopped?("the phone was locked")
        #expect(host.recordingNote == "Video stopped at 1:23: the phone was locked.")
        #expect(host.videoStopped)
        #expect(host.phase == .running)
        capture.onFailed?("the disk is full")
        #expect(host.recordingNote == "Recording stopped: the disk is full.")
        #expect(host.recordingSince == nil)
        #expect(host.phase == .running)
    }

    @Test func aTakeWithNoRecordingIsTornDownAsBefore() async {
        let host = host()
        await host.start()
        host.control(.stop)
        await tornDown(host)
        #expect(host.isTornDown)
        #expect(host.recording == nil)
        #expect(recorder.recordings.isEmpty)
    }

    @Test func aCleanReadWithTheSlateReplyCompletesAndIsRecorded() async {
        let host = host()
        await throughTheSlate(host)
        #expect(output.played.map(\.channel) == [.cue, .tone, .voice])
        #expect(host.snapshot.status == .speaking)

        // Phrase 1 read behind the voice, its interim then its final.
        pass(1, host)
        hear(.interim("We follow"))
        pass(0.6, host)
        hear(.interim("We follow the footpath"))
        output.end(.voice)
        pass(0.4, host)
        hear(finals(["We", "follow", "the", "footpath"], spokenFrom: clock.now - 2.4))
        pass(0.3, host)
        #expect(output.played.last?.channel == .voice)
        #expect(host.snapshot.voicePhrase == 1)

        // Phrase 2, then the last word heard.
        pass(1.2, host)
        hear(.interim("down to the end"))
        pass(1, host)
        output.end(.voice)
        hear(.interim("down to the end of the"))
        pass(0.6, host)
        let lastHeardAt = clock.now
        hear(finals(["down", "to", "the", "end", "of", "the", "fields"], spokenFrom: clock.now - 3.4))
        pass(0.1, host)

        #expect(host.phase == .finished(.completed))
        #expect(recorder.finished.count == 1)
        #expect(recorder.finished.first?.outcome == .completed)
        // From the slate to the last word heard.
        #expect(abs((recorder.finished.first?.duration ?? 0) - (lastHeardAt - 100)) < 0.01)
        #expect(recorder.started.count == 1)
    }

    @Test func aTakeWithNoVoiceFollowsAndCompletesWithNothingOnTheVoice() async {
        let host = host(mode: .screen)
        await throughTheSlate(host)
        #expect(output.played.map(\.channel) == [.cue, .tone])
        #expect(host.snapshot.status == .reading)
        // The earpiece put away: nothing plays through it, so the take goes on.
        session.onDeviceLost?()
        #expect(host.snapshot.status == .reading)

        pass(1, host)
        hear(.interim("We follow the footpath down to"))
        pass(1, host)
        hear(finals(["We", "follow", "the", "footpath", "down", "to", "the", "end", "of", "the", "fields"], spokenFrom: clock.now - 4.4))
        pass(0.1, host)
        #expect(host.phase == .finished(.completed))
        #expect(!output.played.contains { $0.channel == .voice })
        #expect(recorder.finished.map(\.outcome) == [.completed])
    }

    @Test func stopRecordsAStoppedTake() async {
        let host = host()
        await throughTheSlate(host)
        pass(0.5, host)
        host.control(.stop)
        #expect(host.phase == .finished(.stopped))
        #expect(host.stopReason == nil)
        #expect(recorder.finished.map(\.outcome) == [.stopped])
        #expect(output.stopped.contains(.voice))
    }

    @Test func aTapSkipsTheReply() async {
        let host = host()
        await host.start()
        pass(1.5, host)
        output.end(.cue)
        pass(0.5, host)
        host.control(.tap)
        #expect(output.played.map(\.channel) == [.cue, .tone])
        #expect(host.snapshot.status == .tones)
    }

    @Test func tonesOnlyPlaysNoSlate() async {
        // A slate that would fail to render: with tones only it is never rendered (review C3).
        let host = host(start: .tonesOnly, slateText: "", slateFails: true)
        await host.start()
        #expect(!calls.list.contains("slate"))
        #expect(output.played.map(\.channel) == [.tone])
        #expect(recorder.started.count == 1)
    }

    /// Plan 015, decision 14: a step's cues are read before the tones alone.
    @Test func tonesOnlyReadsTheCuesThenTheTones() async {
        let host = host(start: .tonesOnly, slateText: "The entrance. At the pier gates.")
        await host.start()
        #expect(calls.list.contains("slate"))
        #expect(output.played.map(\.channel) == [.cue])
        pass(1.5, host)
        output.end(.cue)
        pass(0.1, host)
        #expect(output.played.map(\.channel) == [.cue, .tone])
        #expect(recorder.started.count == 1)
    }

    @Test func restartPlaysTheTonesInTheSameTake() async {
        let host = host()
        await throughTheSlate(host)
        pass(0.5, host)
        host.control(.restart)
        #expect(output.played.map(\.channel) == [.cue, .tone, .voice, .tone])
        #expect(host.snapshot.status == .tones)
        #expect(recorder.started.count == 1)
        #expect(host.phase == .running)
    }

    @Test func progressReachesTheEngineEveryTick() async {
        let host = host()
        await throughTheSlate(host)
        #expect(host.snapshot.voiceWord == 0)
        // 1.05 s rendered, less 0.2 s latency: 0.85 s in, the third word.
        output.positions[.voice] = 1.05
        host.tick()
        #expect(host.snapshot.voiceWord == 2)
    }

    @Test func aListenerRestartSettlesTheBlock() async {
        let host = host()
        await throughTheSlate(host)
        pass(1, host)
        hear(.interim("We follow the"))
        pass(0.1, host)
        #expect(host.snapshot.presenterWord >= 1)
        heard.onRestart?()
        pass(0.05, host)
        #expect(host.snapshot.presenterWord == -1)
    }

    @Test func listeningThatGivesUpMidTakeStopsItAndSaysWhy() async {
        let host = host()
        await throughTheSlate(host)
        pass(0.5, host)
        heard.onGaveUp?("listening stopped after two failures in ten seconds")
        #expect(host.phase == .finished(.stopped))
        #expect(host.stopReason == "listening stopped after two failures in ten seconds")
        #expect(recorder.finished.map(\.outcome) == [.stopped])
        #expect(output.stopped.contains(.voice))
        // Nothing more reaches the engine, and everything is let go.
        let played = output.played.count
        hear(.interim("We follow the footpath"))
        pass(1, host)
        #expect(output.played.count == played)
        for _ in 0..<20 where session.deactivated == 0 { await Task.yield() }
        #expect(heard.stopped == 1)
        #expect(heard.onGaveUp == nil)
    }

    @Test func aCallStopsTheTake() async {
        let host = host()
        await throughTheSlate(host)
        session.onInterruption?(true)
        #expect(host.phase == .finished(.stopped))
        #expect(recorder.finished.map(\.outcome) == [.stopped])
    }

    @Test func aLostEarpieceHolds() async {
        let host = host()
        await throughTheSlate(host)
        pass(0.5, host)
        session.onDeviceLost?()
        #expect(host.snapshot.status == .held)
        #expect(output.stopped.contains(.voice))
        #expect(host.phase == .running)
    }

    @Test func anEngineRestartReanchorsTheVoice() async {
        let host = host()
        await throughTheSlate(host)
        pass(1, host)
        hear(.interim("We follow"))
        pass(0.1, host)
        let stopsBefore = output.stopped.filter { $0 == .voice }.count
        output.onRestarted?()
        #expect(output.stopped.filter { $0 == .voice }.count > stopsBefore)
        #expect(host.snapshot.status != .held)
        #expect(host.phase == .running)
    }

    @Test func anEngineRestartDuringTheSlateGoesToTheTones() async {
        let host = host()
        await host.start()
        output.onRestarted?()
        #expect(host.snapshot.status == .tones)
        #expect(output.played.map(\.channel) == [.cue, .tone])
    }

    @Test func noMicrophoneRecordsNoTake() async {
        session.microphone = false
        let host = host()
        await host.start()
        guard case .failed = host.phase else {
            Issue.record("expected a failure, got \(host.phase)")
            return
        }
        #expect(!calls.list.contains("listen"))
        #expect(recorder.started.isEmpty)
        #expect(output.played.isEmpty)
    }

    @Test func listeningThatFailsRecordsNoTakeAndTearsDown() async {
        heard.failure = "no assets"
        let host = host()
        await host.start()
        #expect(host.phase == .failed("Listening could not start: no assets"))
        #expect(recorder.started.isEmpty)
        #expect(calls.list.last == "output.stop")
        #expect(session.deactivated == 1)
    }

    @Test func aSlateThatFailsRecordsNoTake() async {
        let host = host(slateFails: true)
        await host.start()
        guard case .failed = host.phase else {
            Issue.record("expected a failure, got \(host.phase)")
            return
        }
        #expect(recorder.started.isEmpty)
    }

    @Test func closingARunningTakeStopsItAndLetsEverythingGo() async {
        let host = host()
        await throughTheSlate(host)
        host.end()
        #expect(host.phase == .finished(.stopped))
        #expect(recorder.finished.map(\.outcome) == [.stopped])
        // The teardown runs in a task of its own.
        for _ in 0..<20 where session.deactivated == 0 { await Task.yield() }
        #expect(heard.stopped == 1)
        #expect(calls.list.last == "output.stop")
        #expect(session.deactivated == 1)
    }

    @Test func theContextWordsAreTheStepsAndTheSlatesOnceEach() {
        let words = TakeSetup.contextWords(phraseList: PhraseList(lines: ["We follow the footpath.", "The footpath ends here!"]), slateText: "Step 1, take 2.")
        #expect(words == ["We", "follow", "the", "footpath", "ends", "here", "Step", "1", "take", "2"])
    }

    @Test func closingWhileGettingReadyStartsNothing() async {
        let host = host()
        host.end()
        await host.start()
        #expect(recorder.started.isEmpty)
        #expect(output.played.isEmpty)
    }
}
