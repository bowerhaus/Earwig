# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

## State (2026-11-05)

- **Plan 002 (skeleton, models, parser) is drafted** in `plans/002-skeleton-models-parser.md`, on branch `skeleton-models-parser` (from `main` at `6d2b848`). No code yet; no issue yet.
- Plan 001 is complete (PASS, PR #2, issue #1 closed; PRD v0.3). The project builds clean, SwiftLint is clean, 17 tests pass.
- The plan follows Cutaway's own parser (`../Cutaway/pipeline/script.py`, `../Cutaway/docs/file-contracts.md`, "The script"), leniently.

## Next action: Andy reviews the plan

1. Andy reviews plan 002, in particular its four **Questions for review** (square brackets as inline directions; re-paste by title; numbers as one script word now, compounds and contractions in stage 3; dark only). Fold his answers into the plan's design decisions.
2. Then `/plan_create_issue` (needs his yes), and put the issue number in the plan's header.
3. Then `/plan_autopilot` is recommended: the stage is pure Swift and unit-testable in the simulator, with one short device check at step 7 (paste a real Cutaway script by Universal Clipboard).

## Reminders

- The repo is public: fixtures and examples are made-up scripts, never Andy's unpublished ones. The harbour walk is in commit `7cb9880`, `Earwig/Spike/SpikeSampleScript.swift`.
- Commit locally at sensible points without asking. Pushing, a PR and an issue each need Andy's yes.
- Install on the iPhone with `devicectl` (CLAUDE.md, Build Commands), never via Xcode.
