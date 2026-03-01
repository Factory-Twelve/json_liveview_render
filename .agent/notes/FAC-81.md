# FAC-81 Handoff Notes

## Summary
Standardized the changelog template format in `CHANGELOG.md` by separating non-released and release-ready notes and added README guidance linking to that template from release docs.

## What Changed
- Reworked the top of `CHANGELOG.md` into an explicit unreleased template:
  - `### Non-released` for exploratory or in-progress entries
  - `### Release-ready` for items intended for the next release
  - `### v0.3 scope lock release draft` subsection to hold the current draft release entries
- Linked release docs in `README.md` to the new changelog template and added explicit placement guidance for release-cut steps.
- Clarified the release-candidate path to map changelog states to explicit subsections.

## Assumptions / Risks
- Scope lock is to keep this ticket docs-only; no changelog tooling changes were made.
- `## Unreleased (template)` now contains draft content and is expected to be manually moved to version headings during release prep.

## Validation
- Ran required checks:
  - `mix format --check-formatted`
  - `mix compile --warnings-as-errors`
