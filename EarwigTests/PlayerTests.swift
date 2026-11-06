import AVFoundation
@testable import Earwig
import Testing

/// Records what the player asks of the audio, and lets a test end a buffer or set a position.
@MainActor
final class FakeOutput: PlayerOutput {
    struct Played {
        var channel: AudioChannel
        var frames: AVAudioFrameCount
        var delay: TimeInterval
        var speed: Double
    }

    var played: [Played] = []
    var stopped: [AudioChannel] = []
    var positions: [AudioChannel: TimeInterval] = [:]
    var speed = 1.0
    var outputLatency: TimeInterval = 0.2
    private var completions: [AudioChannel: @MainActor () -> Void] = [:]

    func play(_ buffer: AVAudioPCMBuffer, on channel: AudioChannel, delay: TimeInterval, completion: @escaping @MainActor () -> Void) throws {
        played.append(Played(channel: channel, frames: buffer.frameLength, delay: delay, speed: speed))
        completions[channel] = completion
        positions[channel] = 0
    }

    func stop(_ channel: AudioChannel) {
        stopped.append(channel)
        completions[channel] = nil
        positions[channel] = nil
    }

    func position(of channel: AudioChannel) -> TimeInterval? { positions[channel] }

    /// The channel's buffer has been heard to its end, as the real engine reports it.
    func end(_ channel: AudioChannel) {
        let completion = completions.removeValue(forKey: channel)
        positions[channel] = nil
        completion?()
    }
}

@MainActor
struct PlayerTests {

    private let output = FakeOutput()
    /// Phrases: 0 spoken (1 s), 1 a cue (0.5 s), 2 spoken (2 s).
    private let audio = TakeAudio(
        phrases: [
            TakeAudio.Phrase(kind: .spoken, buffer: silence(seconds: 1)),
            TakeAudio.Phrase(kind: .cue, buffer: silence(seconds: 0.5)),
            TakeAudio.Phrase(kind: .spoken, buffer: silence(seconds: 2)),
        ],
        slate: silence(seconds: 1.5),
        tones: silence(seconds: Tones.duration)
    )

    private func player() -> (Player, Events) {
        let player = Player(output: output, audio: audio)
        let events = Events()
        player.onEvent = { events.list.append($0) }
        return (player, events)
    }

    final class Events {
        var list: [FollowEvent] = []
    }

    private let rate = VoiceRenderer.outputFormat.sampleRate

    @Test func aSpokenPhrasePlaysOnTheVoiceAtTheEnginesSpeed() {
        let (player, events) = player()
        player.handle(.play(phrase: 2, speed: 1.1))
        #expect(output.played.last?.channel == .voice)
        #expect(output.played.last?.speed == 1.1)
        #expect(output.played.last?.frames == AVAudioFrameCount(2 * rate))
        output.end(.voice)
        #expect(events.list == [.phraseEnded(2)])
        #expect(player.current == nil)
    }

    @Test func aCuePhrasePlaysOnTheCueChannelAndKeepsTheSpeed() {
        let (player, events) = player()
        output.speed = 1.1
        player.handle(.play(phrase: 1, speed: 1.0))
        #expect(output.played.last?.channel == .cue)
        #expect(output.speed == 1.1)
        output.end(.cue)
        #expect(events.list == [.phraseEnded(1)])
    }

    @Test func setSpeedChangesTheVoice() {
        let (player, _) = player()
        player.handle(.play(phrase: 0, speed: 1.0))
        player.handle(.setSpeed(0.9))
        #expect(output.speed == 0.9)
    }

    @Test func stopVoiceStopsBothAndNoEndIsReported() {
        let (player, events) = player()
        player.handle(.play(phrase: 0, speed: 1.0))
        player.handle(.stopVoice)
        #expect(output.stopped.contains(.voice) && output.stopped.contains(.cue))
        output.end(.voice)
        #expect(player.progress() == nil)
        // The slate too: it is on the cue channel.
        player.handle(.playCue(.slate))
        player.handle(.stopVoice)
        output.end(.cue)
        #expect(events.list.isEmpty)
    }

    @Test func aNewPhraseStopsTheOneBeforeOnTheOtherChannel() {
        let (player, events) = player()
        player.handle(.play(phrase: 1, speed: 1.0))
        player.handle(.play(phrase: 2, speed: 1.0))
        output.end(.cue)
        #expect(events.list.isEmpty)
        output.end(.voice)
        #expect(events.list == [.phraseEnded(2)])
    }

    @Test func theSlateAndTones() {
        let (player, events) = player()
        player.handle(.playCue(.slate))
        #expect(output.played.last?.channel == .cue)
        #expect(output.played.last?.frames == AVAudioFrameCount(1.5 * rate))
        output.end(.cue)
        player.handle(.playTones)
        #expect(output.played.last?.channel == .tone)
        #expect(output.played.last?.delay == Player.toneLeadIn)
        output.end(.tone)
        #expect(events.list == [.cueEnded, .tonesEnded])
    }

    @Test func withNoSlateItEndsAtOnce() {
        let player = Player(output: output, audio: TakeAudio(phrases: audio.phrases, slate: nil, tones: audio.tones))
        var events: [FollowEvent] = []
        player.onEvent = { events.append($0) }
        player.handle(.playCue(.slate))
        #expect(events == [.cueEnded])
    }

    @Test func progressIsWhereTheVoiceIsHeard() {
        let (player, _) = player()
        player.handle(.play(phrase: 2, speed: 1.0))
        output.positions[.voice] = 0.1
        #expect(player.progress() == .voiceProgress(phrase: 2, offset: 0))
        output.positions[.voice] = 1.0
        #expect(player.progress() == .voiceProgress(phrase: 2, offset: 0.8))
        // At 1.2x the latency covers more of the rendering.
        player.handle(.setSpeed(1.2))
        guard case .voiceProgress(2, let offset)? = player.progress() else {
            Issue.record("no progress")
            return
        }
        #expect(abs(offset - 0.76) < 1e-9)
    }

    @Test func aCuePhrasesProgressIgnoresTheSpeed() {
        let (player, _) = player()
        output.speed = 1.2
        player.handle(.play(phrase: 1, speed: 1.0))
        output.positions[.cue] = 0.4
        guard case .voiceProgress(1, let offset)? = player.progress() else {
            Issue.record("no progress")
            return
        }
        #expect(abs(offset - 0.2) < 1e-9)
    }

    @Test func nothingIsReportedWhenIdle() {
        let (player, _) = player()
        #expect(player.progress() == nil)
        player.handle(.playTones)
        #expect(player.progress() == nil)
        player.handle(.play(phrase: 9, speed: 1))
        #expect(output.played.count == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func theTonesPlayThroughTheRealEngine() async throws {
        let host = AudioEngineHost()
        let tones = try #require(Tones.buffer())
        let player = Player(output: host, audio: TakeAudio(phrases: [], slate: nil, tones: tones))
        let started = HostClock.now
        await withCheckedContinuation { continuation in
            player.onEvent = { event in
                if event == .tonesEnded { continuation.resume() }
            }
            // A failure to play is only logged; end the wait on it rather than at the time limit.
            player.onLog = { message in
                Issue.record("\(message)")
                continuation.resume()
            }
            player.handle(.playTones)
        }
        #expect(HostClock.now - started >= Tones.duration - 0.05)
        host.stop()
    }
}
