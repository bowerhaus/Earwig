# Progress

Scratch state for the plan in flight. Overwritten at the start of a plan, emptied to a stub when it completes.

Mode: autopilot (/plan_autopilot)

**Plan:** `plans/011-first-release.md`, issue #22, branch `first-release` (from `main` at `9c2a4aa`).
**Manual test:** device (store migration, samples, a take on the Pier) and Andy's README review on GitHub.

The Weekend Loaf and The Old Watermill texts are on Andy's phone only; read them off its store with the `devicectl device copy from` command in the plan's Context.

## Checklist

- [x] 1. Samples' texts
- [x] 2. Model and seeder
- [x] 3. Paste rules
- [x] 4. Scripts screen
- [x] 5. Version and licence
- [x] 6. Screenshots, banner and diagrams (simulator shots done; script.png and voice-take.png come from the phone at the device check, then rerun scripts/readme/make_readme_images.py)
- [x] 7. README
- [x] Tests + lint
- [x] Review + fixes (recorded in the plan; issue comment on #22)
- [ ] Manual test: device checks and README review (device checks 1 to 3 and the look check passed, Andy, 2026-11-09; all six screenshots taken; next the README review on GitHub, which needs the branch pushed)
- [ ] Complete (commit + PR)
- [ ] 10. The release, after the PR merges (Andy's yes for each push)

## Notes
- Licence wording (Andy, 2026-11-09): current files, the issue comment, the PR body and the release notes state the licence only, never that it changed, the old one, or the alternatives weighed. PRD v0.2's Document History row drops its licence words at the PRD update. Before the first push, squash this branch's commits so no pushed commit carries the plan's earlier wording.
