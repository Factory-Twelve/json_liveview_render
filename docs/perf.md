# Benchmark Runbook

This file is the canonical reference for running, recording, and comparing benchmark results in `json_liveview_render`.

## Prerequisites

- Run commands from the repository root.
- Install dependencies once: `mix deps.get`
- Recommended toolchain parity with CI matrix:
  - Elixir `1.15.8` + OTP `26.2`
  - Elixir `1.19.5` + OTP `28.0`
- For local reproducibility, prefer:
  - plugged-in power,
  - no heavy background CPU tasks,
  - the same Elixir/OTP pair for baseline and compare runs,
  - the same host OS and hardware class.

## Canonical Commands

Quick local run (text output):

```bash
make benchmark
```

Direct task examples:

```bash
# local text output
mix json_liveview_render.bench

# deterministic JSON matrix run for compare/baseline workflows
mix json_liveview_render.bench --matrix --suites validate,render --seed 20260301 --iterations 30 --format json

# fail process when thresholds are exceeded
mix json_liveview_render.bench --matrix --suites validate,render --seed 20260301 --iterations 30 --format json --guardrail-fail
```

## Reproducible Run Protocol

Use this protocol when capturing a baseline or validating a potential regression.

1. Warm-up run (discard result):

```bash
mix json_liveview_render.bench --matrix --suites validate,render --seed 20260301 --iterations 10 --format json > /tmp/json_liveview_render.bench.warmup.json
```

2. Measured run (store raw payload):

```bash
mix json_liveview_render.bench --matrix --suites validate,render --seed 20260301 --iterations 30 --format json > /tmp/json_liveview_render.bench.last.json
```

3. Repeat the measured run once more if guardrail fails in `report_only` mode to rule out transient noise.

## Expected Output Contract

Text output includes:

- config block,
- metadata block,
- results by suite,
- guardrail summary (when enabled).

JSON output shapes:

- Single run (`--matrix` omitted):
  - top-level keys: `metadata`, `config`, `suites`, optional `guardrail`
- Matrix run (`--matrix` enabled):
  - top-level keys: `matrix`, `cases`, optional `guardrail`
  - each entry in `cases` has `metadata`, `config`, `suites`

Guardrail payload keys:

- `status` (`pass` or `fail`)
- `mode` (`report_only` or `fail_on_regression`)
- `threshold_file`
- `threshold_version`
- `checked_count`
- `skipped_count`
- `failure_count`
- `failures`
- `skipped`

## Machine and OS Caveats

Benchmark numbers are comparable only when runtime and host context are close.

- Do not compare runs across different Elixir/OTP versions without labeling them separately.
- Keep OS type and CPU topology stable (`metadata.machine.os_type`, `logical_processors`, `schedulers_online`).
- Expect first-run outliers if code paths are cold; always run the warm-up command before measured capture.
- If two measured runs differ materially, capture both and treat the run as noisy instead of rewriting thresholds immediately.

## Baseline Capture Format (Stable)

Copy-paste this exact shape when recording a new baseline. Keep key names unchanged.

```json
{
  "baseline_capture_v1": {
    "captured_at_utc": "2026-03-01T00:00:00Z",
    "git_ref": "<commit_sha>",
    "command": "mix json_liveview_render.bench --matrix --suites validate,render --seed 20260301 --iterations 30 --format json",
    "threshold_file": "benchmarks/thresholds.json",
    "threshold_version": 1,
    "matrix": true,
    "machine": {
      "os_type": "unix/darwin",
      "logical_processors": 10,
      "schedulers_online": 10,
      "word_size": 8
    },
    "cases": [
      {
        "suite": "validate",
        "case_name": "validate_small_depth_4_width_2_nodes_15",
        "node_count": 15,
        "iterations": 30,
        "p50_microseconds": 17,
        "p95_microseconds": 61,
        "memory_p50_bytes": 1328,
        "memory_p95_bytes": 99320
      }
    ]
  }
}
```

Field mapping from benchmark payload:

- `captured_at_utc`: `metadata.benchmarked_at_utc`
- `machine.*`: `metadata.machine.*`
- `threshold_*`: `guardrail.threshold_*`
- `cases[*].case_name`: `cases[*].config.case_name`
- `cases[*].node_count`: `cases[*].config.node_count`
- `cases[*].iterations`: `cases[*].config.iterations`
- `cases[*].p50_microseconds`: `cases[*].suites[*].metrics.p50_microseconds`
- `cases[*].p95_microseconds`: `cases[*].suites[*].metrics.p95_microseconds`

## Last-Run Summary Format (Stable)

Copy-paste this exact shape for the latest measured run summary. Keep key names unchanged.

```json
{
  "last_run_summary_v1": {
    "ran_at_utc": "2026-03-01T00:00:00Z",
    "git_ref": "<commit_sha>",
    "command": "mix json_liveview_render.bench --matrix --suites validate,render --seed 20260301 --iterations 30 --format json",
    "guardrail_status": "pass",
    "guardrail_mode": "report_only",
    "checked_count": 8,
    "skipped_count": 0,
    "failure_count": 0,
    "regressions": []
  }
}
```

When `failure_count > 0`, each `regressions` entry should use:

```json
{
  "suite": "render",
  "case_name": "depth_5_width_4",
  "metric": "p95_microseconds",
  "baseline": 957.0,
  "actual": 1280.0,
  "allowed_max": 1244.1,
  "regression_percent": 33.751
}
```

## Where to Keep Captures

- Keep raw JSON benchmark outputs outside committed source paths unless a ticket explicitly requires committing fixtures.
- Paste `baseline_capture_v1` and `last_run_summary_v1` blocks into the Linear issue, PR description, or a linked performance note so reviewers can compare runs without reformatting.
