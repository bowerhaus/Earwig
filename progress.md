# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

## Plan 001: voice, earpiece and recognition spike

Branch `voice-earpiece-recognition-spike`. Issue: drafted, not yet created (needs Andy's yes).

**Done:** project, CLAUDE.md, lint; services (AudioSessionManager, VoiceRenderer, AudioEngineHost, Listener, PhraseSplitter, WordNormaliser); spike screen in `Earwig/Spike/`. Builds clean, SwiftLint clean, tests pass. Simulator check recorded in the plan's Results.

**Next:** Andy's device trial (below), then Results and Outcome in the plan, PRD v0.3, delete the spike UI.

## Device trial checklist

Install from Xcode on the iPhone 14 Pro (scheme Earwig, his device, Run). First launch asks for the mic and speech recognition. Earpiece paired and in.

1. **Voices.** Tap Ask for Personal Voice. Pick Personal Voice, paste a real script (any length; two minutes is the test), Render. Note the render summary (RTF). Start take in *Straight through*: judge it. Repeat for Jamie (Premium) and Stephanie (Enhanced). Try the speed slider at 0.85x and 1.2x.
2. **Earpiece.** With Listen on and a take playing, watch the Route section: output should say A2DP, input built-in mic. Note any red warning. Sound quality by ear.
3. **Mic hears earpiece?** Stay silent during a straight-through take: does anything appear under Listen?
4. **Recognition, mount.** Phone on the mount near the camera. Listen, read the script aloud (no playback needed). Note median delay, p90, accuracy. Use the Mark button on a few words.
5. **Recognition, pocket.** Same, phone in a pocket (screen locked). Outdoors if possible.
6. **Locked ten minutes.** Reset route watch, start a gated take, lock the screen, speak along for about ten minutes. Afterwards: did audio and recognition keep going? Ever hands-free / off built-in mic?
7. **Lead.** Gated mode, speak behind the voice; try leads 1 to 5. Which felt right?

After each part: Share log (AirDrop to the Mac) or paste the numbers, and give the verdicts.
