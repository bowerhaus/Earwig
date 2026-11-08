@testable import Earwig
import Foundation

// A take on a fake clock (plan 003, decision 15): a presenter who speaks, a recogniser that
// hears them late and writes numbers and compounds its own way, and a player that plays what
// the engine asks. Made-up text only: the repo is public.

/// Plays phrases at the commanded speed from their word timings and reports as a player would.
struct SimulatedPlayer {
    let script: FollowScript
    var cueLength: TimeInterval = 1.5
    var tonesLength: TimeInterval = 1.5

    private(set) var phrase: Int?
    private(set) var offset: TimeInterval = 0
    private(set) var speed = 1.0
    private var nextWord = 0
    private var cueEndsAt: TimeInterval?
    private var tonesEndAt: TimeInterval?

    /// Every time the voice began each word, by flat index.
    private(set) var said: [Int: [TimeInterval]] = [:]
    /// Each play command, with its time.
    private(set) var plays: [(time: TimeInterval, phrase: Int)] = []
    private(set) var speeds: [Double] = [1]
    private(set) var stops = 0
    /// Seconds the voice was silent between spoken phrases once under way.
    private(set) var silences: [TimeInterval] = []
    private var silentSince: TimeInterval?

    init(script: FollowScript) {
        self.script = script
    }

    /// The word the voice is saying, as a flat index.
    var word: Int? {
        guard let phrase, nextWord > 0 else { return nil }
        return script.firstWord[phrase] + nextWord - 1
    }

    var isSpeakingAPhrase: Bool { phrase.map { script.phrases[$0].kind == .spoken } ?? false }

    mutating func apply(_ command: FollowCommand, at time: TimeInterval) {
        switch command {
        case let .play(phrase, speed):
            if let since = silentSince, !plays.isEmpty { silences.append(time - since) }
            silentSince = nil
            self.phrase = phrase
            self.speed = speed
            offset = 0
            nextWord = 0
            plays.append((time, phrase))
            speeds.append(speed)
        case .setSpeed(let speed):
            self.speed = speed
            speeds.append(speed)
        case .stopVoice:
            if phrase != nil { stops += 1 }
            phrase = nil
            cueEndsAt = nil
            silentSince = time
        case .playTones:
            tonesEndAt = time + tonesLength
        case .playCue:
            cueEndsAt = time + cueLength
        case .finished:
            phrase = nil
        }
    }

    mutating func advance(to time: TimeInterval, by step: TimeInterval) -> [FollowEvent] {
        var events: [FollowEvent] = []
        if let end = cueEndsAt, time >= end {
            cueEndsAt = nil
            events.append(.cueEnded)
        }
        if let end = tonesEndAt, time >= end {
            tonesEndAt = nil
            events.append(.tonesEnded)
        }
        guard let phrase else { return events }
        offset += step * speed
        let starts = script.phrases[phrase].wordStarts
        while nextWord < starts.count, starts[nextWord] <= offset {
            said[script.firstWord[phrase] + nextWord, default: []].append(time)
            nextWord += 1
        }
        if offset >= script.phrases[phrase].duration {
            self.phrase = nil
            silentSince = time
            events.append(.phraseEnded(phrase))
        } else {
            events.append(.voiceProgress(phrase: phrase, offset: offset))
        }
        return events
    }
}

/// What the presenter does, in order.
enum PresenterAct {
    /// Read these script words. A reactive presenter says a word only once the voice has.
    case read(ClosedRange<Int>)
    /// Read these script words from memory, whatever the voice does.
    case recite(ClosedRange<Int>)
    /// Say words that are not in the script.
    case say([String])
    case pause(TimeInterval)
    /// Go straight on from the last word, without its phrase-end pause.
    case runOn
}

/// Speaks at a steady rate, behind the voice, pausing at phrase ends.
struct SimulatedPresenter {
    struct Word {
        let script: Int?
        let reactive: Bool
        let text: String
        var pauseAfter: TimeInterval
    }

    struct Spoken {
        let word: Word
        let start: TimeInterval
        let end: TimeInterval
    }

    var rate = 2.5
    /// How long after the voice begins a word the presenter can say it.
    var reaction: TimeInterval = 0.3
    var phrasePause: TimeInterval = 0.6
    /// How long a reactive presenter waits for the voice before going on from memory.
    var patience: TimeInterval = 6

    private var queue: [Word] = []
    private var index = 0
    private var nextAt = TimeInterval.infinity
    private(set) var spoken: [Spoken] = []
    /// Times the presenter was ready to speak but waited for the voice, once under way.
    private(set) var waits: [(at: TimeInterval, length: TimeInterval)] = []
    /// The last script word begun.
    private(set) var position = -1

    init(script: FollowScript, acts: [PresenterAct], rate: Double = 2.5) {
        self.rate = rate
        let phraseEnds = Set(script.phrases.indices.compactMap { script.lastWord(of: $0) })
        for act in acts {
            switch act {
            case .read(let range), .recite(let range):
                var reactive = false
                if case .read = act { reactive = true }
                for word in range {
                    let text = script.words[word].number.map(String.init) ?? script.words[word].text
                    queue.append(Word(script: word, reactive: reactive, text: text, pauseAfter: phraseEnds.contains(word) ? phrasePause : 0))
                }
            case .say(let words):
                queue += words.map { Word(script: nil, reactive: false, text: $0, pauseAfter: 0) }
            case .pause(let length):
                if !queue.isEmpty { queue[queue.count - 1].pauseAfter += length }
            case .runOn:
                if !queue.isEmpty { queue[queue.count - 1].pauseAfter = 0 }
            }
        }
    }

    var isDone: Bool { index >= queue.count }

    /// The voice has started: the presenter may begin.
    mutating func begin(at time: TimeInterval) {
        if nextAt == .infinity { nextAt = time }
    }

    /// A word begun at this moment, if any.
    mutating func advance(to time: TimeInterval, voiceSaid: (Int) -> TimeInterval?) -> Spoken? {
        guard index < queue.count, time >= nextAt else { return nil }
        let word = queue[index]
        if word.reactive, let script = word.script {
            let heard = voiceSaid(script).map { time >= $0 + reaction } ?? false
            if !heard && time - nextAt < patience { return nil }
        }
        if !spoken.isEmpty, time - nextAt > 0.06 { waits.append((nextAt, time - nextAt)) }
        // A number of three digits or more is said as two words or more.
        let length = (word.text.count >= 3 && Int(word.text) != nil ? 2 : 1) / rate
        let said = Spoken(word: word, start: time, end: time + length)
        spoken.append(said)
        if let script = word.script { position = script }
        nextAt = time + length + word.pauseAfter
        index += 1
        return said
    }
}

/// Hears the presenter about 0.9 s late, in interim blocks with no times, and gives a final
/// with every word's start after each pause, as `SpeechTranscriber` does (plan 001 findings 2, 3).
struct SimulatedRecogniser {
    var delay: TimeInterval = 0.9
    /// How late the first word after a final appears; plan 001 saw up to 1.5 s.
    var firstAfterFinal: TimeInterval = 0.9
    var pauseForFinal: TimeInterval = 0.5
    var finalDelay: TimeInterval = 1.0
    /// The least time between interim results. On the phone they came in bursts about a second
    /// apart (plan 005, device check 4); 0 shows each change at once.
    var interimInterval: TimeInterval = 0
    /// How the recogniser writes a script word, by flat index: "seawall" for "sea" with ""
    /// for "wall" joins a compound; "" alone drops a word.
    var writes: [Int: String] = [:]

    private struct Item {
        let text: String
        let start: TimeInterval
        let end: TimeInterval
    }

    private var block: [Item] = []
    private var pending: [Item] = []
    private var blockFollowsFinal = false
    /// The interim text last shown, and when.
    private(set) var lastInterim = ""
    private var lastInterimAt = -TimeInterval.infinity

    mutating func hear(_ spoken: SimulatedPresenter.Spoken) {
        var text = spoken.word.text
        if let script = spoken.word.script, let written = writes[script] { text = written }
        guard !text.isEmpty else { return }
        let item = Item(text: text, start: spoken.start, end: spoken.end)
        if let last = block.last, item.start > last.end + pauseForFinal {
            pending.append(item)
        } else if pending.isEmpty {
            block.append(item)
        } else {
            pending.append(item)
        }
    }

    mutating func advance(to time: TimeInterval) -> [FollowEvent] {
        var events: [FollowEvent] = []
        if let last = block.last, time >= last.end + finalDelay, pending.first.map({ $0.start > last.end + pauseForFinal }) ?? true {
            var words: [FinalWord] = []
            for item in block {
                for (index, part) in item.text.split(separator: " ").enumerated() {
                    words.append(FinalWord(text: String(part), start: item.start + Double(index) * 0.2))
                }
            }
            events.append(.final(words))
            block = pending
            pending = []
            blockFollowsFinal = true
            lastInterim = ""
        }
        guard let first = block.first else { return events }
        let firstVisible = first.start + (blockFollowsFinal ? firstAfterFinal : delay)
        var shown: [String] = []
        for item in block {
            let visible = max(item.start + delay, firstVisible)
            guard time >= visible else { break }
            shown.append(Self.building(item.text, since: time - visible))
        }
        let text = shown.joined(separator: " ")
        if !text.isEmpty, text != lastInterim, time - lastInterimAt >= interimInterval {
            lastInterim = text
            lastInterimAt = time
            events.append(.interim(text))
        }
        return events
    }

    /// A number written in digits builds up: "18", then "189", then "1890".
    private static func building(_ text: String, since: TimeInterval) -> String {
        guard text.count >= 3, Int(text) != nil else { return text }
        let shown = min(text.count, 2 + Int(since / 0.15))
        return String(text.prefix(shown))
    }
}

/// Runs a take to its end and keeps what the scenarios measure.
struct TakeSimulation {
    var engine: FollowEngine
    var player: SimulatedPlayer
    var presenter: SimulatedPresenter
    var recogniser: SimulatedRecogniser
    let step: TimeInterval = 0.05

    private(set) var time: TimeInterval = 0
    private(set) var statuses: [FollowStatus] = []
    /// The voice's word less the presenter's, less the lead, while both are under way.
    private(set) var leadErrors: [(time: TimeInterval, error: Int)] = []
    /// What the engine knew when it released each phrase (plan 006, decision 4).
    struct Release {
        let phrase: Int
        /// The presenter estimate and confident word just before the release.
        let estimate: Double
        let confident: Int
        /// The last script word the presenter had begun, and the interim text last shown.
        let presenterAt: Int
        let heard: String
    }
    private(set) var releases: [Release] = []
    /// With no voice, the presenter estimate less the last word the presenter began, while they
    /// are reading (plan 008, decision 1).
    private(set) var placeErrors: [(time: TimeInterval, error: Double)] = []
    /// What the screen shows, smoothed from the estimate each step (plan 008, decision 3): its
    /// place less the last word the presenter began while reading, and every step it moved back.
    private(set) var screen = ScreenPlace()
    private(set) var screenErrors: [(time: TimeInterval, error: Double)] = []
    private(set) var screenBackSteps: [(time: TimeInterval, length: Double)] = []
    /// The screen's place at every step.
    private(set) var screenPlaces: [(time: TimeInterval, place: Double)] = []

    init(script: FollowScript, settings: FollowSettings = FollowSettings(), acts: [PresenterAct], rate: Double = 2.5, recogniser: SimulatedRecogniser = SimulatedRecogniser()) {
        var settings = settings
        settings.start = .tonesOnly
        engine = FollowEngine(script: script, settings: settings)
        player = SimulatedPlayer(script: script)
        presenter = SimulatedPresenter(script: script, acts: acts, rate: rate)
        self.recogniser = recogniser
    }

    var outcome: FollowOutcome? { engine.snapshot.outcome }

    mutating func run(for limit: TimeInterval = 240) {
        apply(engine.handle(.start, at: 0))
        while time < limit, outcome == nil {
            time += step
            var events = player.advance(to: time, by: step)
            let said = player.said
            if let spoken = presenter.advance(to: time, voiceSaid: { said[$0]?.first }) { recogniser.hear(spoken) }
            events += recogniser.advance(to: time)
            for event in events {
                // With no voice the presenter starts after the tones, from the script.
                if event == .tonesEnded, !engine.settings.voiced { presenter.begin(at: time + 0.3) }
                apply(engine.handle(event, at: time))
            }
            apply(engine.tick(at: time))
            measure()
        }
    }

    private mutating func apply(_ new: [FollowCommand]) {
        for command in new {
            if case .play(let phrase, _) = command {
                let snapshot = engine.snapshot
                releases.append(Release(phrase: phrase, estimate: snapshot.presenterEstimate, confident: snapshot.presenterWord,
                                        presenterAt: presenter.position, heard: recogniser.lastInterim))
            }
            player.apply(command, at: time)
            if case .play = command { presenter.begin(at: time) }
        }
    }

    private mutating func measure() {
        statuses.append(engine.snapshot.status)
        let reading = presenter.position >= 0 && presenter.spoken.last.map { $0.word.script != nil && time - $0.end < 0.7 } == true
        let shown = screen.place
        screen.step(toward: engine.snapshot.presenterPlace, confident: engine.snapshot.presenterWord,
                    paused: engine.snapshot.presenterPaused, at: time)
        if screen.place < shown - 0.001 { screenBackSteps.append((time, shown - screen.place)) }
        screenPlaces.append((time, screen.place))
        if reading { screenErrors.append((time, screen.place - Double(presenter.position))) }
        if !engine.settings.voiced {
            if reading { placeErrors.append((time, engine.snapshot.presenterEstimate - Double(presenter.position))) }
            return
        }
        guard player.isSpeakingAPhrase, let voice = player.word, presenter.position >= 0,
              let last = presenter.spoken.last, time - last.end < 0.7 else { return }
        leadErrors.append((time, voice - presenter.position - engine.settings.lead))
    }

    // MARK: - Measures

    /// Script words the voice said more than once, and never.
    var repeatedWords: [Int] { player.said.filter { $0.value.count > 1 }.keys.sorted() }
    var unsaidWords: [Int] { engine.script.words.indices.filter { player.said[$0] == nil } }
    var played: [Int] { player.plays.map(\.phrase) }
}

/// The scenarios' scripts.
enum SimulationScripts {
    /// The sample's step: the harbour walk, step 2 by default, made the engine's input. The
    /// voice says a word every `secondsPerWord` (2.5 words a second by default).
    static func harbour(step: Int, secondsPerWord: TimeInterval = 0.4) -> FollowScript {
        let parsed = ScriptParser.parse(SampleScript.harbourWalk)
        return FollowScript(phraseList: PhraseList(lines: parsed.steps[step].lines), secondsPerWord: secondsPerWord)
    }
}
