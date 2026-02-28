# FAC-79 Implementation Plan

## Problem
Package metadata drift can cause Hex publish failures and make release artifacts inconsistent (incorrect name/url/license inputs or stale values in `mix.exs`). We need a reproducible local check that enforces required package metadata before release.

## Design
Introduce a dedicated mix task to validate the required metadata fields from the project config and keep the validation logic deterministic and easy to test.

- Add `mix json_liveview_render.check_metadata` that reads `Mix.Project.config/0` and validates required metadata.
- Validate required fields:
  - package name (resolved from `project[:name]` when present, otherwise `project[:app]`)
  - package URL (from `source_url` with `homepage_url` fallback)
  - package version (valid semver string)
  - license list (non-empty `licenses` in package metadata)
- Fail with actionable errors when any required field is missing or malformed.
- Document and wire this check into the release process documentation for this package.

## Files to Change
- `.agent/plans/FAC-79.md` (create/update)
- `.agent/notes/FAC-79.md` (create)
- `lib/mix/tasks/json_liveview_render.check_metadata.ex` (create)
- `test/mix/tasks/json_liveview_render.check_metadata_test.exs` (create)
- `README.md` (document release metadata check)
- `CHANGELOG.md` (Unreleased section entry)

## Key Decisions
- Keep validation in a mix task module to match existing task patterns and allow direct developer invocation.
- Keep checks focused on required release-critical metadata fields only to minimize release friction.
- Keep version validation using Elixir `Version.parse/1` to enforce semver format without introducing new dependencies.
- Keep URL checks permissive on host/path (non-empty `http`/`https`-style URL) and enforce that at least one package URL source exists.

## Scope Boundaries
### In scope
- Add a reproducible metadata validation task and tests.
- Add release workflow documentation that includes the validation step.
- Log/raise clear actionable failures for missing or invalid required metadata.

### Out of scope
- Automating publishing itself (`mix hex.publish` execution).
- Broadening checks beyond the required metadata fields list (name/url/version/license).
- Changes to CI matrix behavior.

## Validation
- Add tests for both valid and invalid metadata permutations for the metadata check.
- Run `mix format --check-formatted`.
- Run `mix compile --warnings-as-errors`.
- Update `.agent/notes/FAC-79.md` with implementation notes and any follow-ups.
