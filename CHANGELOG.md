# Changelog

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
- Added structured event stream accumulator (`JsonLiveviewRender.Stream`) as pre-v0.3 functionality.
- Added `JsonLiveviewRender.Debug.inspect_spec/3` diagnostics report helper.
- Added `mix json_liveview_render.new` starter scaffolding task.
- Added `JsonLiveviewRender.Test.Generators` support helpers for property-based spec fixtures.
- Added generated-scaffold smoke test (`mix json_liveview_render.new` -> compile -> validate -> render).
- Added `mix ci` alias and Hex docs/package metadata polish in `mix.exs`.
