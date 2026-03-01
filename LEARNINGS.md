# JsonLiveviewRender Learnings

Updated: 2026-02-25

## What We Validated

- The PRD-first v0.1 boundary is workable as code: catalog DSL, strict validator, explicit registry, renderer, schema export, prompt export.
- Flat `root + elements` specs are easy to validate and support incremental composition later.
- Permission filtering before rendering cleanly removes unauthorized elements without placeholder artifacts.
- `*_binding` props are a practical server-side data bridge and keep runtime state simple.

## Implementation Learnings

- Compile-time DSL code should persist generated component maps in module attributes; relying on macro-local variables can break generated functions.
- Explicit registry wiring (`registry` assign) keeps behavior deterministic and avoids implicit runtime module discovery.
- Binding transform logic must account for renamed keys (`rows_binding` -> `rows`) when building component assigns.
- `Phoenix.LiveViewTest.render_component/2` is a macro in current LiveView versions, so helpers must `require Phoenix.LiveViewTest`.
- In Elixir 1.19, support files in `test/support` should use `_helper.exs` naming to avoid test loader warnings.
- DevTools output contains internal spec/error details, so production-safe defaults must be explicit (disabled by default) with an explicit environment or deployment opt-in.

## Testing Learnings

- Property tests were effective for validating graph invariants, especially cycle detection and acyclic chain behavior.
- Renderer integration tests caught real contract mismatches between transformed props and component assigns.
- Strict-mode vs permissive-mode behavior needs explicit assertions and log capture to prevent accidental regressions.
- Scaffold smoke tests are valuable for generator tasks: they caught unsafe child rendering in generated HEEx wrappers and prevented shipping broken starter templates.

## Known Gaps and Risks

- Renderer currently assumes component callbacks consume assigns directly and render child content via `:children`; slot ergonomics are minimal.
- Registry completeness is enforced at runtime, not compile-time against the catalog.
- Permission semantics are component-level only; there is no inherited policy model yet.
- JSON Schema export is sufficient for structured output constraints, but not yet optimized for very large catalogs.
- Streaming runtime (`JsonLiveviewRender.Stream`) is intentionally deferred and not implemented in v0.1.

## Follow-Up Candidates

- Add compile-time checks to detect registry/catalog drift.
- Add richer slot support and child rendering helpers.
- Add benchmark suite for validation/render hot paths.
- Add optional validator integration with a full JSON Schema engine.
- Implement v0.2+ streaming accumulator and provider adapter examples.

## 2026-02-28

### FAC-53: Implement child slot rendering ergonomics for renderer
- Tests: passed
- PR: https://github.com/Factory-Twelve/json_liveview_render/pull/4

## 2026-03-01

### FAC-71: Benchmark: bench harness scaffolding + tooling entrypoint
- Tests: passed
- PR: https://github.com/Factory-Twelve/json_liveview_render/pull/17

## 2026-03-01

### FAC-74: Benchmark: deterministic catalog/spec generator
- Tests: passed
- PR: https://github.com/Factory-Twelve/json_liveview_render/pull/19

## 2026-03-01

### FAC-76: Benchmark: docs and run reproducibility notes
- Tests: passed
- PR: https://github.com/Factory-Twelve/json_liveview_render/pull/30
