---
name: repo-context
description: Use this skill before non-trivial changes in json_liveview_render to keep changes aligned with the Catalog -> Spec -> Render model and the public library boundary.
---

Before making non-trivial changes in this repo:

1. Read `ARCHITECTURE.md`.
2. Read `docs/quality.md`.
3. Check whether the change belongs in catalog, spec, schema, render, stream, or Mix-task layers.

Working rules:

- Preserve Catalog -> Spec -> Render as the core dependency direction.
- Keep the library app-agnostic.
- Avoid transport-specific or app-specific feature creep in the core package.
- Update the docs when public release-family scope changes.
