# FAC-70 Handoff Notes

## Summary
Completed the v0.3 migration/approval evidence package by adding a migration summary doc, updating changelog caveats/migration context, recording an explicit dated local-use approval statement, and linking the package in the parent gate issue (FAC-61).

## What Changed
- Created and filled `.agent/plans/FAC-70.md` with required planning sections.
- Added migration summary artifact:
  - `docs/v0.3_migration_notes.md`
  - Includes v0.2 baseline contract, v0.3 gate deltas, migration impact, and caveats.
- Added explicit approval artifact:
  - `docs/v0.3_local_use_approval.md`
  - Includes explicit approval statement + date (`2026-03-01`) for local-use stability scope.
- Updated release-readiness docs:
  - `RELEASE_READINESS.md`
  - Added `## FAC-70 Migration and Approval Package` with links to both artifacts and parent-gate target.
  - Added gate checklist item requiring FAC-70 artifacts to be linked in FAC-61.
- Updated changelog draft:
  - `CHANGELOG.md`
  - Added `#### Migration context and caveats` under `### v0.3 scope lock release draft`.
  - Clarifies non-breaking expectation for v0.2 core consumers and opt-in nature of v0.3 candidate paths.
- Added Linear evidence comments:
  - FAC-61 parent link comment id: `9214644f-251b-4a81-b5fe-8cdecd82534c`
  - FAC-70 implementation comment id: `b0ba7bb9-92d3-4492-8c46-5b5e12d23437`

## Validation
- `mix format --check-formatted` (pass)
- `MIX_PUBSUB=0 mix test` (fails in this sandbox: `Mix.PubSub.Subscriber` socket open `:eperm`)
- `mix compile --warnings-as-errors` (fails in this sandbox with same `Mix.PubSub` `:eperm`)
- `MIX_PUBSUB=0 mix compile --warnings-as-errors` (same `:eperm` failure)

## Notes for Next Agent/Reviewer
- FAC-70 acceptance criteria are covered by committed docs artifacts plus explicit parent-gate linkage comment on FAC-61.
- Compile/test failures in this environment are sandbox-level Mix PubSub socket restrictions, consistent with prior gate tickets.
