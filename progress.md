# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

## State (2026-11-05)

- **Plan 002 (skeleton, models, parser) is drafted** in `plans/002-skeleton-models-parser.md`, on branch `skeleton-models-parser` (from `main` at `6d2b848`). Reviewed by Andy; issue [#3](https://github.com/bowerhaus/Earwig/issues/3). No code yet. The branch is pushed to origin.
- Plan 001 is complete (PASS, PR #2, issue #1 closed; PRD v0.3). The project builds clean, SwiftLint is clean, 17 tests pass.
- The plan follows Cutaway's own parser (`../Cutaway/pipeline/script.py`, `../Cutaway/docs/file-contracts.md`, "The script"), leniently.

## Next action: build plan 002

1. Andy's review is folded in: decisions 4, 5 and 8 agreed; decision 11 is now one distinctive theme, not necessarily dark, with no light and dark variants, picked by Andy from candidates in step 6.
2. `/plan_autopilot` is recommended: pure Swift and unit-testable in the simulator. It pauses for the palette pick (step 6) and the device paste check (step 7).
3. The PR must include "Closes #3".

## Reminders

- The repo is public: fixtures and examples are made-up scripts, never Andy's unpublished ones. The harbour walk is in commit `7cb9880`, `Earwig/Spike/SpikeSampleScript.swift`.
- Commit locally at sensible points without asking. Pushing, a PR and an issue each need Andy's yes.
- Install on the iPhone with `devicectl` (CLAUDE.md, Build Commands), never via Xcode.
