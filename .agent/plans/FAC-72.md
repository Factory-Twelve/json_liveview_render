# FAC-72 Implementation Plan

## Problem
`JsonLiveviewRender.Spec.validate/2` currently has inconsistent coverage across benchmark workload sizes. The matrix harness includes multiple render-focused shape combinations, but there is no explicit small/typical/pathological coverage for validation-only behavior, and validation results can be captured without memory statistics.

## Design
- Keep the existing benchmark matrix architecture and keep output formatting unchanged.
- Replace matrix cases with three deterministic validation tiers:
  - small
  - typical
  - pathological (1k+ nodes)
- Reuse matrix seed derivation (`base_seed + index`) for reproducible specs.
- Enable memory collection in the `validate` suite so results include latency percentiles and memory metrics.
- Add docs entry with a reproducible command and captured baseline values for `validate` tier runs.

## Files to Change
- `.agent/plans/FAC-72.md` (create)
- `.agent/notes/FAC-72.md` (create)
- `lib/json_liveview_render/benchmark/matrix.ex`
- `lib/json_liveview_render/benchmark/suite/validate.ex`
- `test/json_liveview_render/benchmark/suite/validate_test.exs`
- `test/mix/tasks/json_liveview_render.bench_test.exs`
- `README.md`

## Key Decisions
- Use exactly three matrix cases to match acceptance of small/typical/pathological tiers.
- Keep matrix defaults and case naming deterministic and explicit so historical baselines are easy to compare.
- Measure memory in `validate` suite consistently with `Metrics.measure(..., memory: true)` to satisfy reporting requirements.
- Store benchmark baseline numbers in repository docs (README) with the command used and recorded metric snapshots.

## Scope Boundaries
### In scope
- Matrix case redefinition for validate path focus.
- Memory collection for validate suite.
- Test updates for suite metrics and matrix tier output shape.
- Baseline documentation update with reproducible validate measurements.

### Out of scope
- Changes to renderer suite behavior or benchmark generator internals beyond matrix tiers.
- CI wiring or gating logic changes.
- New tooling outside existing benchmark task/matrix flow.

## Validation
- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- Manually confirm baseline docs are generated from deterministic benchmark runs.
