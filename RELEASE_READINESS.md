# v0.3 Release Readiness Checklist

Owner: Factorytwelve maintainers (current DRI: Jeff Fedor)  
Checklist path: `RELEASE_READINESS.md`  
Parent gate: [FAC-61 - v0.3 hardening milestone closeout gate](https://linear.app/factorytwelve/issue/FAC-61/v03-hardening-milestone-closeout-gate)

Use this page as the required release gate before closing FAC-61 and before running `mix hex.publish`.

## FAC-70 Migration and Approval Package

- Migration summary (v0.2 -> v0.3 gate): [`docs/v0.3_migration_notes.md`](docs/v0.3_migration_notes.md)
- Local-use stability approval artifact: [`docs/v0.3_local_use_approval.md`](docs/v0.3_local_use_approval.md)
- Parent-gate reference target: [FAC-61](https://linear.app/factorytwelve/issue/FAC-61/v03-hardening-milestone-closeout-gate)

## Gate Checklist

- [ ] All required smoke tests in the matrix below pass with `0 failures`.
- [ ] `mix format --check-formatted` passes.
- [ ] `mix compile --warnings-as-errors` passes.
- [ ] `MIX_PUBSUB=0 mix test` passes.
- [ ] `make release-check` passes without manual overrides.
- [ ] FAC-70 migration summary and approval artifact are linked in FAC-61.
- [ ] FAC-61 contains maintainer sign-off and any documented caveats.

## Required Smoke Matrix

| Area | Owner | Command | Command path | Expected pass signal | Expected fail signal | Rollback + retest action |
| --- | --- | --- | --- | --- | --- | --- |
| Catalog | Release DRI | `MIX_PUBSUB=0 mix test test/json_liveview_render/catalog_test.exs` | `test/json_liveview_render/catalog_test.exs` | Command exits `0`; ExUnit reports `0 failures`; catalog introspection and compile-time guard tests pass | Non-zero exit; ExUnit assertion failures or missing expected `ArgumentError` for invalid catalog definitions | Revert/fix catalog DSL changes, rerun this command until green, then rerun full smoke sequence |
| Registry | Release DRI | `MIX_PUBSUB=0 mix test test/json_liveview_render/registry_test.exs` | `test/json_liveview_render/registry_test.exs` | Command exits `0`; ExUnit reports `0 failures`; registry mapping + unknown-type guard tests pass | Non-zero exit; mapping assertions fail or compile-time unknown-type checks regress | Revert/fix registry mapping changes, rerun this command, then rerun full smoke sequence |
| Permissions | Release DRI | `MIX_PUBSUB=0 mix test test/json_liveview_render/permissions_test.exs` | `test/json_liveview_render/permissions_test.exs` | Command exits `0`; ExUnit reports `0 failures`; allow/deny composition and authorizer contract tests pass | Non-zero exit; permission filtering mismatch or invalid authorizer return handling regresses | Revert/fix permission policy or authorizer changes, rerun this command, then rerun full smoke sequence |
| Bindings | Release DRI | `MIX_PUBSUB=0 mix test test/json_liveview_render/bindings_test.exs` | `test/json_liveview_render/bindings_test.exs` | Command exits `0`; ExUnit reports `0 failures`; binding resolution and deterministic type-check errors behave as expected | Non-zero exit; missing-binding or type-check behavior changes unexpectedly | Revert/fix binding resolution changes, rerun this command, then rerun full smoke sequence |
| Partial streaming | Release DRI | `MIX_PUBSUB=0 mix test test/json_liveview_render/spec_test.exs test/json_liveview_render/stream_test.exs test/json_liveview_render/stream_integration_test.exs test/json_liveview_render/renderer_test.exs` | `test/json_liveview_render/spec_test.exs`, `test/json_liveview_render/stream_test.exs`, `test/json_liveview_render/stream_integration_test.exs`, `test/json_liveview_render/renderer_test.exs` | Command exits `0`; ExUnit reports `0 failures`; `validate_partial`, stream finalize, adapter integration, and `allow_partial` renderer behavior all pass | Non-zero exit; partial-validation, stream sequencing, adapter normalization, or partial renderer behavior fails | Revert/fix stream/spec/renderer partial-path changes, rerun this command, then rerun full smoke sequence |

## Command Execution Steps

Run smoke commands in this order and stop immediately on first failure:

1. `MIX_PUBSUB=0 mix test test/json_liveview_render/catalog_test.exs`
2. `MIX_PUBSUB=0 mix test test/json_liveview_render/registry_test.exs`
3. `MIX_PUBSUB=0 mix test test/json_liveview_render/permissions_test.exs`
4. `MIX_PUBSUB=0 mix test test/json_liveview_render/bindings_test.exs`
5. `MIX_PUBSUB=0 mix test test/json_liveview_render/spec_test.exs test/json_liveview_render/stream_test.exs test/json_liveview_render/stream_integration_test.exs test/json_liveview_render/renderer_test.exs`
6. `mix format --check-formatted`
7. `mix compile --warnings-as-errors`
8. `MIX_PUBSUB=0 mix test`
9. `make release-check`

## Failure States: Rollback and Retest

1. Freeze release activity: do not publish and do not mark FAC-61 complete.
2. Capture failure details in FAC-68 (failing command, timestamp, branch SHA, first failing test).
3. Roll back the failing change set:
   - If not merged: remove or patch the offending commit(s) on the branch.
   - If merged: create a revert commit for the offending SHA(s).
4. Retest in two phases:
   - Phase A: rerun the exact failing smoke command until it passes.
   - Phase B: rerun the full sequence in `Command Execution Steps`.
5. Update FAC-61 with retest result and only proceed when all gate checks return green.
