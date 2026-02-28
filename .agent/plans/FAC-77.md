# FAC-77 Implementation Plan

## Problem
Release readiness currently depends on CI to run a broader set of checks, and there is no local script that guarantees the same publish path in a repeatable way. As a result, developers can miss local readiness issues (missing credentials, build/publish regressions) until CI or a failed publish attempt.

## Design
Add a root-invocable shell script that executes the required release-readiness sequence in a deterministic order:
1. `mix deps.get`
2. `mix ci`
3. `mix hex.build`
4. `mix hex.publish --dry-run`

The script will fail fast on missing prerequisites and clearly explain why and how to fix it before doing any publish-related steps. Checks will include:
- repo-root validation (expected `mix.exs`),
- required tool availability (`mix`),
- Hex credential guardrails (either `HEX_API_KEY` is set or local Hex config is present),
- command-by-command failure context with explicit next steps.

## Files to Change
- `.agent/plans/FAC-77.md` (create)
- `scripts/hex_release_dry_run.sh` (create)
- `README.md` (document script path and usage)
- `.agent/notes/FAC-77.md` (create)

## Key Decisions
- Keep the script as a Bash utility in `scripts/` to match existing project conventions (`scripts/ci_local.sh`).
- Keep behavior simple and explicit: no hidden flags and no partial command chaining, so failures surface where they occur.
- Fail early for missing credentials/config and toolchain issues to avoid expensive later failures.
- Keep existing CI flow untouched; this is a local publish-readiness helper.

## Scope Boundaries
- In scope:
  - Implementing and documenting `scripts/hex_release_dry_run.sh`.
  - Pre-flight guardrails for missing tools and Hex credentials.
  - Clear pass/fail messages with actionable next steps.
- Out of scope:
  - Changes to CI matrix/workflows.
  - Actual non-dry publish automation.
  - Hex registry metadata or version bump automation.
  - Additional test harness for shell scripts.

## Validation
- Ensure script file exists at `scripts/hex_release_dry_run.sh` and is executable.
- Validate script documentation exists in `README.md` and references repo-root execution.
- Run `mix format --check-formatted`.
- Run `mix compile --warnings-as-errors`.
- Update `.agent/notes/FAC-77.md` with implementation notes and handoff details.
