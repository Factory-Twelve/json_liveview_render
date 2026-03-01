# FAC-75 Handoff Notes

Implemented benchmark regression guardrail contract with versioned thresholds, report output, and optional fail-on-regression mode.

## What changed

- Added committed threshold source of truth:
  - `benchmarks/thresholds.json`
  - Includes explicit `validate` and `render` sections.
  - Enforced metric is `p95_microseconds`.
  - Each suite includes `max_regression_percent` + per-case baseline values.

- Added guardrail evaluator module:
  - `lib/json_liveview_render/benchmark/guardrail.ex`
  - Loads/parses thresholds from JSON.
  - Evaluates benchmark reports (single and matrix) against thresholds.
  - Returns pass/fail status with checked/skipped/failure counts and failure details.
  - Supports text rendering for CLI report output.

- Wired guardrails into benchmark task:
  - `lib/mix/tasks/json_liveview_render.bench.ex`
  - New options:
    - `--guardrail` / `--no-guardrail` (default enabled)
    - `--guardrail-fail` (optional hard fail mode)
    - `--guardrail-thresholds <path>` (override threshold file, useful for tests)
  - New env toggle:
    - `BENCH_GUARDRAIL_FAIL=true` behaves like `--guardrail-fail`.
  - Guardrail summary is included in both JSON and text outputs.
  - Enforced mode field in output:
    - `report_only` (default)
    - `fail_on_regression`
  - If fail mode is enabled and any threshold fails, task exits with `Mix.raise`.

- Updated tests:
  - Added `test/json_liveview_render/benchmark/guardrail_test.exs`
    - threshold parsing
    - pass/fail/skip evaluation
    - text summary output
  - Updated `test/mix/tasks/json_liveview_render.bench_test.exs`
    - asserts guardrail payload presence and counts
    - covers deterministic fail path via temp threshold fixture
    - validates invalid flag combination (`--no-guardrail` + `--guardrail-fail`)

- Updated docs:
  - `README.md` benchmark section now documents:
    - threshold file location
    - local report-only vs optional fail-on-regression behavior
    - exact failure handling rules
    - required checklist for threshold adjustments in PR review

## Validation status

- `mix format --check-formatted` passed.
- `mix compile --warnings-as-errors` could not run in this sandbox due Mix PubSub TCP restriction (`:eperm` in `Mix.Sync.PubSub.subscribe/1`).
- `MIX_PUBSUB=0 mix test` could not run for the same reason.
- Fallback signal gathered:
  - `elixir` + `Code.compile_file/1` succeeds for changed lib modules.
  - Targeted pure ExUnit for new guardrail module passes:
    - 5 tests, 0 failures (`test/json_liveview_render/benchmark/guardrail_test.exs` loaded via `elixir`).

## Notes for next agent/reviewer

- Baseline values in `benchmarks/thresholds.json` reflect deterministic matrix case measurements and existing documented validate baseline values.
- Single non-matrix runs default to case name `default`; those are reported as skipped unless `default` thresholds are added explicitly.
- CI can opt into hard enforcement by setting `BENCH_GUARDRAIL_FAIL=true` (or passing `--guardrail-fail`).
