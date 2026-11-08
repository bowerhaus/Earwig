import AVFoundation
@testable import Earwig
import Testing

struct PromptViewModelTests {

    /// Phrases: "We follow the footpath.", the cue [Point], "Down to three hundred boats."
    private let setup: TakeSetup.Summary = {
        let list = PhraseList(lines: ["We follow the footpath. [Point] Down to three hundred boats."])
        let script = FollowScript(phraseList: list)
        return TakeSetup.Summary(number: 3, title: "The footpath", take: 2, start: .slateWithReply,
                                 screenWords: ScreenText.words(phraseList: list, firstWord: script.firstWord))
    }()

    private func route(out: AVAudioSession.Port, in input: AVAudioSession.Port = .builtInMic) -> AudioRoute {
        var route = AudioRoute()
        route.outputs = [AudioRoute.Port(type: out.rawValue, name: "Out")]
        route.inputs = [AudioRoute.Port(type: input.rawValue, name: "In")]
        return route
    }

    private func model(_ phase: TakeHost.Phase = .running, _ status: FollowStatus = .speaking, voicePhrase: Int? = 0, voiceWord: Int? = nil,
                       route: AudioRoute? = nil, start: StartMode = .slateWithReply, download: Double? = nil,
                       mode: TakeMode = .voice, recording: TakeRecordingMode = .off,
                       recorded: PromptViewModel.Recording = PromptViewModel.Recording()) -> PromptViewModel {
        var snapshot = FollowSnapshot()
        snapshot.status = status
        snapshot.voicePhrase = voicePhrase
        snapshot.voiceWord = voiceWord
        var setup = setup
        setup.start = start
        setup.mode = mode
        setup.recording = recording
        return PromptViewModel(phase: phase, snapshot: snapshot, route: route ?? self.route(out: .bluetoothA2DP), setup: setup,
                               downloadProgress: download, recording: recorded)
    }

    // MARK: - Recording (plan 010)

    private static let file = RecordingResult(url: URL(filePath: "/tmp/Step 3 Take 2.mov"), video: true, duration: 30)

    @Test func aVideoTakeFramesWhileGettingReady() {
        #expect(model(.gettingReady, .idle, recording: .video).isFraming)
        #expect(!model(.gettingReady, .idle, recording: .sound).isFraming)
        #expect(!model(.running, .speaking, recording: .video).isFraming)
    }

    @Test func theDotShowsWhileRecordingAndTurnsToSoundWhenTheVideoStops() {
        let recorded = PromptViewModel.Recording(since: 100)
        #expect(model(.running, .speaking, recording: .video, recorded: recorded).showsRecordingDot)
        #expect(!model(.running, .speaking, recording: .video).showsRecordingDot)
        #expect(!model(.finished(.completed), .finished, recording: .video, recorded: recorded).showsRecordingDot)
        let stopped = PromptViewModel.Recording(since: 100, videoStopped: true)
        #expect(model(.running, .speaking, recording: .video, recorded: stopped).recordingSoundOnly)
        #expect(!model(.running, .speaking, recording: .video, recorded: recorded).recordingSoundOnly)
    }

    @Test func nextTakeWaitsForTheRecordingToBeSaved() {
        let saving = model(.finished(.completed), .finished, recording: .video, recorded: PromptViewModel.Recording(since: 100))
        #expect(saving.isSavingRecording)
        #expect(!saving.canTakeAgain)
        let saved = model(.finished(.completed), .finished, recording: .video,
                          recorded: PromptViewModel.Recording(since: 100, result: Self.file, isTornDown: true))
        #expect(!saved.isSavingRecording)
        #expect(saved.canTakeAgain)
        #expect(model(.finished(.completed), .finished).canTakeAgain)
    }

    @Test func playVideoAndPlaySoundForAVideoAndPlayBackForSound() {
        let video = model(.finished(.completed), .finished, recording: .video,
                          recorded: PromptViewModel.Recording(result: Self.file, isTornDown: true))
        #expect(video.canPlayVideo)
        #expect(video.canPlaySound)
        var sound = Self.file
        sound.video = false
        let soundOnly = model(.finished(.completed), .finished, recording: .sound,
                              recorded: PromptViewModel.Recording(result: sound, isTornDown: true))
        #expect(!soundOnly.canPlayVideo)
        #expect(soundOnly.canPlaySound)
        var stoppedAtOnce = Self.file
        stoppedAtOnce.videoStoppedAt = 0
        #expect(!model(.finished(.completed), .finished, recording: .video,
                       recorded: PromptViewModel.Recording(result: stoppedAtOnce, isTornDown: true)).canPlayVideo)
    }

    @Test func theRecordingsNoteShowsOnceTheTakeIsOver() {
        let note = PromptViewModel.Recording(note: "Video stopped at 1:23: the phone was locked.")
        #expect(model(.finished(.stopped), .finished, recording: .video, recorded: note).recordingText == note.note)
        #expect(model(.running, .speaking, recording: .video, recorded: note).recordingText == nil)
        let nothing = PromptViewModel.Recording(since: 100, isTornDown: true)
        #expect(model(.finished(.stopped), .finished, recording: .sound, recorded: nothing).recordingText == "Nothing was recorded.")
        #expect(model(.finished(.stopped), .finished, recorded: nothing).recordingText == nil)
    }

    @Test func theStatusWords() {
        #expect(model(.gettingReady, .idle).status == "Getting ready")
        #expect(model(.running, .slate).status == "Slate")
        #expect(model(.running, .tones).status == "Tones")
        #expect(model(.running, .speaking).status == "Speaking")
        #expect(model(.running, .waiting).status == "Waiting")
        #expect(model(.running, .lost).status == "Lost")
        #expect(model(.running, .held).status == "Held")
        #expect(model(.finished(.completed), .finished).status == "Finished")
        #expect(model(.failed("No mic"), .idle).status == "Can't start")
    }

    @Test func whatToDo() {
        #expect(model(.running, .slate).instruction == "Say the slate, or tap")
        #expect(model(.running, .slate, start: .slate).instruction == "Say the slate to the camera")
        #expect(model(.running, .slate).tapStarts)
        #expect(!model(.running, .speaking).tapStarts)
        #expect(model(.gettingReady, .idle, download: 0.4).instruction == "Downloading speech for listening: 40%")
        #expect(model(.failed("No mic"), .idle).instruction == "No mic")
        #expect(model(.finished(.stopped), .finished).instruction == "Stopped")
        let gaveUp = PromptViewModel(phase: .finished(.stopped), snapshot: FollowSnapshot(), route: route(out: .bluetoothA2DP), setup: setup,
                                     stopReason: "listening stopped after two failures in ten seconds")
        #expect(gaveUp.instruction == "Stopped: listening stopped after two failures in ten seconds")
    }

    @Test func theRouteStates() {
        let earpiece = model(route: route(out: .bluetoothA2DP))
        #expect(earpiece.earpiece == .good)
        #expect(earpiece.mic == .good)
        #expect(earpiece.routeNote == nil)

        let handsFree = model(route: route(out: .bluetoothHFP, in: .bluetoothHFP))
        #expect(handsFree.earpiece == .wrong)
        #expect(handsFree.mic == .wrong)
        #expect(handsFree.routeNote == "The earpiece is in hands-free mode: reconnect it.")

        let speaker = model(route: route(out: .builtInSpeaker))
        #expect(speaker.earpiece == .caution)
        #expect(speaker.routeNote == "Speaker: the mic will hear the voice.")

        let headsetMic = model(route: route(out: .headphones, in: .headsetMic))
        #expect(headsetMic.earpiece == .good)
        #expect(headsetMic.mic == .wrong)
        #expect(headsetMic.routeNote == "Not listening on the iPhone's mic.")
    }

    @Test func withNoVoiceTheEarpieceIsNotJudged() {
        let speaker = model(.running, .reading, route: route(out: .builtInSpeaker), mode: .screen)
        #expect(speaker.earpiece == .unknown)
        #expect(speaker.mic == .good)
        #expect(speaker.routeNote == nil)
        let handsFree = model(.running, .reading, route: route(out: .bluetoothHFP, in: .bluetoothHFP), mode: .screen)
        #expect(handsFree.earpiece == .unknown)
        #expect(handsFree.mic == .wrong)
        #expect(handsFree.routeNote == "Not listening on the iPhone's mic.")
        // With Voice, the earpiece is judged.
        #expect(model(route: route(out: .builtInSpeaker), mode: .voice).earpiece == .caution)
    }

    @Test func theRouteIsJudgedOnlyWhileATakeRuns() {
        var none = AudioRoute()
        none.outputs = [AudioRoute.Port(type: AVAudioSession.Port.bluetoothA2DP.rawValue, name: "SK18")]
        for phase: TakeHost.Phase in [.gettingReady, .finished(.completed), .failed("No mic")] {
            let model = model(phase, .finished, route: none)
            #expect(model.mic == .unknown)
            #expect(model.earpiece == .unknown)
            #expect(model.routeNote == nil)
        }
        #expect(model(.running, .speaking, route: none).mic == .wrong)
    }

    @Test func theControlsByStatus() {
        let slate = model(.running, .slate)
        #expect(!slate.holdEnabled && !slate.backEnabled && !slate.forwardEnabled)
        #expect(slate.restartEnabled && slate.stopEnabled)

        let speaking = model(.running, .speaking)
        #expect(speaking.holdEnabled && speaking.backEnabled && speaking.forwardEnabled && !speaking.isHeld)

        let held = model(.running, .held)
        #expect(held.holdEnabled && held.isHeld)

        let finished = model(.finished(.completed), .finished)
        #expect(!finished.stopEnabled && !finished.restartEnabled)
        #expect(finished.isOver && finished.canTakeAgain)

        let failed = model(.failed("No mic"), .idle)
        #expect(failed.isOver && !failed.canTakeAgain)

        let gettingReady = model(.gettingReady, .idle)
        #expect(!gettingReady.stopEnabled && !gettingReady.isOver)
    }

    @Test func theTopLine() {
        let model = model()
        #expect(model.stepText == "Step 3 · The footpath")
        #expect(model.takeText == "Take 2")
    }

    @Test func diagnosticsWhileFollowing() {
        var snapshot = FollowSnapshot()
        snapshot.status = .speaking
        snapshot.error = -0.42
        snapshot.speed = 1.05
        snapshot.delay = 0.91
        snapshot.rate = 2.63
        let model = PromptViewModel(phase: .running, snapshot: snapshot, route: route(out: .bluetoothA2DP), setup: setup)
        #expect(model.diagnostics == "lead error -0.4 · speed 1.05× · delay 0.91 s · rate 2.6 w/s")
        #expect(self.model(.running, .slate).diagnostics == nil)
    }

    // MARK: - Screen mode

    private func screen(_ status: FollowStatus, place: Double = -1, voicePhrase: Int? = nil, voiceWord: Int? = nil,
                        mode: TakeMode = .screen, lightsVoice: Bool = true) -> PromptViewModel {
        var snapshot = FollowSnapshot()
        snapshot.status = status
        snapshot.presenterPlace = place
        snapshot.voicePhrase = voicePhrase
        snapshot.voiceWord = voiceWord
        var setup = setup
        setup.mode = mode
        setup.lightsVoice = lightsVoice
        return PromptViewModel(phase: .running, snapshot: snapshot, route: route(out: .builtInSpeaker), setup: setup)
    }

    @Test func beforeFollowingEveryWordWaits() {
        let model = screen(.tones)
        #expect(model.screenTokens.allSatisfy { $0.isWaiting })
        #expect(model.place == -1)
        #expect(screen(.reading).status == "Reading")
    }

    /// Which words are dimmed is the caller's cut-off (the follower's mark); a cue and a word
    /// still waiting are never dimmed.
    @Test func wordsBeforeTheCutOffAreHeardButNotCuesOrWaitingWords() {
        // Words: We(0) follow(1) the(2) footpath.(3) [Point] Down(4) to(5) three hundred(6) boats.(7)
        let tokens = screen(.reading, place: 2.6).screenTokens
        #expect(tokens.filter { $0.isHeard(before: 2) }.map(\.word.text) == ["We", "follow"])
        #expect(!tokens.contains { $0.isHeard(before: nil) })
        #expect(tokens.first { $0.word.isCue }?.isHeard(before: 6) == false)
        #expect(!screen(.tones).screenTokens.contains { $0.isHeard(before: 2) })
        #expect(screen(.reading, place: 2.6).place == 2.6)
    }

    @Test func aCueIsNeverLit() {
        let cue = screen(.speaking, place: 6, voicePhrase: 1, mode: .voice).screenTokens.first { $0.word.isCue }
        #expect(cue?.word.text == "[Point]")
        #expect(cue?.inVoicePhrase == false)
    }

    @Test func withTheVoiceItsPhraseIsLitAndItsWordMarked() {
        let tokens = screen(.speaking, place: 1, voicePhrase: 2, voiceWord: 5, mode: .voice).screenTokens
        #expect(tokens.filter { $0.inVoicePhrase }.map(\.word.text) == ["Down", "to", "three hundred", "boats."])
        #expect(tokens.filter { $0.isVoiceWord }.map(\.word.text) == ["to"])
        // Waiting, the phrase stays lit and no word is being said.
        let waiting = screen(.waiting, place: 1, voicePhrase: 2, voiceWord: 7, mode: .voice).screenTokens
        #expect(waiting.filter { $0.inVoicePhrase }.count == 4)
        #expect(!waiting.contains { $0.isVoiceWord })
        // Not lit when the setting is off, nor on the screen alone.
        let off = screen(.speaking, place: 1, voicePhrase: 2, voiceWord: 5, mode: .voice, lightsVoice: false)
        #expect(!off.screenTokens.contains { $0.inVoicePhrase || $0.isVoiceWord })
        #expect(!screen(.reading, place: 1, voicePhrase: 2, voiceWord: 5).screenTokens.contains { $0.inVoicePhrase })
    }

    /// Lost or held, the place and the diagnostics stay live.
    @Test func lostAndHeldStillFollow() {
        for status in [FollowStatus.lost, .held] {
            #expect(screen(status, place: 3).place == 3)
            #expect(screen(status, place: 3).diagnostics != nil)
        }
    }
}
