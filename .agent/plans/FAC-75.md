# FAC-75 Implementation Plan

## Problem
Benchmark runs currently emit raw metrics but do not enforce regression guardrails against versioned baselines. That leaves validate/render performance vulnerable to accidental drift because there is no codified threshold contract, no standard failure policy, and no documented process for when/why threshold updates are acceptable.

## Design
Add a benchmark guardrail layer with three parts:

1. Versioned thresholds:
   - Add a repository-managed JSON file under `benchmarks/thresholds.json`.
   - Define explicit `validate` and `render` sections with per-case baseline values and allowed regression percentages.
   - Use one latency metric (`p95_microseconds`) as the enforced contract to keep interpretation simple and consistent.

2. Guardrail evaluation + enforcement:
   - Add a new benchmark module that loads threshold definitions and evaluates benchmark reports (single and matrix).
   - Emit guardrail results in both text and JSON output:
     - pass/fail status
     - checked/skipped counts
     - failure details (suite, case, metric, baseline, observed value, allowed max, regression %)
   - Keep default behavior non-blocking (local report only).
   - Add optional hard-fail mode (`--guardrail-fail`) so CI can fail the job when thresholds are exceeded.

3. Documentation + update protocol:
   - Extend README benchmark docs with:
     - guardrail command examples (report-only vs fail-on-regression),
     - exact failure handling steps,
     - threshold update checklist (evidence + review expectations).

## Files to Change
- `.agent/plans/FAC-75.md` (create)
- `.agent/notes/FAC-75.md` (create/update)
- `benchmarks/thresholds.json` (create)
- `lib/json_liveview_render/benchmark/guardrail.ex` (create)
- `lib/mix/tasks/json_liveview_render.bench.ex`
- `test/json_liveview_render/benchmark/guardrail_test.exs` (create)
- `test/mix/tasks/json_liveview_render.bench_test.exs`
- `README.md`

## Key Decisions
- Threshold source of truth will be a committed JSON file (`benchmarks/thresholds.json`) so changes are reviewable, diffable, and versioned with code.
- Enforce only latency `p95_microseconds` for this ticket to avoid overfitting to noisy memory metrics while still protecting hot-path regressions.
- Guardrails will evaluate every benchmark case that has a matching threshold entry; missing entries are reported as skipped (not hard errors) to preserve incremental adoption.
- Default mode is report-only for local development; hard failure is opt-in via `--guardrail-fail` to satisfy optional CI gating.

## Scope Boundaries
### In scope
- Define and version guardrail thresholds for `validate` and `render`.
- Implement guardrail evaluation and output in benchmark task flow.
- Add optional CI-style fail behavior.
- Document exact reproducibility and failure response steps, including threshold adjustment review checklist.

### Out of scope
- Reworking benchmark metric collection internals.
- Auto-updating thresholds from benchmark runs.
- Mandatory CI wiring changes outside benchmark task behavior/documentation.

## Validation
- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- `MIX_PUBSUB=0 mix test`
- Targeted assertions:
  - threshold file loads and validates shape,
  - guardrail pass/fail/skip behavior,
  - `--guardrail-fail` exits non-zero on regression,
  - README guardrail instructions remain explicit and reproducible.
