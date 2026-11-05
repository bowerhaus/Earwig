import AVFoundation
import Observation
import Speech
import UIKit

/// The spike screen's state and actions (plan 001). Deleted with the spike; what is worth
/// keeping lives in Services.
@MainActor
@Observable
final class SpikeModel {

    // MARK: Voices

    struct VoiceOption: Identifiable, Hashable {
        let id: String
        let name: String
        let language: String
        let quality: String
        let isPersonal: Bool
        let sortRank: Int
    }

    private(set) var voices: [VoiceOption] = []
    var showAllLanguages = false { didSet { loadVoices() } }
    private(set) var personalVoiceStatus = "not asked"
    var selectedVoiceID: String?
    /// `AVSpeechUtterance` rate, 0.5 is the default.
    var rate: Float = 0.5

    // MARK: Script and rendering

    var scriptText = ""
    private(set) var phrases: [Phrase] = []
    private(set) var renders: [RenderedPhrase] = []
    private(set) var renderProgress: Double?
    private(set) var renderSummary = ""
    /// Index of each phrase's first word in the flat normalised script.
    private(set) var phraseStarts: [Int] = []
    private(set) var scriptWords: [String] = []

    // MARK: Playback

    enum Mode: String, CaseIterable, Identifiable {
        case gated = "Gated"
        case through = "Straight through"
        var id: String { rawValue }
    }

    enum PlayState: Equatable {
        case idle
        case speaking(Int)
        case waiting(Int)
        case finished
    }

    var mode: Mode = .gated
    /// Words: the next phrase starts when the heard position is within this many words of
    /// the end of the current one.
    var lead = 3
    var speed: Double = 1.0 { didSet { audio.speed = Float(speed) } }
    private(set) var playState: PlayState = .idle
    private(set) var voicePosition = -1

    // MARK: Listening

    var fastResults = true
    var scriptAsContext = true
    private(set) var heardPosition = -1
    private(set) var accuracy: Double?
    private(set) var heardCount = 0
    private(set) var medianDelay: Double?
    private(set) var p90Delay: Double?
    private(set) var medianFinalDelay: Double?
    private(set) var inputLevel: Float = 0
    private(set) var marks: [String] = []
    private(set) var heardTail: [HeardWord] = []

    // MARK: Route watch

    private(set) var watchStartedAt: Date?
    private(set) var everHandsFree = false
    private(set) var everNotBuiltInMic = false
    private(set) var routeChanges = 0

    // MARK: Log

    private(set) var log: [String] = []

    // MARK: Services

    let session = AudioSessionManager()
    let audio = AudioEngineHost()
    let listener: Listener
    private let renderer = VoiceRenderer()
    private var follower = SpikeFollower(script: [])
    private var waitStartedAt: Date?
    private var pollTask: Task<Void, Never>?
    private var renderTask: Task<Void, Never>?

    init() {
        listener = Listener(audio: audio)
        session.onEvent = { [weak self] in self?.routeEvent($0) }
        session.onInterruption = { [weak self] began in
            if began { self?.stop(reason: "interruption") }
        }
        listener.onEvent = { [weak self] in self?.note($0) }
        listener.onWordsChanged = { [weak self] in self?.heardChanged($0) }
        NotificationCenter.default.addObserver(forName: AVSpeechSynthesizer.availableVoicesDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.loadVoices() }
        }
        loadVoices()
        note("spike started on \(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)")
    }

    func onAppear() async {
        let granted = await session.requestMicrophone()
        note("microphone \(granted ? "granted" : "denied")")
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        note("speech recognition authorisation: \(Self.describe(speech))")
        do { try session.configure() } catch {}
        watchStartedAt = Date()
        await listener.checkAssets()
        note("speech assets (\(listener.localeIdentifier)): \(listener.assetStatus)")
        startPolling()
    }

    // MARK: - Voices

    func requestPersonalVoice() async {
        let status = await AVSpeechSynthesizer.requestPersonalVoiceAuthorization()
        personalVoiceStatus = Self.describe(status)
        note("Personal Voice authorisation: \(personalVoiceStatus)")
        loadVoices()
    }

    func loadVoices() {
        personalVoiceStatus = Self.describe(AVSpeechSynthesizer.personalVoiceAuthorizationStatus)
        let installed = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            showAllLanguages || voice.language.hasPrefix("en") || voice.voiceTraits.contains(.isPersonalVoice)
        }
        let options = installed.map(Self.option(for:))
        voices = options.sorted { a, b in
            if a.sortRank != b.sortRank { return a.sortRank < b.sortRank }
            let aBritish = a.language == "en-GB"
            let bBritish = b.language == "en-GB"
            if aBritish != bBritish { return aBritish }
            return a.name < b.name
        }
        if selectedVoiceID == nil || !voices.contains(where: { $0.id == selectedVoiceID }) {
            selectedVoiceID = voices.first?.id
        }
    }

    private static func option(for voice: AVSpeechSynthesisVoice) -> VoiceOption {
        let personal = voice.voiceTraits.contains(.isPersonalVoice)
        let quality: String
        let rank: Int
        switch voice.quality {
        case .premium: (quality, rank) = ("Premium", 1)
        case .enhanced: (quality, rank) = ("Enhanced", 2)
        default: (quality, rank) = ("Default (poor)", 3)
        }
        return VoiceOption(id: voice.identifier, name: voice.name, language: voice.language,
                           quality: personal ? "Personal Voice" : quality, isPersonal: personal, sortRank: personal ? 0 : rank)
    }

    var selectedVoice: VoiceOption? { voices.first { $0.id == selectedVoiceID } }

    // MARK: - Rendering

    func render() {
        guard renderTask == nil else { return }
        guard let id = selectedVoiceID, let voice = AVSpeechSynthesisVoice(identifier: id) else {
            note("no voice selected")
            return
        }
        stop(reason: "re-render")
        let spoken = SpikeScriptCleaner.spokenText(from: scriptText)
        phrases = PhraseSplitter().phrases(in: spoken)
        var starts: [Int] = []
        var words: [String] = []
        for phrase in phrases {
            starts.append(words.count)
            words += phrase.normalisedWords
        }
        phraseStarts = starts
        scriptWords = words
        follower = SpikeFollower(script: words)
        renders = []
        renderSummary = ""
        guard !phrases.isEmpty else {
            note("nothing to render")
            return
        }
        note("rendering \(phrases.count) phrases, \(words.count) words, voice \(voice.name) (\(selectedVoice?.quality ?? "")), rate \(String(format: "%.2f", rate))")
        renderTask = Task { [weak self] in
            await self?.renderAll(voice: voice)
            self?.renderTask = nil
        }
    }

    func cancelRender() {
        renderTask?.cancel()
        renderer.cancel()
    }

    private func renderAll(voice: AVSpeechSynthesisVoice) async {
        let started = Date()
        renderProgress = 0
        for (index, phrase) in phrases.enumerated() {
            if Task.isCancelled { break }
            do {
                let rendered = try await renderer.render(phrase, index: index, voice: voice, rate: rate)
                renders.append(rendered)
                logRender(rendered)
            } catch {
                note("render p\(index + 1) failed: \(error.localizedDescription)")
                break
            }
            renderProgress = Double(index + 1) / Double(phrases.count)
        }
        renderProgress = nil
        let wall = Date().timeIntervalSince(started)
        let audioSeconds = renders.reduce(0) { $0 + $1.duration }
        let renderSeconds = renders.reduce(0) { $0 + $1.renderSeconds }
        let timed = renders.reduce(0) { $0 + $1.tokenStarts.compactMap { $0 }.count }
        let tokens = renders.reduce(0) { $0 + $1.phrase.tokens.count }
        renderSummary = String(format: "%d/%d phrases, %.1f s audio in %.1f s (RTF %.2f), %d/%d words timed by markers",
                               renders.count, phrases.count, audioSeconds, renderSeconds, audioSeconds > 0 ? renderSeconds / audioSeconds : 0, timed, tokens)
        note("render done in \(String(format: "%.1f", wall)) s wall: \(renderSummary)")
    }

    private func logRender(_ r: RenderedPhrase) {
        let markers = r.tokenStarts.map { $0.map { String(format: "%.2f", $0) } ?? "–" }.joined(separator: " ")
        let delegate = r.delegateTokenTimes.map { $0.map { String(format: "%.2f", $0) } ?? "–" }.joined(separator: " ")
        note(String(format: "render p%d: %.2f s for %.2f s audio (RTF %.2f), %@, markers from %@ as %@ “%@”\n  marker starts: %@\n  delegate wall: %@",
                    r.phraseIndex + 1, r.renderSeconds, r.duration, r.realTimeFactor, r.sourceFormat, r.markerSource, r.markerUnit.rawValue, r.phrase.text, markers, delegate))
    }

    /// Seconds per script word for the rendered voice, to show the lead in seconds.
    var secondsPerWord: Double? {
        let words = renders.reduce(0) { $0 + $1.phrase.normalisedWords.count }
        let seconds = renders.reduce(0) { $0 + $1.duration }
        return words > 0 ? seconds / Double(words) : nil
    }

    // MARK: - Take

    var canStart: Bool { !renders.isEmpty && renders.count == phrases.count }

    func startTake() async {
        guard canStart else { return }
        if !session.isConfigured { try? session.configure() }
        if listener.state != .listening {
            await listener.start(contextWords: scriptAsContext ? Array(Set(scriptWords)).sorted() : nil, fastResults: fastResults)
        } else {
            listener.clearWords()
        }
        audio.speed = Float(speed)
        heardPosition = -1
        note("take started: mode \(mode.rawValue), lead \(lead) words, speed \(String(format: "%.2f", speed)), route \(session.route.summary)")
        play(0)
    }

    func stop(reason: String = "stop") {
        guard playState != .idle else { return }
        audio.stopPhrase()
        playState = .idle
        voicePosition = -1
        note("take stopped (\(reason))\(statsLine)")
    }

    func stopListening() async {
        stop(reason: "listening stopped")
        await listener.stop()
    }

    func startListening() async {
        if !session.isConfigured { try? session.configure() }
        await listener.start(contextWords: scriptAsContext && !scriptWords.isEmpty ? Array(Set(scriptWords)).sorted() : nil, fastResults: fastResults)
    }

    /// Releases a waiting gate by hand, for when recognition has lost the presenter.
    func releaseGate() {
        guard case .waiting(let index) = playState else { return }
        note("gate after p\(index + 1) released by hand")
        play(index + 1)
    }

    private func play(_ index: Int) {
        guard index < renders.count else {
            playState = .finished
            note("take finished\(statsLine)")
            return
        }
        do {
            try audio.play(renders[index].buffer) { [weak self] in self?.phraseFinished(index) }
            playState = .speaking(index)
        } catch {
            note("play p\(index + 1) failed: \(error.localizedDescription)")
            playState = .idle
        }
    }

    private func phraseFinished(_ index: Int) {
        guard playState == .speaking(index) else { return }
        if index + 1 >= renders.count {
            playState = .finished
            note("take finished\(statsLine)")
            return
        }
        playState = .waiting(index)
        waitStartedAt = Date()
        checkGate()
    }

    private func phraseEnd(_ index: Int) -> Int {
        index + 1 < phraseStarts.count ? phraseStarts[index + 1] - 1 : scriptWords.count - 1
    }

    private func checkGate() {
        guard case .waiting(let index) = playState else { return }
        let target = phraseEnd(index) - lead
        guard mode == .through || heardPosition >= target else { return }
        let waited = waitStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        if mode == .gated {
            note(String(format: "gate after p%d released: heard %d ≥ %d, waited %.2f s", index + 1, heardPosition, target, waited))
        }
        play(index + 1)
    }
}

extension SpikeModel {

    // MARK: - Heard words

    private func heardChanged(_ words: [HeardWord]) {
        let previousCount = heardCount
        let normalised = words.flatMap { WordNormaliser.normaliseToken($0.text) }
        let result = follower.follow(normalised)
        heardPosition = result.position
        accuracy = result.accuracy
        heardCount = words.count
        heardTail = Array(words.suffix(14).reversed())
        let delays = words.map(\.delay).filter { $0 > -1 && $0 < 30 }.sorted()
        medianDelay = Self.percentile(delays, 0.5)
        p90Delay = Self.percentile(delays, 0.9)
        medianFinalDelay = Self.percentile(words.compactMap(\.finalDelay).filter { $0 > -1 && $0 < 30 }.sorted(), 0.5)
        if words.count > previousCount, let last = words.last {
            let position = heardPosition >= 0 && heardPosition < scriptWords.count ? scriptWords[heardPosition] : "–"
            note(String(format: "heard “%@” delay %.2f s%@, position %d (%@)", last.text, last.delay, last.isFinal ? " final" : "", heardPosition, position))
        }
        checkGate()
    }

    // MARK: - Marks

    /// The presenter taps as they say a word; three seconds later the heard word nearest the
    /// tap is logged with its computed spoken time and its delay from the tap.
    func mark() {
        let tap = HostClock.now
        let number = marks.count + 1
        marks.insert("mark \(number): waiting…", at: 0)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            self?.resolveMark(number, tap: tap)
        }
    }

    private func resolveMark(_ number: Int, tap: TimeInterval) {
        let line: String
        if let word = listener.words.min(by: { abs($0.spokenAt - tap) < abs($1.spokenAt - tap) }), abs(word.spokenAt - tap) < 1.5 {
            line = String(format: "mark %d: “%@” computed spoken at tap %+.2f s, first heard tap %+.2f s", number, word.text, word.spokenAt - tap, word.firstHeardAt - tap)
        } else {
            line = "mark \(number): no word heard within 1.5 s of the tap"
        }
        if let index = marks.firstIndex(of: "mark \(number): waiting…") { marks[index] = line }
        note(line)
    }

    // MARK: - Route

    private func routeEvent(_ message: String) {
        routeChanges += message.hasPrefix("route change") ? 1 : 0
        if session.route.isHandsFree { everHandsFree = true }
        if !session.route.inputIsBuiltInMic, session.isConfigured { everNotBuiltInMic = true }
        note(message)
    }

    func resetWatch() {
        watchStartedAt = Date()
        everHandsFree = session.route.isHandsFree
        everNotBuiltInMic = !session.route.inputIsBuiltInMic
        routeChanges = 0
        note("route watch reset: \(session.route.summary)")
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.poll()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func poll() {
        inputLevel = listener.inputLevel
        guard case .speaking(let index) = playState, let position = audio.phrasePosition, index < renders.count else { return }
        let render = renders[index]
        var token = 0
        for (offset, start) in render.tokenStarts.enumerated() where (start ?? .infinity) <= position { token = offset }
        voicePosition = phraseStarts[index] + render.phrase.tokens.prefix(token).reduce(0) { $0 + $1.normalised.count }
    }

    // MARK: - Log

    func note(_ message: String) {
        log.append("\(Self.clock.string(from: Date())) \(message)")
    }

    func clearLog() {
        log = []
        note("log cleared")
    }

    var logText: String {
        let header = [
            "Earwig plan 001 spike log",
            "voice: \(selectedVoice.map { "\($0.name) (\($0.quality), \($0.language))" } ?? "none"), rate \(String(format: "%.2f", rate))",
            "render: \(renderSummary)",
            "mode \(mode.rawValue), lead \(lead), speed \(String(format: "%.2f", speed)), fast results \(fastResults), script context \(scriptAsContext)",
            "route now: \(session.route.summary); ever hands-free: \(everHandsFree); ever not built-in mic: \(everNotBuiltInMic); route changes: \(routeChanges)",
            "listening:\(statsLine)",
            "",
        ]
        return (header + log).joined(separator: "\n")
    }

    private var statsLine: String {
        let fmt: (Double?) -> String = { $0.map { String(format: "%.2f s", $0) } ?? "–" }
        return " heard \(heardCount) words, median delay \(fmt(medianDelay)), p90 \(fmt(p90Delay)), median to final \(fmt(medianFinalDelay)), accuracy \(accuracy.map { String(format: "%.0f%%", $0 * 100) } ?? "–")"
    }

    // MARK: - Helpers

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func percentile(_ sorted: [Double], _ p: Double) -> Double? {
        guard !sorted.isEmpty else { return nil }
        let index = min(sorted.count - 1, max(0, Int((Double(sorted.count - 1) * p).rounded())))
        return sorted[index]
    }

    private static func describe(_ status: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "not asked"
        case .denied: "denied"
        case .unsupported: "unsupported on this device"
        case .authorized: "authorised"
        @unknown default: "unknown"
        }
    }

    private static func describe(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "not asked"
        case .denied: "denied"
        case .restricted: "restricted"
        case .authorized: "authorised"
        @unknown default: "unknown"
        }
    }
}

/// Pulls the spoken text out of a pasted script for the spike: drops Markdown headings and
/// Cutaway's `Shows:`, `Footage:` and `Open:` fields, strips `Says:` and list markers, and
/// removes bracketed directions. The real parser (PRD §4.1) is stage 2.
enum SpikeScriptCleaner {
    static func spokenText(from text: String) -> String {
        text.components(separatedBy: .newlines).compactMap { raw -> String? in
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") { return nil }
            for field in ["Shows:", "Footage:", "Open:"] where line.hasPrefix(field) { return nil }
            if line.hasPrefix("Says:") { line = String(line.dropFirst(5)) }
            if line.hasPrefix("- ") || line.hasPrefix("* ") { line = String(line.dropFirst(2)) }
            line = line.replacingOccurrences(of: #"\[[^\]]*\]|\([^)]*\)"#, with: "", options: .regularExpression)
            line = line.replacingOccurrences(of: "*", with: "")
            line = line.trimmingCharacters(in: .whitespaces)
            return line.isEmpty ? nil : line
        }.joined(separator: "\n")
    }
}
