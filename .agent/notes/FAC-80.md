# FAC-80 Handoff Notes

## Summary
Documented local-first release behavior and explicit tag policy for this package.

## What Changed
- Added a linked release policy section in `README.md` covering local/experimental flow, `make release-check`, and external publish/release triggers.
- Added explicit language that normal local/experimental work requires `no tag push`.
- Added an acceptance-oriented decision flow in the README linking release sanity checks to release/publish actions.
- Created/updated `.agent/plans/FAC-80.md` with required planning fields.

## Assumptions / Risks
- CI still uses `mix hex.publish --dry-run` in `make release-check`; actual `mix hex.publish` is intentionally documented as a manual external publish action.
- Tagging remains the external release marker and is intentionally excluded from normal local workflows.

## Validation
- Ran the required style/build commands:
  - `mix format --check-formatted`
  - `mix compile --warnings-as-errors`
