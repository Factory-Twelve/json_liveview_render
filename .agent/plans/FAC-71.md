# FAC-71 Implementation Plan

## Problem
Benchmarking currently has no dedicated harness in this repository, so performance work has no repeatable baseline for validation and render hot-path timing. There is no stable command to run benchmarks locally or through CI tooling, and benchmark output lacks machine/runtime context for reproducibility.

## Design
Create a dedicated benchmark namespace under `lib/json_liveview_render/benchmark` with: a reusable config parser, deterministic fixture generator, suite registry, and suite implementations for `validate` and `render` workloads. Add a `mix json_liveview_render.bench` task as the primary entrypoint and a shell wrapper in `scripts` for local and CI usage with shared defaults. Ensure each benchmark run prints suite results plus config and machine/runtime metadata.

## Files to Change
- `.agent/plans/FAC-71.md` (create)
- `.agent/notes/FAC-71.md` (create/update)
- `lib/json_liveview_render/benchmark/config.ex`
- `lib/json_liveview_render/benchmark/data.ex`
- `lib/json_liveview_render/benchmark/metrics.ex`
- `lib/json_liveview_render/benchmark/runner.ex`
- `lib/json_liveview_render/benchmark/suites.ex`
- `lib/json_liveview_render/benchmark/suite/validate.ex`
- `lib/json_liveview_render/benchmark/suite/render.ex`
- `lib/json_liveview_render/benchmark/catalog.ex`
- `lib/json_liveview_render/benchmark/components.ex`
- `lib/json_liveview_render/benchmark/registry.ex`
- `lib/mix/tasks/json_liveview_render.bench.ex`
- `scripts/benchmark.sh`
- `README.md`
- `test/mix/tasks/json_liveview_render.bench_test.exs`
- `test/json_liveview_render/benchmark_data_test.exs`

## Key Decisions
- Keep benchmark fixtures private to this package and colocated under `JsonLiveviewRender.Benchmark` modules to avoid adding extra external tooling dependencies.
- Use a deterministic fixture builder that depends only on config (`--seed`, width/depth parameters) so repeated runs are reproducible.
- Keep suites explicit and separate (`validate`, `render`) so future additions can be added without merging mixed timing logic.
- Measure both absolute per-iteration wall time and aggregate stats (min/max/mean/p95/p99) to give meaningful comparisons.
- Include metadata from `System.version/0`, OTP, OS, CPU/scheduler info, seed, and benchmark config in printed output and optional JSON output.
- Keep harness lightweight by avoiding external benchmark libraries and using a custom runner with `:timer.tc/1`.

## Scope Boundaries
### In scope
- Benchmark scaffolding modules and deterministic fixture generation for validate/render paths.
- Mix task entrypoint and shell script entrypoint for local and CI invocation.
- README documentation for running benchmarks.
- Minimal test coverage for parser determinism and CLI task invocation output.
- Update `.agent/notes/FAC-71.md` with handoff context.

### Out of scope
- Adding threshold assertions, alerting, or dashboards.
- Adding benchmark results to CI gates or release gating logic.
- Refactoring core `Spec`/`Renderer` performance code beyond moving data setup around benchmark invocation.
- Changing existing CI matrix behavior beyond docs/script additions.

## Validation
- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- Manual spot-check of README command examples after doc update.
- Update `.agent/notes/FAC-71.md` with observed setup assumptions and any follow-up work.
