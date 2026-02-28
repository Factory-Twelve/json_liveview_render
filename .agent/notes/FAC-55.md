# FAC-55 Handoff Notes

## Summary
Implemented permission model inheritance and composition support across catalog policy declarations and permission filtering.

## What Changed
- `lib/json_liveview_render/catalog/component_def.ex`
  - Expanded `permission` field typing and removed atom-only restriction in `put_permission/2`.
- `lib/json_liveview_render/catalog.ex`
  - Relaxed `permission/1` setter guard so catalog policies can be atom, list, or map declarations.
- `lib/json_liveview_render/authorizer.ex`
  - Widened `JsonLiveviewRender.Authorizer.allowed?/2` required role argument from atom to term for compatibility with composed policies.
- `lib/json_liveview_render/permissions.ex`
  - Added policy normalization and validation for:
    - atom (legacy)
    - list (default `any_of`)
    - map with `:any_of`, `:all_of`, and optional `:deny`
  - Added inheritance-aware role resolution from `current_user` via:
    - `:roles` or `:role` input
    - optional `:role_inheritance` map
  - Added deny-first precedence and per-policy allow evaluation logic.
- `lib/json_liveview_render/schema/prompt_builder.ex`
  - Expanded policy rendering to print composed policy forms deterministically.
- `test/json_liveview_render/permissions_test.exs`
  - Added tests for shorthand list policies, `all_of`, deny precedence, malformed declarations, and inheritance/nested policy behavior.
- `README.md`
  - Added permission policy composition examples and defaults.

## Assumptions / Risks
- Inheritance input is assumed on `current_user` as `:roles` (or `:role`) plus optional `:role_inheritance` map.
- Authorization behavior remains backwards compatible through existing `allowed?/2` callback; composed checks still call the callback for policy terms not matched by inherited role keys.

## Validation
- `mix format` run and applied.
- `mix format --check-formatted` passes.
- `mix compile --warnings-as-errors` could not complete in this environment because Mix PubSub fails to open a TCP socket (`:eperm`).
