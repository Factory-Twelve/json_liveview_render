# Changelog

## 0.1.0 - 2026-02-25

- Initial v0.1 foundation release.
- Catalog DSL with runtime introspection.
- Flat spec validator with strict/permissive unknown prop modes.
- Explicit registry mapping and fail-fast lookup behavior.
- LiveView renderer with permission filtering and binding resolution.
- JSON Schema and prompt export.
- ExUnit + property tests and CI workflow.
- Added module-level catalog introspection helpers (`types/1`, `props_for/2`, `exists?/2`).
- Added optional binding type checks (`binding_type`, `check_binding_types`).
- Added compile-time registry drift warnings for unknown mapped component types.
- Added structured event stream accumulator (`JsonLiveviewRender.Stream`) as pre-v0.3 functionality.
- Added `JsonLiveviewRender.Debug.inspect_spec/3` diagnostics report helper.
- Added `mix json_liveview_render.new` starter scaffolding task.
- Added `JsonLiveviewRender.Test.Generators` support helpers for property-based spec fixtures.
- Added generated-scaffold smoke test (`mix json_liveview_render.new` -> compile -> validate -> render).
- Added `mix ci` alias and Hex docs/package metadata polish in `mix.exs`.
