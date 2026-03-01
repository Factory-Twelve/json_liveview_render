# Changelog

## Unreleased (template)

### Non-released
- Items here are still in progress, exploratory, or waiting for confirmation.
- Keep non-release work here until it is intentionally prepared for the next release.
- Added `Spec.auto_fix/2` for automatic correction of common AI mistakes in generated specs (string→integer/float/boolean coercion, single-string children wrapping, orphan element detection).
- Added `Spec.format_errors/1,2` for formatting validation errors into human-readable strings suitable for AI re-prompting; catalog-enriched variant appends available component types for unknown_component errors.
- Added opt-in `error_boundary` attribute to `JsonLiveviewRender.Renderer` — when enabled, elements that raise during rendering are caught, logged, and silently removed so siblings continue to render.

### Release-ready
- Items here are the release draft for the next version bump.
- When cutting a release, move only this block into a versioned heading and keep `### Non-released` for future work.

### v0.3 scope lock release draft

#### API stability scope lock

- Added explicit v0.3 package-level API scope in `README.md`:

  - Stable v0.2 core (contract): Catalog, Spec, Registry, Renderer, Permissions, Bindings, Schema, Debug
  - v0.3 candidate: Stream, partial validation/rendering (`validate_partial/3`, `allow_partial`)
  - Experimental/deferred: Streaming adapters and DevTools

- Marked streaming adapters and DevTools as experimental/companion-surface and out of the v0.3 core contract.

#### Migration context and caveats

- v0.2 core API consumers are expected to remain non-breaking through this v0.3 scope-lock draft.
- v0.3 behavior changes are opt-in for partial/streaming flows (`validate_partial/3`, `allow_partial`), so full-spec v0.2 core paths do not require migration changes.
- Stream event handling is now stricter for malformed or out-of-order event payloads; teams using incremental streaming should verify provider normalization/error handling paths.
- Adapter references and DevTools remain experimental/deferred surfaces and are not part of the stable v0.3 core contract.
- FAC-70 release-gate artifacts:
  - Migration summary: `docs/v0.3_migration_notes.md`
  - Explicit local-use stability approval: `docs/v0.3_local_use_approval.md`

#### Changes

- Added `mix json_liveview_render.check_metadata` as a reproducible metadata validation
  command for required Hex fields before release.
- Documented a release workflow in `README.md` that runs the new metadata check
  before `mix hex.publish --dry-run`.
- Added canonical CI contract for `FAC-59` to harden local/CI parity and cost control:
  - Added `scripts/ci_plan.md` as the source of truth for trigger policy, matrix, and check command contract.
  - Updated `scripts/ci_local.sh` to execute the plan-defined matrix via `--matrix`, with dry-run support and explicit failure context.
  - Synced `.github/workflows/ci.yml` to the same matrix policy (`1.15`/`1.19`, format on `1.19` only, `MIX_PUBSUB=0 mix test`).
  - Added `test/ci_plan_test.exs` to enforce plan/script/workflow parity and document the intentional matrix-format split.

- Added partial-spec validation path for streaming:
  - `JsonLiveviewRender.Spec.validate_partial/3`
  - `allow_missing_root` and `allow_unresolved_children` validation options
- Added partial renderer mode:
  - `JsonLiveviewRender.Renderer` now supports `allow_partial: true`
- Expanded stream runtime APIs:
  - `JsonLiveviewRender.Stream.ingest_many/3`
  - `JsonLiveviewRender.Stream.finalize/3`
- Added provider adapter examples (experimental reference only):
  - `JsonLiveviewRender.Stream.Adapter.OpenAI`
  - `JsonLiveviewRender.Stream.Adapter.Anthropic`
- Added tests for partial rendering, stream finalize behavior, and adapter integration.
- Stabilized the streaming event contract and adapter normalization for v0.3:
  - `JsonLiveviewRender.Stream` now enforces explicit transitions for `{:root, id}`, `{:element, id, element}`, and `{:finalize}` with duplicate/out-of-order explicit errors
  - `JsonLiveviewRender.Stream.finalize/3` and `JsonLiveviewRender.Stream.to_spec/1` now share partial-state behavior via `require_complete: false` support
  - Adapter reference modules now return explicit errors for malformed provider payloads (including missing fields and schema mismatches) and ignore only unrelated/noise events
- Added experimental DevTools integration:
  - `JsonLiveviewRender.DevTools` browser inspector component
  - renderer flags `dev_tools` and `dev_tools_open`
- Hardened DevTools output by default:
  - `JsonLiveviewRender.Renderer` now gates DevTools output behind environment/config checks
  - added hard kill switch `dev_tools_force_disable` for sensitive environments
  - added test coverage for absent DevTools rendering when disabled
- Added catalog schema/prompt golden contract hardening (FAC-56):
  - Added golden fixture exports for small and medium catalog schemas/prompts under `test/fixtures/schema`
  - Tightened `JsonLiveviewRender.Schema` output determinism by sorting components and prop fields during prompt/schema generation
  - Added strict-mode import regression coverage for schema contract consistency (`unknown_prop` rejection in strict mode with permissive-mode exception)
  - Added doctest-backed documentation examples for `JsonLiveviewRender.Schema` export APIs

## 0.2.0 - 2026-02-26

- Data binding milestone complete:
  - `_binding` prop resolution from LiveView assigns.
  - optional binding type checks via `binding_type` + `check_binding_types`.
- Added local CI workflow for cost control:
  - `scripts/ci_local.sh`
  - `make ci-local`
- Updated CI to run formatting on canonical Elixir version and cancel superseded runs.
- Updated package metadata and links for `json_liveview_render`.

## 0.1.0 - 2026-02-25

- Initial v0.1 foundation release.
- Catalog DSL with runtime introspection.
- Flat spec validator with strict/permissive unknown prop modes.
- Explicit registry mapping and fail-fast lookup behavior.
- LiveView renderer with permission filtering.
- JSON Schema and prompt export.
- ExUnit + property tests and CI workflow.
- Added module-level catalog introspection helpers (`types/1`, `props_for/2`, `exists?/2`).
- Added compile-time registry drift warnings for unknown mapped component types.
- Added structured event stream accumulator (`JsonLiveviewRender.Stream`) as v0.3 candidate functionality.
- Added `JsonLiveviewRender.Debug.inspect_spec/3` diagnostics report helper.
- Added `mix json_liveview_render.new` starter scaffolding task.
- Added `JsonLiveviewRender.Test.Generators` support helpers for property-based spec fixtures.
- Added generated-scaffold smoke test (`mix json_liveview_render.new` -> compile -> validate -> render).
- Added `mix ci` alias and Hex docs/package metadata polish in `mix.exs`.
