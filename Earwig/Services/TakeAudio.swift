import AVFoundation

/// A take's audio, loaded before it starts: the step's phrases by phrase index, the slate and
/// the tones (plan 004, decision 9).
struct TakeAudio {
    struct Phrase {
        var kind: PhraseKind
        var buffer: AVAudioPCMBuffer
        /// A sound started with the phrase on the tone channel and left to ring on past its end:
        /// the chime for a direction, whose `buffer` is then the short hold the voice waits for.
        var ring: AVAudioPCMBuffer? = nil
    }

    var phrases: [Phrase]
    var slate: AVAudioPCMBuffer?
    var tones: AVAudioPCMBuffer
}

extension TakeAudio {
    /// A step's script with its rendering's timings, and its audio without the slate, as Listen
    /// and a take play it (plan 005, step 3). Chimed, a direction is the chime, ringing on under
    /// the next line, and the voice waits only for its hold.
    static func build(phraseList: PhraseList, rendered: [RenderedPhrase], inline: InlineDirections) throws -> (script: FollowScript, audio: TakeAudio) {
        guard let tones = Tones.buffer(), let chime = Tones.Chime.buffer(), let hold = Tones.Chime.holdBuffer() else {
            throw VoiceRenderer.RenderError.conversion
        }
        let chimed = inline == .chime
        let script = FollowScript(phraseList: phraseList) { index in
            if chimed, phraseList.phrases[index].kind == .cue { return PhraseTiming(wordStarts: [], duration: Tones.Chime.hold) }
            return PhraseTiming(phrase: rendered[index].phrase, tokenStarts: rendered[index].tokenStarts, duration: rendered[index].duration)
        }
        let audio = TakeAudio(
            phrases: zip(phraseList.phrases, rendered).map { stepPhrase, rendered in
                chimed && stepPhrase.kind == .cue
                    ? TakeAudio.Phrase(kind: .cue, buffer: hold, ring: chime)
                    : TakeAudio.Phrase(kind: stepPhrase.kind, buffer: rendered.buffer)
            },
            slate: nil,
            tones: tones
        )
        return (script, audio)
    }
}
