## Problem
`JsonLiveviewRender.Renderer.render/1` must maintain bounded complexity as benchmark graph size increases, but the current benchmark coverage only exercises single configured shapes and does not track modern hot-path metrics needed for render-only regression detection.

The task needs reproducible benchmark coverage that exercises:

- Depth/branching variations across matrix-style inputs.
- A large (>1,000 node) render tree.
- Latency percentiles beyond mean and a memory signal for each iteration.

## Design
- Add a matrix execution mode to `mix json_liveview_render.bench` that runs a deterministic set of render/validation shape cases derived from a fixed depth × width matrix plus a 1,000+ node case.
- Keep the existing single-case benchmark path untouched for backward compatibility.
- Extend benchmark metrics capture to record:
  - p50 latency (in addition to existing p95/p99).
  - throughput (ops/sec).
  - optional per-iteration memory delta statistics (mean/p50/p95/min/max/total) so the matrix path can report memory.
- Preserve the deterministic seed behavior by deriving matrix case seeds from the base seed and stable case ordering.
- Keep output compatibility for existing non-matrix CLI JSON/text reports; add matrix-specific payload only when matrix mode is requested.

## Files to Change
- `.agent/plans/FAC-73.md` (create)
- `.agent/notes/FAC-73.md` (create)
- `lib/json_liveview_render/benchmark/config.ex`
- `lib/json_liveview_render/benchmark/matrix.ex` (create)
- `lib/json_liveview_render/benchmark/metrics.ex`
- `lib/json_liveview_render/benchmark/runner.ex`
- `lib/json_liveview_render/benchmark/suite/render.ex`
- `lib/mix/tasks/json_liveview_render.bench.ex`
- `test/json_liveview_render/benchmark/suite/render_test.exs` (create)
- `test/json_liveview_render/benchmark/suite/validate_test.exs`
- `test/json_liveview_render/benchmark/runner_test.exs`
- `test/mix/tasks/json_liveview_render.bench_test.exs`
- `README.md`

## Key Decisions
- Matrix mode is opt-in (`--matrix`) to avoid changing default CI/dev behavior.
- Matrix cases are explicit and bounded:
  - matrix depth×width combinations from a fixed seed-ordered list.
  - a dedicated large tree case with node_count `1024`.
- Keep memory measurement opt-in inside `render` suite execution so non-hot-path benchmark runs can remain lightweight.
- Use strict deterministic construction (deterministic seeds + fixed case ordering) so runs do not flake from seed drift.

## Scope Boundaries
### In scope
- Benchmark execution mode that includes branching-depth matrix cases and a 1k+ node case.
- p50 and memory metric capture in benchmark metrics and report rendering.
- Test updates around metrics shape, matrix output, and render suite memory/percentile capture.
- README update to document new matrix option and metric outputs.

### Out of scope
- Changing validator (`validate` suite) behavior.
- Adding production runtime alerts or budgets in CI.
- Reworking benchmark generator internals outside the existing hot-path benchmark data path.

## Validation
- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- Existing tests for benchmark harness modules adjusted for new metric keys and matrix output.
