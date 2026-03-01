# FAC-78 Handoff Notes

## Summary
Added a canonical Make-based release sanity command and wired documentation around it.

## What Changed
- Added `release-check` target to `Makefile` that runs:
  - `mix json_liveview_render.check_metadata`
  - `mix format --check-formatted`
  - `mix compile --warnings-as-errors`
  - `MIX_PUBSUB=0 mix test`
  - `mix hex.publish --dry-run`
- Added `help` target in `Makefile` and included `release-check` in the discoverable output.
- Updated `README.md` release workflow to use `make release-check` as the canonical command.
- Documented stable exit behavior for `make release-check` (zero-only on full success, non-zero on first failure).

## Assumptions / Decisions
- Kept the command as a Make target for discoverability and explicit discoverability via `make help`, matching existing local tooling (`ci-local`/`ci-local-full`) style.
- Kept checks inline instead of creating a new wrapper script to avoid introducing extra release-tooling surface.
- `MIX_PUBSUB=0 mix test` is explicitly included to preserve CI-safe test execution semantics.

## Validation
- `Makefile` is intentionally minimal; no task orchestration logic introduced.
- Required checks before finishing:
  - `mix format --check-formatted`
  - `mix compile --warnings-as-errors`

## Notes for Next Agent
- If desired, we can add a dedicated section to CI docs explaining when to use `make release-check` versus `make ci-local`/`make ci-local-full`.
