# FAC-76 Implementation Plan

## Problem
Benchmark commands and output details currently live inside a long README section, but there is no dedicated, single runbook for reproducible local benchmarking. Maintainers need one place that clearly defines prerequisites, exact commands, environment caveats, warm-up guidance, and a stable copy-paste format for recording baseline and last-run summaries.

## Design
Create a dedicated benchmark runbook in `docs/perf.md` and link it from the README benchmark section.

The runbook will include:

1. Prerequisites and setup
   - required toolchain expectations (Elixir/OTP compatibility context and dependency install)
   - canonical entrypoint (`make benchmark`) and direct task commands
   - required environment notes (`CI=true` behavior and `MIX_PUBSUB=0` context for local validation commands)

2. Reproducible execution guidance
   - deterministic command examples using fixed seed, explicit suites, matrix mode, and iteration count
   - warm-up and repeat guidance (discard first run, compare subsequent runs)
   - machine/OS caveats for comparing results across hosts and runtimes

3. Stable reporting formats
   - baseline capture format (copy-paste JSON envelope with fixed keys)
   - last-run summary format (copy-paste JSON envelope with fixed keys)
   - explicit field mapping to current benchmark output/guardrail data

4. Discoverability
   - add a prominent link in `README.md` benchmark section to `docs/perf.md`

## Files to Change
- `.agent/plans/FAC-76.md` (create)
- `docs/perf.md` (create)
- `README.md` (update benchmark section with link to runbook)
- `.agent/notes/FAC-76.md` (create/update handoff notes)

## Key Decisions
- Keep benchmark behavior unchanged for FAC-76; this ticket is documentation and reproducibility guidance only.
- Define a canonical runbook (`docs/perf.md`) rather than growing README further.
- Treat JSON output from `mix json_liveview_render.bench --format json` as the source payload and document stable, copy-paste wrapper formats around it for baseline and last-run records.
- Standardize on deterministic benchmark examples using fixed `seed`, explicit `iterations`, and matrix case names.

## Scope Boundaries
### In scope
- Create benchmark runbook documentation with unambiguous commands and caveats.
- Document baseline and last-run summary formats in stable JSON shape.
- Link runbook from README.

### Out of scope
- Changing benchmark runtime code, metrics collection, or guardrail thresholds.
- Adding CI workflow changes for benchmark execution.
- Auto-generating or persisting benchmark snapshots via new tooling/scripts.

## Validation
- `MIX_PUBSUB=0 mix test`
- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- Manual doc verification:
  - `docs/perf.md` exists and is linked from `README.md`
  - benchmark run commands are copy-paste executable with no missing flags/context
  - baseline and last-run JSON templates are clearly named and stable-keyed
