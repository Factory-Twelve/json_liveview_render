---
tracker:
  kind: linear
  project_slug: "json_liveview_render-b9bb581f0a42"
  active_states:
    - Todo
    - In Progress
    - Human Review
    - Merging
    - Rework
  terminal_states:
    - Done
    - Canceled
    - Cancelled
    - Closed
    - Duplicate
polling:
  interval_ms: 300000
workspace:
  root: ~/code/symphony-workspaces/json_liveview_render
hooks:
  after_create: |
    git clone --depth 1 https://github.com/Factory-Twelve/json_liveview_render.git .
    mix deps.get
  before_remove: |
    branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$branch" ] && command -v gh >/dev/null 2>&1; then
      gh pr list --head "$branch" --state open --json number         --jq '.[].number' | while read -r pr; do
        [ -n "$pr" ] && gh pr close "$pr"           --comment "Closing: Linear issue reached terminal state."
      done
    fi
  before_run: |
    git restore --source=HEAD --worktree .codex 2>/dev/null || true
    git clean -fd .codex
agent:
  max_concurrent_agents: 3
  max_turns: 20
codex:
  command: >-
    codex
    --config shell_environment_policy.inherit=all
    --config model_reasoning_effort=high
    --model gpt-5.4
    app-server
  approval_policy: never
  thread_sandbox: danger-full-access
  turn_sandbox_policy:
    type: dangerFullAccess
---

You are working on Linear ticket `{{ issue.identifier }}` in the **json_liveview_render** repository — an Elixir library for agent-safe generative UI on Phoenix LiveView.

{% if attempt %}
## Continuation

This is retry attempt #{{ attempt }}. The ticket is still active.
- Resume from current workspace state — do not restart from scratch.
- Do not repeat completed investigation/validation unless needed for new changes.
- Do not end the turn while the issue remains active unless truly blocked.
{% endif %}

## Issue Context

- **Identifier:** {{ issue.identifier }}
- **Title:** {{ issue.title }}
- **Status:** {{ issue.state }}
- **Labels:** {{ issue.labels }}
- **URL:** {{ issue.url }}

### Description

{% if issue.description %}
{{ issue.description }}
{% else %}
No description provided.
{% endif %}

## Project Conventions

- **Elixir library** targeting Phoenix LiveView
- Preserve public API clarity and docs quality
- Prefer explicit options/contracts over magic behavior
- Keep generated/rendering semantics deterministic and testable

## Operating Rules

1. This is an unattended orchestration session. Never ask a human to perform follow-up actions.
2. Only stop early for a true blocker (missing auth/permissions/secrets). Record blockers in the workpad.
3. Final message: report completed actions and blockers only. No "next steps for user."

## Workflow

### Status Routing

| State | Action |
|-------|--------|
| `Backlog` | Do not touch. Wait for human. |
| `Todo` | Move to `In Progress`, create workpad, start execution. If PR already attached, run feedback sweep first. |
| `In Progress` | Continue execution from workpad. |
| `Human Review` | Legacy/manual hold state. Prefer auto-landing once review + checks are clean unless the ticket explicitly requires human hold. |
| `Merging` | Open and follow `.codex/skills/land/SKILL.md`. Do NOT call `gh pr merge` directly. |
| `Rework` | Full reset: close existing PR, delete workpad, fresh branch from `origin/main`, restart. |
| `Done` | Shut down. |

### Workpad

Use a single persistent Linear comment (`## Codex Workpad`) as the source of truth.

### Validation

- `mix test`
- `mix ci` before handoff when reasonable

### Execution Flow

1. Move to `In Progress` if currently `Todo`.
2. Find or create the workpad comment.
3. Reconcile plan and acceptance criteria.
4. Reproduce first.
5. Run `pull` skill to sync with `origin/main`.
6. Implement, validate, self-review diff, push.
7. Request Codex review and sweep all PR feedback.
8. When Codex Connector passes cleanly and checks are green, move the issue to `Merging`, run `.codex/skills/land/SKILL.md`, and auto-land the PR.
9. After merge succeeds, move the issue to `Done` and stop.

## Guardrails

- If branch PR is closed/merged, create fresh branch from `origin/main`.
- Do not edit the issue body for planning — use the workpad comment only.
- One workpad comment per issue.
- In `Human Review`, do not make changes.
