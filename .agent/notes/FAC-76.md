# FAC-76 Handoff Notes

Implemented benchmark documentation and reproducibility notes with a dedicated runbook and stable copy-paste reporting formats.

## What changed

- Added a canonical benchmark runbook:
  - `docs/perf.md`
  - Covers prerequisites, canonical commands, deterministic matrix run protocol, warm-up guidance, and machine/OS caveats.

- Added stable reporting templates (copy-paste JSON shapes) in `docs/perf.md`:
  - `baseline_capture_v1`
  - `last_run_summary_v1`
  - Includes explicit field mapping from benchmark payload keys (`metadata`, `cases[*].config`, `cases[*].suites[*].metrics`, `guardrail`).

- Linked benchmark runbook from README:
  - `README.md` benchmark section now points to `docs/perf.md` as canonical run/read/compare reference.

- Completed required planning artifact:
  - `.agent/plans/FAC-76.md`

## Format contract decisions

- Keep benchmark task output as source-of-truth; no runtime code changes for FAC-76.
- Treat `docs/perf.md` templates as stable shape contract:
  - key names are versioned by top-level object name (`*_v1`),
  - future additions should be additive and avoid renaming/removing existing keys.

## Validation status

- `mix format --check-formatted`: passed
- `MIX_PUBSUB=0 mix test`: failed in sandbox due Mix PubSub socket permission (`:eperm`)
- `mix compile --warnings-as-errors`: failed in sandbox due same Mix PubSub socket permission (`:eperm`)
- `MIX_PUBSUB=0 mix compile --warnings-as-errors`: failed in sandbox due same Mix PubSub socket permission (`:eperm`)

## Notes for next agent/reviewer

- FAC-76 is docs-only; no benchmark execution logic or thresholds were changed.
- If you need compile/test confirmation, rerun those commands in an environment where Mix PubSub socket creation is permitted.
