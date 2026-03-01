# FAC-68 Handoff Notes

## Summary
Implemented the v0.3 release-readiness checklist and smoke matrix as a dedicated docs page, wired it into ExDoc/package metadata, and linked the checklist path from the parent gate issue (FAC-61).

## What Changed
- Created and filled `.agent/plans/FAC-68.md` with required planning sections.
- Added new canonical checklist page:
  - `RELEASE_READINESS.md`
  - Includes owner, checklist path, gate checklist, required smoke matrix, command-level execution sequence, and failure-state rollback/retest actions.
- Updated docs discoverability in source docs:
  - `README.md` now links to `RELEASE_READINESS.md` in a dedicated release-readiness section.
- Updated package/docs metadata so checklist ships with package docs:
  - `mix.exs` `package.files` now includes `RELEASE_READINESS.md`.
  - `mix.exs` `docs.extras` now includes `RELEASE_READINESS.md`.
- Added parent ticket checklist-path link in Linear:
  - FAC-61 comment id: `fbe835b3-d826-47bf-abe7-355fe37b1a67`
  - Includes repo path `RELEASE_READINESS.md` and branch link.

## Scope Decisions Captured
- Checklist source of truth is `RELEASE_READINESS.md` at repo root.
- Smoke coverage is command-first and maps directly to existing test files for: catalog, registry, permissions, bindings, and partial streaming.
- Parent-link acceptance is satisfied via explicit FAC-61 comment linking checklist path.

## Validation
- `mix format` (pass)
- `mix format --check-formatted` (pass)
- `mix compile --warnings-as-errors` (fails in this sandbox: `Mix.PubSub.Subscriber` socket open `:eperm`)
- `MIX_PUBSUB=0 mix compile --warnings-as-errors` (same `:eperm` failure)
- `MIX_PUBSUB=0 mix test` (same `:eperm` failure)

## Notes for Next Agent/Reviewer
- Compile/test failures are environment-level Mix PubSub socket restrictions in this sandbox, not code-level failures from FAC-68 changes.
- If you need to re-verify full gate checks outside this sandbox, rerun the exact command sequence in `RELEASE_READINESS.md` under `Command Execution Steps`.
