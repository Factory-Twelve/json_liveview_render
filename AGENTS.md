# AGENTS.md

This repo is the core generative UI library for Phoenix LiveView.

Start here:
- `README.md`
- `ARCHITECTURE.md`
- `docs/quality.md`
- `docs/architecture/`
- `WORKFLOW.md` for unattended Linear/Symphony orchestration

Default workflow:
- Keep core library behavior under `lib/json_liveview_render/`.
- Keep Mix task entrypoints under `lib/mix/tasks/`.
- Preserve the Catalog -> Spec -> Render layering.
- For unattended Linear/Symphony runs, follow `WORKFLOW.md` status routing and repo-local `.codex/skills/`.
- Use repo-local `.codex/skills/pull`, `commit`, `push`, `request-review`, and `land` for branch sync, review, and auto-landing; use `debug`/`linear` for Symphony run diagnostics or raw Linear GraphQL.
- Keep transport-specific work in documented companion/deferred surfaces; do not promote it into the core render contract.
- Update architecture docs when changing public module boundaries or the release-family contract.

Common commands:
- `mix test` for the required focused validation gate.
- `mix ci` for format, warnings-as-errors compile, and tests.
- `make ci-local` for the local CI plan's Elixir 1.15 slot; `make ci-local-full` for the documented 1.15 and 1.19 matrix.
- `make release-check` before release/publish work.
- `make benchmark` for local benchmark text output; `make benchmark-ci` for CI-style JSON benchmark output.

Do not turn the core library into an app-specific component bundle or a transport adapter kitchen sink.
