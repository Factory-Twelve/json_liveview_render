# FAC-80 Implementation Plan

## Problem
Developers still use informal release assumptions, including pushing tags during local iteration, which conflicts with the local-first release workflow and makes it unclear when a full external release check is required. The repository lacks explicit guidance for local vs. external release paths.

## Design
Update README to include one clear release policy section that distinguishes:

- local/experimental iteration (always tag-free, no external publish path),
- pre-release verification (`make release-check` + dry-run), and
- explicit release actions.

Keep `make release-check` as the canonical local sanity command and add a direct link from the existing release workflow section to the new policy section.

## Files to Change
- `.agent/plans/FAC-80.md` (create/update)
- `README.md`
- `.agent/notes/FAC-80.md` (create)

## Key Decisions
- Keep changes documentation-only for this ticket.
- Define “no tag push” as a strict rule for local and experimental work.
- Make tag push and `mix hex.publish` the explicit, manual release gate only, and require the release checklist to pass before those actions.
- Add one link from the release-check docs in README to the new policy section for fast discoverability and to prevent policy drift.

## Scope Boundaries
### In scope
- README updates for local-first flow, no tag push guidance, and release trigger conditions.
- New FAC-80 plan and notes files.
- No changes to code, tests, CI jobs, Make targets, or publish automation.

### Out of scope
- Adding automation for automatic Hex publication.
- Modifying CI/CD release pipelines.
- Metadata/task changes (already covered by prior ticket).

## Validation
- Visual/manual review of README policy wording for unambiguous decision points.
- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- Note any remaining risks or follow-up items in `.agent/notes/FAC-80.md`.
