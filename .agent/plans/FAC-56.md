# FAC-56 Implementation Plan

## Problem
Schema and prompt exports are currently tested with loose assertions only, which allows accidental drift between catalog definitions, JSON Schema constraints, and strict validator behavior to slip in silently. We also need stable golden contracts for schema/prompt output to protect consumers from ordering and semantics regressions.

## Design
Use fixture-driven golden tests over representative catalogs to pin exact output contracts.

- Add two fixture catalogs to exercise contract breadth:
  - a small catalog with mandatory/required props and enum usage for minimal shape coverage
  - a medium catalog with multiple required/optional props, descriptions, permissions, and nested binding/list type coverage
- Export canonical golden fixtures under `test/fixtures/schema/` for both JSON Schema and prompt text.
- Normalize fixture generation and prompt checks with stable ordering (`Enum.sort_by` for components and props) so snapshots are deterministic.
- Add tests that compare output maps/strings against fixture files and validate strict-vs-permissive behavior for unknown props.
- Add doctests/examples in `JsonLiveviewRender.Schema` documentation for `to_json_schema/1` and `to_prompt/1`.

## Files to Change
- `.agent/plans/FAC-56.md` (create)
- `test/support/fixtures_helper.exs` (add small and medium catalog fixtures for contract tests)
- `test/fixtures/schema/small_catalog.json` (create)
- `test/fixtures/schema/small_prompt.txt` (create)
- `test/fixtures/schema/medium_catalog.json` (create)
- `test/fixtures/schema/medium_prompt.txt` (create)
- `test/json_liveview_render/schema_test.exs` (replace loose assertions with golden contract tests and strict-mode import regression test)
- `lib/json_liveview_render/schema/prompt_builder.ex` (sort component/prop order for deterministic prompt output)
- `lib/json_liveview_render/schema.ex` (add doctest coverage snippets)
- `CHANGELOG.md` (document validation hardening)
- `.agent/notes/FAC-56.md` (update handoff notes)

## Key Decisions
- Keep existing catalog DSL modules in `test/support/fixtures_helper.exs` to avoid extra fixture loading pathways and maintain test conventions.
- Use explicit golden fixture files for medium/small outputs to avoid brittle assertion coupling to internal map ordering.
- Keep validator strict behavior assertions in tests as behavior-level contracts rather than introducing snapshot tests for all possible errors.
- Keep required spec rule compliance (`children: []`) in fixtures and validation tests to avoid runtime crash patterns.

## Scope Boundaries
- In scope:
  - Golden contract tests for schema and prompt exports.
  - Deterministic normalization/order guarantees in prompt generation.
  - Strict-mode unknown-prop regression coverage.
  - Documentation snippet/doctest coverage for Schema export APIs.
  - Changelog entry for this hardening work.
- Out of scope:
  - Changes to runtime spec validator logic beyond tests and contract hardening assertions.
  - Streaming contract changes.
  - Registry/Catalog runtime behavior changes outside fixture coverage.

## Validation
- Verify golden fixtures for small and medium catalogs (schema and prompt) compare exactly.
- Add tests for `root/elements/children/properties/required` mappings and enum mapping in schema output.
- Add test proving an unknown property in spec fails strict validation while permissive mode allows it.
- Confirm prompt output includes descriptions, required/optional semantics, and deterministic component/prop ordering.
- Run `mix format --check-formatted` and `mix compile --warnings-as-errors` before finishing.
- Update `.agent/notes/FAC-56.md` with handoff details, assumptions, and any unresolved risks.
