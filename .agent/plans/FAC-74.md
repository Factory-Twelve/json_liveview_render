# FAC-74 Implementation Plan

## Problem
Current benchmark fixtures are generated with fixed geometry (`sections` × `columns` × `metrics_per_column`) and no reusable random seed path. That produces deterministic values by construction, but not a configurable random benchmark topology, and makes it difficult to recreate identical workloads across environments with explicit seed/state parameters.

## Design
Implement a seeded, deterministic fixture generator in `JsonLiveviewRender.Benchmark.Data` that builds a catalog/spec pair shape from configurable graph parameters:

- `seed`: controls the pseudo-random sequence used by the generator
- `node_count`: exact number of benchmark nodes
- `depth`: maximum tree depth
- `branching_factor`: maximum children per internal node

Use a custom pure integer RNG state machine (Xorshift-style) so node ordering and props are stable across runtimes.

The generated specs will:

- always include `"children"` on every node (empty list for leaves),
- use only components with complete required props (`row`, `column`, `section`, `section_metric_card`, `metric`) from benchmark catalog coverage,
- stay within strict validator constraints for both validation and render suites.

`Config` will expose new defaults and flags and keep optional legacy shape aliases (`sections`, `columns`, `metrics_per_column`) as compatibility inputs that resolve to `node_count` to preserve existing invocations.

## Files to Change
- `.agent/plans/FAC-74.md` (create)
- `.agent/notes/FAC-74.md` (create)
- `lib/json_liveview_render/benchmark/config.ex`
- `lib/json_liveview_render/benchmark/data.ex`
- `lib/json_liveview_render/benchmark/runner.ex`
- `lib/mix/tasks/json_liveview_render.bench.ex`
- `test/json_liveview_render/benchmark/config_test.exs`
- `test/json_liveview_render/benchmark_data_test.exs`
- `test/mix/tasks/json_liveview_render.bench_test.exs`
- `test/json_liveview_render/benchmark/runner_test.exs`
- `README.md`

## Key Decisions
- Keep benchmark catalog and registry modules static to avoid dynamic compile-time registry/catalog generation overhead in benchmark runs.
- Replace fixed-shape generation with depth/breadth constrained random tree generation while preserving strict validation compatibility.
- Preserve legacy CLI shape inputs as aliasing translation to avoid unnecessary breakage in existing benchmark invocations.
- Choose a pure integer pseudo-random process over `:rand` to avoid runtime/OTP variability.
- Fail fast when requested `node_count` is impossible for the requested `(depth, branching_factor)`.

## Scope Boundaries
### In scope
- Deterministic benchmark fixture generation for both suites using seeded randomness.
- New benchmark parameters (`node_count`, `depth`, `branching_factor`) with defaults.
- Suite compatibility with existing `validate` and `render` suite pipeline.
- Update docs and unit tests for deterministic seeded generator behavior.

### Out of scope
- Changing core validator/renderer behavior.
- Adding streaming/generator-based catalog modules.
- Modifying non-benchmark benchmark-related tooling beyond supported options and documentation.

## Validation
- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- Existing benchmark integration tests, plus new/updated tests for:
  - shape parameter validation,
  - deterministic behavior on repeated seed runs,
  - suite report keying and generated spec shape (`children` present on every node).
