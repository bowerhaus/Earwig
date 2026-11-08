import AVFoundation
@testable import Earwig
import Testing

struct PromptViewModelTests {

    /// Phrases: "We follow the footpath.", the cue [Point], "Down to three hundred boats."
    private let setup: TakeSetup.Summary = {
        let list = PhraseList(lines: ["We follow the footpath. [Point] Down to three hundred boats."])
        let script = FollowScript(phraseList: list)
        return TakeSetup.Summary(number: 3, title: "The footpath", take: 2, start: .slateWithReply, phraseList: list, firstWord: script.firstWord)
    }()

    private func route(out: AVAudioSession.Port, in input: AVAudioSession.Port = .builtInMic) -> AudioRoute {
        var route = AudioRoute()
        route.outputs = [AudioRoute.Port(type: out.rawValue, name: "Out")]
        route.inputs = [AudioRoute.Port(type: input.rawValue, name: "In")]
        return route
    }

    private func model(_ phase: TakeHost.Phase = .running, _ status: FollowStatus = .speaking, voicePhrase: Int? = 0, voiceWord: Int? = nil,
                       route: AudioRoute? = nil, start: StartMode = .slateWithReply, download: Double? = nil,
                       mode: TakeMode = .ear) -> PromptViewModel {
        var snapshot = FollowSnapshot()
        snapshot.status = status
        snapshot.voicePhrase = voicePhrase
        snapshot.voiceWord = voiceWord
        var setup = setup
        setup.start = start
        setup.mode = mode
        return PromptViewModel(phase: phase, snapshot: snapshot, route: route ?? self.route(out: .bluetoothA2DP), setup: setup, downloadProgress: download)
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

    @Test func thePhraseWithTheVoicesWord() {
        let tokens = model(.running, .speaking, voicePhrase: 0, voiceWord: 2).phrase
        #expect(tokens.map(\.text) == ["We", "follow", "the", "footpath."])
        #expect(tokens.map(\.isVoiceWord) == [false, false, true, false])
    }

    @Test func aNumberSaidInWordsIsOneToken() {
        // Phrase 2 starts at word 4: "Down", "to", "three hundred", "boats."
        let tokens = model(.running, .speaking, voicePhrase: 2, voiceWord: 6).phrase
        #expect(tokens.map(\.text) == ["Down", "to", "three hundred", "boats."])
        #expect(tokens.map(\.isVoiceWord) == [false, false, true, false])
    }

    @Test func waitingShowsThePhraseTheVoiceIsAfter() {
        let waiting = model(.running, .waiting, voicePhrase: 0, voiceWord: 3)
        #expect(waiting.phrase.map(\.text) == ["We", "follow", "the", "footpath."])
        #expect(waiting.phrase.allSatisfy { !$0.isVoiceWord })
    }

    @Test func aCueIsShownInBrackets() {
        let cue = model(.running, .speaking, voicePhrase: 1)
        #expect(cue.phrase.map(\.text) == ["[Point]"])
        #expect(cue.phrase.allSatisfy { $0.isCue })
    }

    @Test func noPhraseBeforeTheVoiceStarts() {
        #expect(model(.running, .slate, voicePhrase: nil).phrase.isEmpty)
        #expect(model(.running, .tones, voicePhrase: nil).phrase.isEmpty)
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
        // With the voice on the screen too, the earpiece is judged as in Ear mode.
        #expect(model(route: route(out: .builtInSpeaker), mode: .both).earpiece == .caution)
    }

    @Test func waitingMidSentenceShowsTheWholeSentence() {
        let list = PhraseList(lines: ["Morning!", "The plan is simple: along the sea wall, up the cliff path, and back through the village for a late breakfast."])
        let summary = TakeSetup.Summary(number: 1, title: "", take: 1, start: .slateWithReply, phraseList: list, firstWord: FollowScript(phraseList: list).firstWord)
        #expect(list.phrases.count == 3)
        var snapshot = FollowSnapshot()
        snapshot.status = .waiting
        snapshot.voicePhrase = 1
        let waiting = PromptViewModel(phase: .running, snapshot: snapshot, route: route(out: .bluetoothA2DP), setup: summary)
        let given = list.phrases[1].phrase.tokens.map(\.text)
        let ahead = list.phrases[2].phrase.tokens.map(\.text)
        #expect(waiting.phrase.map(\.text) == given + ahead)
        #expect(waiting.phrase.map(\.isAhead) == given.map { _ in false } + ahead.map { _ in true })

        // Speaking, only the phrase.
        snapshot.status = .speaking
        let speaking = PromptViewModel(phase: .running, snapshot: snapshot, route: route(out: .bluetoothA2DP), setup: summary)
        #expect(speaking.phrase.map(\.text) == given)
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

    private func screen(_ status: FollowStatus, estimate: Double = -1, voicePhrase: Int? = nil, voiceWord: Int? = nil,
                        mode: TakeMode = .screen, phase: TakeHost.Phase = .running) -> PromptViewModel {
        var snapshot = FollowSnapshot()
        snapshot.status = status
        snapshot.presenterEstimate = estimate
        snapshot.presenterPlace = estimate
        snapshot.presenterWord = Int(estimate.rounded(.down))
        snapshot.voicePhrase = voicePhrase
        snapshot.voiceWord = voiceWord
        var setup = setup
        setup.mode = mode
        setup.screenWords = ScreenText.words(phraseList: setup.phraseList, firstWord: setup.firstWord)
        return PromptViewModel(phase: phase, snapshot: snapshot, route: route(out: .builtInSpeaker), setup: setup)
    }

    @Test func theScreenShowsWhileTheTakeRunsWithTheScreenOn() {
        #expect(screen(.reading).showsScreen)
        #expect(screen(.idle, phase: .gettingReady).showsScreen)
        #expect(!screen(.finished, phase: .finished(.completed)).showsScreen)
        #expect(!screen(.idle, phase: .failed("No mic")).showsScreen)
        #expect(!screen(.speaking, mode: .ear).showsScreen)
        #expect(screen(.speaking, mode: .both).showsScreen)
    }

    @Test func beforeFollowingEveryWordWaits() {
        let model = screen(.tones)
        #expect(model.screenTokens.allSatisfy { $0.isWaiting })
        #expect(!model.screenTokens.contains { $0.isMark(2) || $0.isPassed(mark: 2) })
        #expect(model.place == -1)
        #expect(screen(.reading).status == "Reading")
    }

    @Test func thePresentersPlaceIsMarkedAndWhatTheyPassedDimmed() {
        // Words: We(0) follow(1) the(2) footpath.(3) [Point] Down(4) to(5) three hundred(6) boats.(7)
        let model = screen(.reading, estimate: 2.6)
        let tokens = model.screenTokens
        #expect(tokens.filter { $0.isMark(2) }.map(\.word.text) == ["the"])
        #expect(tokens.filter { $0.isPassed(mark: 2) }.map(\.word.text) == ["We", "follow"])
        #expect(!tokens.contains { $0.isMark(nil) || $0.isPassed(mark: nil) })
        #expect(!tokens.contains { $0.inVoicePhrase })
        #expect(model.place == 2.6)
        #expect(model.confident == 2)
    }

    @Test func aCueIsNeverMarkedPassedOrLit() {
        let tokens = screen(.speaking, estimate: 6, voicePhrase: 1, mode: .both).screenTokens
        let cue = tokens.first { $0.word.isCue }
        #expect(cue?.word.text == "[Point]")
        #expect(cue?.isPassed(mark: 6) == false)
        #expect(cue?.isMark(6) == false)
        #expect(cue?.inVoicePhrase == false)
    }

    @Test func withTheVoiceItsPhraseIsLitAndItsWordMarked() {
        let tokens = screen(.speaking, estimate: 1, voicePhrase: 2, voiceWord: 5, mode: .both).screenTokens
        #expect(tokens.filter { $0.inVoicePhrase }.map(\.word.text) == ["Down", "to", "three hundred", "boats."])
        #expect(tokens.filter { $0.isVoiceWord }.map(\.word.text) == ["to"])
        // Waiting, the phrase stays lit and no word is being said.
        let waiting = screen(.waiting, estimate: 1, voicePhrase: 2, voiceWord: 7, mode: .both).screenTokens
        #expect(waiting.filter { $0.inVoicePhrase }.count == 4)
        #expect(!waiting.contains { $0.isVoiceWord })
        // On the screen alone, nothing is lit.
        #expect(!screen(.reading, estimate: 1, voicePhrase: 2, voiceWord: 5).screenTokens.contains { $0.inVoicePhrase })
    }

    @Test func lostAndHeldStillFollow() {
        #expect(screen(.lost, estimate: 3).screenTokens.filter { $0.isMark(3) }.map(\.word.text) == ["footpath."])
        #expect(screen(.held, estimate: 3).place == 3)
        #expect(screen(.held, estimate: 3).diagnostics != nil)
    }
}
