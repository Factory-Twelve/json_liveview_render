# FAC-77 Handoff Notes

## Summary
Added a local dry-run release script and documentation for predictable publish readiness checks:
- Added `scripts/hex_release_dry_run.sh`
- Documented repo-root execution and command flow in `README.md`

## What Changed
- Implemented a guarded executable script that:
  - Validates execution from repo root
  - Verifies `mix` is available
  - Validates Hex credentials (`HEX_API_KEY` or local Hex key config fallback)
  - Runs `mix deps.get`, `mix ci`, `mix hex.build`, and `mix hex.publish --dry-run`
- Added command-level failure messaging with suggested remediation steps.
- Added handoff notes for follow-up agents.

## Assumptions / Decisions
- Credentials are treated as available when either `HEX_API_KEY` is set or Hex config contains common key fields.
- Script is intentionally local-only and does not alter CI matrix wiring.
- No test harness was added because this change is shell/documentation focused and there is no existing shell test framework in the repo.

## Next Steps
- Verify the script from a clean local environment where Hex is available and credentials are configured.
- Run the required checks (`mix format --check-formatted`, `mix compile --warnings-as-errors`) before committing.
- Commit with an FAC-77 reference in the message.
