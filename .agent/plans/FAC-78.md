# FAC-78 Implementation Plan

## Problem
There is no canonical local one-liner for publish-sanity checks, so release checks are documented as a manual sequence. This creates drift risk between CI/manual docs and actual command behavior.

## Design
Add a dedicated `release-check` Make target that runs the full publish sanity sequence in a stable order and exits on first failure.

- Keep each prerequisite check explicit in the target and avoid duplicating CI configuration logic.
- Sequence checks as:
  1. `mix json_liveview_render.check_metadata`
  2. `mix format --check-formatted`
  3. `mix compile --warnings-as-errors`
  4. `MIX_PUBSUB=0 mix test`
  5. `mix hex.publish --dry-run`
- Add a `help` target so `release-check` is discoverable from `make help` output.
- Update release documentation to reference `make release-check` as the canonical command and document expected exit behavior.

## Files to Change
- `.agent/plans/FAC-78.md` (create/update)
- `.agent/notes/FAC-78.md` (create/update)
- `Makefile` (add `release-check` target and target discovery via `help`)
- `README.md` (update release workflow section)

## Key Decisions
- Use a Make target instead of a new mix task for the canonical command to keep discoverability in `make` help and local workflows.
- Keep `release-check` on the same step order as README/CI expectations to reduce semantic drift.
- Keep semantics strict and explicit: if any step fails, the target exits non-zero immediately.

## Scope Boundaries
### In scope
- Add `release-check` target with publish dry-run and prerequisite checks.
- Make target discoverable from `make help` output.
- Document command semantics in README.

### Out of scope
- Creating a dedicated `mix` release alias/task.
- Modifying CI matrix or check behavior.
- Updating any unrelated tooling or release automation.

## Validation
- Run `mix format --check-formatted`.
- Run `mix compile --warnings-as-errors`.
- Update `.agent/notes/FAC-78.md` with implementation notes and any caveats.
