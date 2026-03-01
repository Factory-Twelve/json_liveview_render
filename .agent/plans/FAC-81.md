# FAC-81 Implementation Plan

## Problem
Release notes formatting in `CHANGELOG.md` is informal and mixed, and contributors are unclear about where to place items that are not yet ready versus those intended for the next tagged release.

## Design
Introduce a dedicated `CHANGELOG.md` unreleased template that explicitly separates:

- `### Non-released` for in-progress or provisional notes
- `### Release-ready` for items intentionally selected for the next release draft

Keep the existing draft content under the new `Release-ready` subsection to preserve history.

Document the changelog workflow in `README.md` under the release section, with an explicit pointer to the changelog template and a clear ordering for version bump + changelog placement.

## Files to Change
- `.agent/plans/FAC-81.md` (create/update)
- `CHANGELOG.md`
- `README.md`
- `.agent/notes/FAC-81.md` (create/update)

## Key Decisions
- Keep this ticket documentation-only (no code/runtime behavior changes).
- Preserve an explicit two-track unreleased section so maintainers can stage work before a release without losing visibility.
- Keep release notes release-ready entries in `### Release-ready` and only move them to a versioned heading at release time.
- Link release docs directly to the `CHANGELOG.md` template to reduce process ambiguity.

## Scope Boundaries
### In scope
- Standardize unreleased changelog format in `CHANGELOG.md`.
- Add release documentation clarifying non-released vs release-ready notes and the release-cutoff step.
- Update `.agent/notes/FAC-81.md` with handoff context.

### Out of scope
- Changing release tooling, CI scripts, mix tasks, or package metadata.
- Adding automation for changelog generation.
- Modifying tests.

## Validation
- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- Manual markdown review for heading placement and release workflow clarity.
