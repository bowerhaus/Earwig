import Foundation

/// The follow engine (PRD §5, plan 003): words heard and the player's position in, commands to
/// the player out. A value-type state machine with time passed in on every call, so the same
/// inputs always give the same commands. The host calls `tick(at:)` about ten times a second.
///
/// The player's contract: after `stopVoice` it sends no more progress or end for the phrase it
/// stopped; it reports `voiceProgress` as it plays and `phraseEnded` when a phrase is done.
struct FollowEngine: Sendable {
    let script: FollowScript
    let settings: FollowSettings
    /// The slate's words as they would be heard: the step number or shot ID, "take", the take
    /// number. Used by `.slateWithReply`.
    let slateWords: [ScriptWord]

    private let matcher: Matcher
    private var estimate: PresenterEstimate
    private var pacer: Pacer

    private enum Phase: Equatable {
        case idle
        case slateCue
        case slateReply(since: TimeInterval)
        case slateGap(until: TimeInterval)
        case tones
        case following
        case finished
    }

    private enum Voice: Equatable {
        case idle
        case playing(Int)
        /// Waiting to play this phrase when its gate opens.
        case waiting(Int)
        /// Finished the last phrase at this time.
        case done(TimeInterval)
    }

    private enum Reason {
        case stepBack, ahead, found, release
    }

    private var phase: Phase = .idle
    private var voice: Voice = .idle
    private var held = false
    /// Where the presenter was estimated to be when Hold was pressed: the place shown while
    /// held, so the text stays still (plan 008, decisions 1 and 4).
    private var heldPlace: Double?
    /// The phrase the voice last started, when, and the word it is saying.
    private var voicePhrase: Int?
    private var voiceStartedAt: TimeInterval?
    private var voiceWord: Int?

    /// The matcher's state at the last final, and with the current interim block on top.
    private var settled = MatchState()
    private var current = MatchState()
    /// When each word of the current interim block first appeared, by its place in the block.
    private var blockStamps: [TimeInterval] = []
    private var lastFinalAt: TimeInterval?
    /// Heard words from before these times are not followed (the slate, or before a manual move).
    private var ignoreHeardBefore = -TimeInterval.infinity
    private var ignoreSpokenBefore = -TimeInterval.infinity
    /// Slate words heard in finals, and with the current interim block on top.
    private var slateSettled: Set<Int> = []
    private var slateHeard: Set<Int> = []

    private var outcome: FollowOutcome?
    private var lastError: Double?
    private var now: TimeInterval = 0

    init(script: FollowScript, settings: FollowSettings = FollowSettings(), slateWords: [ScriptWord] = []) {
        self.script = script
        self.settings = settings
        self.slateWords = slateWords
        matcher = Matcher(words: script.words, settings: settings)
        estimate = PresenterEstimate(settings: settings)
        pacer = Pacer(settings: settings)
    }

    // MARK: - Input

    mutating func handle(_ event: FollowEvent, at time: TimeInterval) -> [FollowCommand] {
        now = time
        var commands: [FollowCommand]
        switch event {
        case .interim(let text): commands = heardInterim(text)
        case .final(let words): commands = heardFinal(words)
        case .voiceProgress, .phraseEnded, .cueEnded, .tonesEnded: commands = player(event)
        default: commands = control(event)
        }
        commands += advance()
        return commands
    }

    /// What the player reports.
    private mutating func player(_ event: FollowEvent) -> [FollowCommand] {
        switch event {
        case let .voiceProgress(phrase, offset):
            if voice == .playing(phrase), let word = script.word(in: phrase, at: offset) { voiceWord = word }
        case .phraseEnded(let phrase):
            guard voice == .playing(phrase) else { break }
            voiceWord = script.lastWord(of: phrase) ?? voiceWord
            voice = phrase + 1 < script.phrases.count ? .waiting(phrase + 1) : .done(now)
            pacer.pause()
        case .cueEnded:
            guard phase == .slateCue else { break }
            phase = settings.start == .slateWithReply ? .slateReply(since: now) : .slateGap(until: now + settings.slateGap)
        case .tonesEnded:
            guard phase == .tones else { break }
            phase = .following
            voice = settings.voiced ? .waiting(0) : .idle
        default:
            break
        }
        return []
    }

    /// Start, the tap and the manual controls.
    private mutating func control(_ event: FollowEvent) -> [FollowCommand] {
        switch event {
        case .start: return begin()
        case .tap: return tap()
        case .hold: return toggleHold()
        case .back: return move(by: -1)
        case .forward: return move(by: 1)
        case .restart: return isRunning ? stopping() + startTones() : []
        case .stop: return isRunning ? stopping() + finish(.stopped) : []
        default: return []
        }
    }

    private var isRunning: Bool { phase != .idle && phase != .finished }

    /// Stops whatever is playing, for Restart and Stop.
    private func stopping() -> [FollowCommand] {
        if case .playing = voice { return [.stopVoice] }
        return phase == .slateCue ? [.stopVoice] : []
    }

    /// Time-based rules: the slate's pause, speed, gates and the end.
    mutating func tick(at time: TimeInterval) -> [FollowCommand] {
        now = time
        var commands: [FollowCommand] = []
        if case .slateGap(let until) = phase, now >= until { commands += startTones() }
        // Speed follows the presenter only once they have been heard.
        if phase == .following, !held, current.confidentAt != nil,
           case .playing(let phrase) = voice, script.phrases[phrase].kind == .spoken, let word = voiceWord {
            let error = Pacer.error(voice: word, presenter: presenterNow(), lead: settings.lead)
            lastError = error
            if let speed = pacer.update(error: error, at: now) { commands.append(.setSpeed(speed)) }
        } else {
            lastError = nil
        }
        commands += advance()
        return commands
    }

    // MARK: - Output

    var snapshot: FollowSnapshot {
        var snapshot = FollowSnapshot()
        snapshot.status = status
        switch voice {
        case .playing(let phrase): snapshot.voicePhrase = phrase
        case .waiting(let phrase): snapshot.voicePhrase = max(phrase - 1, 0)
        case .done: snapshot.voicePhrase = script.phrases.count - 1
        case .idle: snapshot.voicePhrase = nil
        }
        snapshot.voiceWord = voiceWord
        snapshot.presenterWord = current.confident
        snapshot.presenterEstimate = heldPlace ?? presenterNow()
        snapshot.confident = current.run >= (current.lost ? settings.lostRun : settings.run) && current.sinceMatch == 0
        snapshot.speed = pacer.speed
        snapshot.error = lastError
        snapshot.delay = estimate.delay
        snapshot.rate = estimate.rate
        snapshot.outcome = outcome
        return snapshot
    }

    private var status: FollowStatus {
        switch phase {
        case .idle: return .idle
        case .slateCue, .slateReply, .slateGap: return .slate
        case .tones: return .tones
        case .finished: return .finished
        case .following:
            if held { return .held }
            if current.lost { return .lost }
            if !settings.voiced { return .reading }
            if case .playing = voice { return .speaking }
            return .waiting
        }
    }

    // MARK: - Hearing

    private mutating func heardInterim(_ text: String) -> [FollowCommand] {
        let words = ScriptWords.words(in: text)
        var stamps = Array(blockStamps.prefix(words.count))
        stamps += Array(repeating: now, count: words.count - stamps.count)
        blockStamps = stamps
        let heard = zip(words, stamps).map { HeardScriptWord(word: $0, heardAt: $1) }

        if case .slateReply(let since) = phase { return heardSlate(heard, since: since) }
        guard phase == .following else { return [] }
        let previous = current
        current = matcher.align(heard.filter { $0.heardAt >= ignoreHeardBefore }, from: settled, prefixLast: true)
        return afterHearing(previous)
    }

    private mutating func heardFinal(_ words: [FinalWord]) -> [FollowCommand] {
        var heard: [HeardScriptWord] = []
        var followed: [HeardScriptWord] = []
        var starts: [TimeInterval] = []
        let groups = ScriptWords.groups(words.map(\.text)).filter { $0.word != nil }
        for (index, group) in groups.enumerated() {
            guard let word = group.word else { continue }
            let start = words[group.tokens.lowerBound].start
            let stamp = index < blockStamps.count ? blockStamps[index] : now
            if index < blockStamps.count, stamp >= start { estimate.recordDelay(stamp - start) }
            starts.append(start)
            let heardWord = HeardScriptWord(word: word, heardAt: stamp)
            heard.append(heardWord)
            if start >= ignoreSpokenBefore { followed.append(heardWord) }
        }
        estimate.recordFinalStarts(starts)
        blockStamps = []
        lastFinalAt = now

        if case .slateReply(let since) = phase {
            let commands = heardSlate(heard, since: since)
            slateSettled = slateHeard
            return commands
        }
        guard phase == .following else { return [] }
        let previous = current
        settled = matcher.align(followed, from: settled, prefixLast: false)
        current = settled
        return afterHearing(previous)
    }

    /// Steps back, jumps ahead or picks up again when the presenter's confident position says so.
    private mutating func afterHearing(_ previous: MatchState) -> [FollowCommand] {
        guard !held else { return [] }
        if previous.lost && !current.lost { return reanchor(.found) }
        guard current.confident >= 0 else { return [] }
        // A step back is newly heard words matching behind, not a rewrite of words already heard
        // that breaks a run (which leaves the confident word one heard earlier).
        if current.confident <= previous.confident - settings.stepBackWords,
           (current.confidentAt ?? -.infinity) > (previous.confidentAt ?? -.infinity) {
            return reanchor(.stepBack)
        }
        if let word = voiceWord, current.confident > word, voice != .idle { return reanchor(.ahead) }
        return []
    }

    // MARK: - Following

    /// Where the presenter is estimated to be now. For a gate, the coast stops at the end of the
    /// phrase they were last confidently heard in (plan 006, decision 5); pacing and the snapshot
    /// keep the free coast, so the voice is not slowed at every phrase crossing (review C2).
    private func presenterNow(atGate: Bool = false) -> Double {
        // Never past what the voice has given: the end of the phrase it plays, or the word
        // before the phrase it waits to play (which, after a re-anchor, is not the phrase it
        // last started).
        var cap: Int?
        switch voice {
        case .playing(let phrase): cap = script.lastWord(of: phrase) ?? script.firstWord[phrase] - 1
        case .waiting(let next): cap = script.firstWord[next] - 1
        case .done: cap = script.lastSpokenWord
        case .idle: cap = settings.voiced ? nil : script.lastSpokenWord
        }
        let start = voicePhrase.map { script.firstWord[$0] }
        let boundary = atGate ? script.phrase(containing: current.confident).map { script.range(of: $0).upperBound } : nil
        let pausedSince = lastFinalAt.map { (current.confidentAt ?? -.infinity) <= $0 } ?? false
        let basis = PresenterEstimate.Basis(
            confident: current.confident,
            confidentAt: current.confidentAt,
            afterFinal: pausedSince || current.confidentAt == nil,
            offScript: current.lost || current.sinceMatch >= 2,
            voicePhraseStart: start,
            voiceStartedAt: voiceStartedAt,
            cap: cap,
            boundary: boundary
        )
        return estimate.position(basis, lead: settings.lead, at: now)
    }

    /// Re-anchoring (plan 003, decision 11): the voice stops and queues the first phrase the
    /// presenter has not begun, released by the usual gate.
    private mutating func reanchor(_ reason: Reason) -> [FollowCommand] {
        guard phase == .following else { return [] }
        guard let target = script.firstPhrase(after: current.confident) else { return finishVoice(reason) }
        // Once re-anchored, the phrase the voice last started says nothing of where the presenter
        // is: without this, a step back into an earlier phrase was taken as following the
        // stopped one, and the gate after it opened at once (plan 005, device check 4).
        switch voice {
        case .playing(let phrase):
            guard Self.stops(playing: phrase, for: target, reason) else { return [] }
            voice = .waiting(target)
            voiceStartedAt = nil
            pacer.pause()
            return [.stopVoice]
        case .waiting(let next):
            if Self.moves(waiting: next, to: target, reason) {
                voice = .waiting(target)
                voiceStartedAt = nil
            }
        case .done:
            if reason == .stepBack || reason == .found {
                voice = .waiting(target)
                voiceStartedAt = nil
            }
        case .idle:
            break
        }
        return []
    }

    /// The presenter is in the last phrase, so there is nothing to queue: ahead of the voice,
    /// found there or released from Hold, the voice stops and is finished. A step back within
    /// the last phrase leaves it playing, as it is still ahead.
    private mutating func finishVoice(_ reason: Reason) -> [FollowCommand] {
        guard reason != .stepBack else { return [] }
        switch voice {
        case .playing:
            voice = .done(now)
            pacer.pause()
            return [.stopVoice]
        case .waiting:
            voice = .done(now)
        case .done, .idle:
            break
        }
        return []
    }

    /// Whether a playing phrase stops for a re-anchor: a step back to it or before it, the
    /// presenter ahead, found elsewhere, or Hold released.
    private static func stops(playing phrase: Int, for target: Int, _ reason: Reason) -> Bool {
        switch reason {
        case .stepBack: return target <= phrase
        case .ahead, .release: return true
        case .found: return target <= phrase || target > phrase + 1
        }
    }

    /// Whether a waiting voice queues the target instead of its next phrase.
    private static func moves(waiting next: Int, to target: Int, _ reason: Reason) -> Bool {
        switch reason {
        case .stepBack: return target < next
        case .ahead: return target > next
        case .found, .release: return target != next
        }
    }

    /// Gates and the end of the take, after anything that may have moved them.
    private mutating func advance() -> [FollowCommand] {
        guard phase == .following, !held else { return [] }
        guard settings.voiced else { return isCompleteReading ? finish(.completed) : [] }
        if case .waiting(let next) = voice {
            guard next < script.phrases.count else {
                voice = .done(now)
                return []
            }
            if gateIsOpen(next) { return startPhrase(next) }
        }
        if case .done(let at) = voice, isComplete(voiceDoneAt: at) { return finish(.completed) }
        return []
    }

    /// The voice starts a phrase, at 1.0x.
    private mutating func startPhrase(_ phrase: Int) -> [FollowCommand] {
        voice = .playing(phrase)
        voicePhrase = phrase
        voiceStartedAt = now
        if script.phrases[phrase].kind == .spoken { voiceWord = script.firstWord[phrase] }
        pacer.reset(at: now)
        return [.play(phrase: phrase, speed: 1)]
    }

    /// A phrase plays when the presenter is within the lead of the end of the spoken phrase
    /// before it, the end counted as the boundary after its last word, so that a released
    /// phrase starts exactly a lead ahead (with the last word as the end it started a lead and
    /// one ahead, and the simulated clean read ran 1.5 words over the lead). A spoken phrase
    /// straight after a cue follows the cue.
    private func gateIsOpen(_ phrase: Int) -> Bool {
        if script.phrases[phrase].kind == .spoken, phrase > 0, script.phrases[phrase - 1].kind == .cue { return true }
        guard let gating = script.gatingPhrase(before: phrase), let last = script.lastWord(of: gating) else { return true }
        return presenterNow(atGate: true) >= Double(last + 1 - settings.lead)
    }

    /// The take completes when the last word is heard, or, with the presenter in the last spoken
    /// phrase, a while after both the voice finished and they were last heard there: the
    /// recogniser may miss the last words, but a presenter who comes back to the last phrase
    /// long after the voice is not cut off at its first word (device check 6 of plan 005).
    private func isComplete(voiceDoneAt: TimeInterval) -> Bool {
        guard let last = script.lastSpokenWord, let lastPhrase = script.phrase(containing: last) else { return true }
        if current.confident >= last { return true }
        let since = max(voiceDoneAt, current.confidentAt ?? voiceDoneAt)
        return now - since >= settings.endGrace && current.confident >= script.firstWord[lastPhrase]
    }

    private mutating func finish(_ outcome: FollowOutcome) -> [FollowCommand] {
        phase = .finished
        voice = .idle
        held = false
        heldPlace = nil
        self.outcome = outcome
        return [.finished(outcome)]
    }
}

// MARK: - Start and manual controls

extension FollowEngine {

    // MARK: - Start

    private mutating func begin() -> [FollowCommand] {
        guard phase == .idle else { return [] }
        switch settings.start {
        case .slateWithReply, .slate:
            phase = .slateCue
            return [.playCue(.slate)]
        case .tonesOnly:
            return startTones()
        }
    }

    private mutating func tap() -> [FollowCommand] {
        switch phase {
        case .slateCue: return [.stopVoice] + startTones()
        case .slateReply, .slateGap: return startTones()
        default: return []
        }
    }

    /// The tones, then phrase 1. What was heard before them (the slate) is not followed.
    private mutating func startTones() -> [FollowCommand] {
        phase = .tones
        voice = .idle
        held = false
        heldPlace = nil
        voicePhrase = nil
        voiceStartedAt = nil
        voiceWord = nil
        settled = MatchState()
        current = settled
        lastFinalAt = nil
        ignoreSpokenBefore = now
        ignoreHeardBefore = now + estimate.delay
        pacer.reset(at: now)
        pacer.pause()
        return [.playTones]
    }

    private mutating func heardSlate(_ heard: [HeardScriptWord], since: TimeInterval) -> [FollowCommand] {
        slateHeard = slateSettled
        for word in heard where word.heardAt >= since {
            if let index = slateWords.indices.first(where: { !slateHeard.contains($0) && WordFolding.match(word.word, slateWords[$0]) != nil }) {
                slateHeard.insert(index)
            }
        }
        let needed = min(settings.slateWordsNeeded, slateWords.count)
        return slateHeard.count >= needed && needed > 0 ? startTones() : []
    }

    // MARK: - Manual controls

    private mutating func toggleHold() -> [FollowCommand] {
        guard phase == .following else { return [] }
        if held {
            held = false
            heldPlace = nil
            return reanchor(.release)
        }
        // The place shown is kept while held, so the text stays still, and released to
        // wherever the presenter has been heard since (plan 008, decision 4; review C1).
        heldPlace = presenterNow()
        held = true
        pacer.pause()
        if case .playing(let phrase) = voice {
            voice = .waiting(phrase)
            return [.stopVoice]
        }
        return []
    }

    /// Back or Forward a phrase: the voice plays it now, and the presenter is taken to be at its
    /// start until they are heard again. With nothing heard the voice then waits at the next
    /// gate, as it would for a presenter who has stopped. Forward from the last phrase does
    /// nothing: there is no next phrase (device check 5 of plan 005, where it played the last
    /// one again).
    private mutating func move(by offset: Int) -> [FollowCommand] {
        guard phase == .following, !script.phrases.isEmpty else { return [] }
        guard settings.voiced else { return moveReading(by: offset) }
        var commands: [FollowCommand] = []
        let at: Int
        switch voice {
        case .playing(let phrase): at = phrase
        case .waiting(let next): at = max(next - 1, 0)
        case .done: at = script.phrases.count - 1
        case .idle: at = 0
        }
        guard at + offset < script.phrases.count else { return [] }
        if case .playing = voice { commands.append(.stopVoice) }
        let target = max(at + offset, 0)
        held = false
        settled = MatchState(last: script.firstWord[target] - 1, confident: script.firstWord[target] - 1)
        current = settled
        ignoreHeardBefore = now
        ignoreSpokenBefore = now - estimate.delay
        return commands + startPhrase(target)
    }

    /// With no voice, Back or Forward moves the presenter's place a spoken phrase from the one
    /// they are in (the phrase of the next word they will say), taken to be at its start until
    /// they are heard again. Cues are passed over, as there is nothing in them to read. Forward
    /// from the last spoken phrase does nothing (plan 008, decision 1).
    private mutating func moveReading(by offset: Int) -> [FollowCommand] {
        let spoken = script.phrases.indices.filter { script.phrases[$0].kind == .spoken && !script.phrases[$0].words.isEmpty }
        guard let lastWord = script.lastSpokenWord, !spoken.isEmpty else { return [] }
        let next = min(max(current.confident + 1, 0), lastWord)
        guard let inPhrase = script.phrase(containing: next), let at = spoken.firstIndex(of: inPhrase) else { return [] }
        guard at + offset < spoken.count else { return [] }
        let target = spoken[max(at + offset, 0)]
        held = false
        heldPlace = nil
        settled = MatchState(last: script.firstWord[target] - 1, confident: script.firstWord[target] - 1)
        current = settled
        ignoreHeardBefore = now
        ignoreSpokenBefore = now - estimate.delay
        return []
    }

    /// With no voice, the take completes when the last word is heard, or with the presenter in
    /// the last spoken phrase and not heard there for `endGrace` (plan 008, decision 1).
    private var isCompleteReading: Bool {
        guard let last = script.lastSpokenWord, let lastPhrase = script.phrase(containing: last) else { return true }
        if current.confident >= last { return true }
        guard current.confident >= script.firstWord[lastPhrase], let at = current.confidentAt else { return false }
        return now - at >= settings.endGrace
    }
}
