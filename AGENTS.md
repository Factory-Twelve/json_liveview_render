# AGENTS.md

This repo is the core generative UI library for Phoenix LiveView.

Start here:
- `ARCHITECTURE.md`
- `docs/quality.md`
- `docs/architecture/`

Default workflow:
- Keep core library behavior under `lib/json_liveview_render/`.
- Keep Mix task entrypoints under `lib/mix/tasks/`.
- Preserve the Catalog -> Spec -> Render layering.
- Update architecture docs when changing public module boundaries or the release-family contract.

Do not turn the core library into an app-specific component bundle or a transport adapter kitchen sink.
