# FAC-67 Handoff Notes

## Summary
Completed the v0.3 scope conformance audit for FAC-67 using the `v0.3 scope` initiative as source-of-truth and posted a concise scope confirmation note to the parent gate issue (FAC-61).

## What Changed
- Created and filled `.agent/plans/FAC-67.md` with required planning sections.
- Audited scope sources in Linear:
  - Initiative: `v0.3 scope` (`654f621a-3e69-44e9-93dd-574891d5e4d7`)
  - Parent gate: FAC-61
  - Gate-child issues: FAC-66, FAC-67, FAC-68, FAC-69, FAC-70
  - Core prereq set from FAC-61 DoD / FAC-66 dependency audit: FAC-52, FAC-53, FAC-54, FAC-55, FAC-56, FAC-57, FAC-58, FAC-59, FAC-60, FAC-62
- Added scope confirmation comment to FAC-61 (comment id: `3144eed3-30bc-4e5f-a32b-24cb01e6bac3`) containing:
  - Explicit in-scope list
  - Explicit out-of-scope list
  - Scope deltas/ambiguities and tracking context

## Scope Decisions Captured
- In-scope anchor remains: `Catalog -> Spec -> Render`, LiveView-first runtime, binding-only execution model, structured spec streaming.
- Operational gate workstreams (FAC-66..FAC-70) and prereq set (FAC-52..FAC-60, FAC-62) are treated as in-scope closeout checks.
- Out-of-scope exclusions include cross-platform/runtime expression engines and companion-package adapter expansion beyond core scope anchor.
- Noted ambiguity: FAC-57/FAC-58 are operational hardening requirements and should not be interpreted as expanding core API scope.
- Noted metadata delta: FAC-61 `blockedBy` currently shows a subset of full DoD prereqs; referenced FAC-66 dependency-sync evidence in the parent note so this mismatch is tracked.

## Validation
- Confirmed parent scope comment exists on FAC-61 with explicit in-scope and out-of-scope sections.
- `mix format --check-formatted` (pass)
- `MIX_PUBSUB=0 mix test` (fails in this sandbox: `Mix.PubSub.Subscriber` socket open `:eperm`)
- `mix compile --warnings-as-errors` (fails in this sandbox with same `Mix.PubSub` `:eperm`)
- `MIX_PUBSUB=0 mix compile --warnings-as-errors` (same `:eperm` failure)
