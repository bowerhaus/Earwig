# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

**Plan:** 004, renderer and player (`plans/004-renderer-player.md`), stage 4 of PRD §12.
**Mode:** autopilot (`/plan_autopilot`): build, test, review, stop only for the manual test or a real decision, then complete with a PR. Merging is Andy's.
**Branch:** `renderer-player`, from `main` at `a382ac8`. Pushed.
**Issue:** #11 (the PR closes it).
**Manual test:** on the iPhone 14 Pro with the SK18 (plan's Verification: render, Listen, highlight, locked).

## Checklist

- [x] 1. Renderer: `ScriptRenderer` (in-memory, by voice, rate and text), `VoiceCatalogue`, tests
- [x] 2. Timings and slate: `PhraseTiming(rendered:)`, `Slate`, tests
- [x] 3. Tones and player: `Tones`, `AudioEngineHost` nodes, `Player`, tests
- [x] 4. Screen: rendering row, render on open and on a new start step, Listen sheet
- [x] Tests + lint
- [x] Review + fixes (pass and outcome in the plan; comment on #11)
- [ ] Manual test: device check on the iPhone 14 Pro (one check at a time)
- [ ] Complete (Results, PRD v0.6, commit + PR)

## Notes

- Built: `ScriptRenderer`, `VoiceCatalogue`, `Slate`, `Tones`, `PhraseTiming(phrase:tokenStarts:duration:)`, `AudioEngineHost` (voice, cue, tone channels; `PlayerOutput`), `Player`, `StepPreview`, the rendering row and `ListenView`. 187 tests pass, SwiftLint clean.
- Slate signature changed for SwiftLint's parameter count: `Slate.text(number:shotID:take:directions:)`, `directions` nil with cues off.
- Debug flag `-EarwigListen YES` (with `-EarwigDemo YES`) opens Listen once the start step is ready, for the simulator.
- Review: 7 code, 10 test findings, none critical; all fixed except T6 (skipped) and C3/T3 in part. 188 tests pass.
- Simulator (Daniel compact): step 1 renders 10 phrases, 21.7 s of audio in 0.7 s, 74 of 74 words timed (delegate markers). Listen runs slate, tones, all phrases; next phrase starts < 0.5 ms after an end; ends arrive about 145 ms after the audio length; output latency 10 ms on the speaker.


**Next:** manual test on the iPhone 14 Pro, one check at a time (plan's Verification 1–4). Build c1c96ae is installed; launched with `devicectl ... process launch --console` in the background, log in the session scratchpad. Check 1 (Render) handed to Andy; waiting for his verdict. Then checks 2 (Listen), 3 (Highlight), 4 (Locked), Results, PRD v0.6, PR.

## Device results so far (iPhone 14 Pro, SK18)

- Bug found at check 1: iOS 27 puts the quality in a voice's name ("Stephanie (Enhanced)"), so Stephanie was not found and Jamie was used. Fixed in daa1aac (`VoiceInfo.baseName`); en-GB voices now logged at launch.
- Check 1 Render: PASS (Andy: "It all looks good to me"). Voices: presenter Stephanie (Enhanced), cue Jamie (Premium). Step 1: 10 phrases, 22.4 s of audio in 1.12 s, 74 of 74 words timed, markers from both, 22,050 Hz source. Step 2: 8 phrases, 19.5 s in 0.35 s, 76 of 76 timed. Step 1 again: nothing rendered.
- From Andy's early Listen on the Jamie build: output latency 356 ms on the SK18 (333 ms route + 23 ms buffer); phrase 1 ended 547 ms after its length.
- Check 2 Listen (step 1, cues on): ran through. Andy: directions are recognisable by the change of voice; doesn't like the voices much; a spoken inline direction pauses the performance (about 1.35 s for "Gesture to the boats", about 1.9 s with the end delay), "not sure this is a workable solution". Pause after each line "sounded okay", "maybe the pauses at the commas were slightly too long". Console: every phrase end arrived about 520 ms (433–533) after its length; next phrase started 0.3 ms after. Fixed in 3898cee: completion on `.dataRendered`, not `.dataPlayedBack`; phrase silences now logged. To recheck by ear.
- Open decision for Andy: how inline directions reach him in a take (proposed: read them in the slate before the take, a short chime at the point, spoken in place as an option off by default).
- Andy: inline directions should be a setting, spoken or a soft chime. Built in 2efb77a: `InlineDirections` (chime default, spoken), in the script's ••• menu until Settings (stage 7); in chime mode the slate reads the step's inline directions by where they fall ("At “Most of these boats”, gesture to the boats."), and Listen plays a 0.15 s chime at the point.
- Andy's Personal Voice is ready. Added in c6af737: a Voice picker in the ••• menu (Personal Voices once allowed, then Enhanced-or-better English voices) and Allow Personal Voice. A Personal Voice is never the default or the cue voice. To try on the phone: render speed, word markers, quality (open question 6).
- Next: on the phone, recheck the comma gaps, hear both direction modes, then Personal Voice; then checks 3 (highlight) and 4 (locked).
- Personal Voice (open question 6), tried by Andy through the SK18 and the phone speaker: "The voice quality is actually terrible. It sounds like some cross between me and the built-in voices." It "takes longer to render, and it's really not worth it." He would rather put the effort into a better built-in voice, a voice from another source, or his own reading as recorded. Console: Andy's Personal Voice rendered step 1's 9 spoken phrases, 16.8 s of audio in 7.33 s (about 2.3 times real time, against Stephanie's 20), 70 of 70 words timed, markers from both, 48 kHz source. Verdict: not used; PRD to drop it as the first choice.
- Comma-gap fix confirmed in the console: phrase ends now arrive 68–91 ms after their length (were 433–533). Chime mode ran: the 0.15 s chime as phrase 8, the slate reading "At “Most of these boats”, gesture to the boats."
- Check A (Stephanie, chime): comma pauses "do sound right". Overall speed "a little fast"; at 0.85x "seemed more normal"; unsure whether it holds in a real take (left for stage 5, where the engine paces; base rate is a stage 7 setting). Chime "noticeable", but he would rather "an elongated low ping or pong". The direction read in the slate: "If there were several directions, it would be difficult to remember them"; remove it.
- Changed: the chime is a low pong (D4 with two partials, 0.8 s, ringing on the tone channel) and the voice waits only 0.25 s for it (`TakeAudio.Phrase.ring`); inline directions no longer read in the slate.
- The low pong: "much better", "could possibly be slightly louder" (amplitude 0.14 to 0.2, about −14 dBFS). Check 3 Highlight: "everything looks good" (Andy; the console logs only the speed a Listen starts at, 1.0x).
- Andy: the Paste button should be the accent yellow, not "goldy brown". iOS darkens a `PasteButton`'s tint to keep its forced white text legible (dark text and a light scheme were both ignored). Andy chose our own yellow button: `AccentPill` reading `UIPasteboard`, which asks "Allow Paste?" until Settings › Apps › Earwig › Paste from Other Apps is Allow. PRD §4.1 (PasteButton, no prompt) to update.
