# FAC-55 Implementation Plan

## Problem

Permission filtering currently treats `required_role` as a single atom and performs a single `allowed?/2` check per component. This blocks composable authorization patterns needed by larger apps:

- Inherited/default role context (for example admin users inheriting member roles)
- Required-role composition (`all_of`, `any_of`)
- Explicit deny rules that must override allow checks
- Validation errors when policy declarations are malformed

## Design

Implement a normalized policy model in `JsonLiveviewRender.Permissions` and evaluate that model during `filter/4`.

- Add `normalize_policy/1` that accepts:
  - atom role declarations
  - list declarations (legacy shorthand, equivalent to `%{any_of: [...]}`)
  - map declarations:
    - `%{any_of: [...]}`
    - `%{all_of: [...]}`
    - optional `%{deny: ...}` (default empty)
- Expand effective user roles via a deterministic helper using `current_user` context.
- Evaluate deny-first precedence:
  - If any deny term matches the user context, deny immediately.
  - Otherwise evaluate allows:
    - `any_of`: allow when any term matches
    - `all_of`: allow when all terms match
    - legacy atom: treated as a single `any_of` item
- Keep one compatibility path for single-atom policies and simple `allowed?/2` use.
- Provide explicit validation errors with `ArgumentError` when:
  - current policy type is malformed
  - expected role lists are not list-like
  - map keys are unsupported
  - deny/role entries are malformed

## Files to Change

1. `lib/json_liveview_render/catalog/component_def.ex`
- Extend permission type to support atomic and composed policy values.
- Relax `put_permission/2` to accept composed values while retaining legacy compatibility.
- Update function specs and docs.

2. `lib/json_liveview_render/catalog.ex`
- Relax the `permission/1` DSL guard to accept composed declarations.
- Validate composed policy shape in one place by deferring to `ComponentDef.put_permission/2`.

3. `lib/json_liveview_render/authorizer.ex`
- Keep `allowed?/2` callback name and arity unchanged.
- Widen second-arg type from atom to term while keeping behavior contract and default module semantics.

4. `lib/json_liveview_render/permissions.ex`
- Add normalized policy representation and policy normalization/validation helpers.
- Add role expansion helper(s) from `current_user` (including inherited roles, deterministic merge).
- Implement deny-first precedence and `all_of` / `any_of` checks.
- Keep fallback path untouched for no policy and unknown components.

5. `test/json_liveview_render/permissions_test.exs`
- Add tests for:
  - list shorthand semantics (default `any_of`)
  - explicit `%{all_of: ...}` and `%{any_of: ...}`
  - deny precedence over allow
  - inherited roles from current_user context
  - malformed role declarations returning explicit errors
  - nested component filtering with inherited policy composition

6. `README.md`
- Add examples for inheritance and composed role policies.
- Document default behavior for list shorthand and deny precedence.

7. `test/json_liveview_render/schema_prompt_test` fixtures where needed
- Preserve existing atom behavior assertions and add composed-policy visibility only if prompt output changes.

8. `.agent/notes/FAC-55.md`
- Add implementation handoff notes with any assumptions/risks and validation outcome.

## Key Decisions

1. Keep `allowed?/2` behavior stable and unchanged in arity/signature.
2. Treat list policy declarations as shorthand for `%{any_of: list}` for backwards compatibility.
3. Default list/any_of behavior is permissive-or (`any_of`) unless explicitly declared as `all_of`.
4. Evaluate deny rules before allow rules.
5. Implement policy validation in `Permissions` as explicit `ArgumentError` failures; do not silently coerce malformed declarations.
6. Keep catalog/renderer interfaces unchanged to avoid broad compatibility impact.
7. Preserve pure behavior in `filter/4` by avoiding side effects and using deterministic role expansion order.

## Scope Boundaries

### In Scope
- Permission policy normalization in `Permissions.filter/4`
- Inherited role expansion from `current_user`
- all_of/any_of and deny precedence semantics
- Validation for malformed policy declarations
- Unit test additions for allow/deny composition
- README updates with examples

### Out of Scope
- Authorizer behavior beyond current `allowed?/2` signature
- Component spec schema changes
- Streaming pipeline or renderer data-flow changes
- Registry validation or catalog coverage behavior

## Validation

1. Permissions support atom + list + map declarations with no regression to single-atom behavior.
2. Deny rules override allow outcomes.
3. `all_of` requires all required role predicates to pass; `any_of` requires any.
4. Current-user inheritance resolution is deterministic and visible via tests.
5. Malformed declarations raise `ArgumentError` with concrete messages.
6. `mix format --check-formatted` and `mix compile --warnings-as-errors` pass before commit.
