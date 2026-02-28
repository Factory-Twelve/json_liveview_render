# FAC-56 Handoff Notes

## Summary
Implemented golden contract coverage for schema and prompt exports using small/medium fixture catalogs.

## What Changed
- Added fixture catalogs for schema contracts:
  - `JsonLiveviewRenderTest.SchemaFixtures.SmallCatalog`
  - `JsonLiveviewRenderTest.SchemaFixtures.MediumCatalog`
- Added golden fixtures under `test/fixtures/schema`:
  - `small_catalog.json`, `small_prompt.txt`
  - `medium_catalog.json`, `medium_prompt.txt`
- Updated schema tests to compare outputs against fixture files and added strict-mode unknown-prop regression coverage.
- Added doctests for `JsonLiveviewRender.Schema.to_json_schema/1` and `to_prompt/1` examples.
- Made `JsonLiveviewRender.Schema` outputs deterministic:
  - JSON schema variant and property generation sorted by type/prop name.
  - Prompt generation sorts component and prop lines.
- Added changelog entry for v0.3 hardening work.

## Assumptions / Risks
- I could not execute `mix run` in this environment because Mix PubSub startup fails (`:eperm`); fixture JSON/prompt files were authored from deterministic builder logic.
- `test/fixtures/schema/*.txt` are text fixtures consumed by `schema_test.exs`.

## Next Steps
- Re-run `mix format --check-formatted` and `mix compile --warnings-as-errors` in an environment where `mix` commands are permitted.
- Commit using a FAC-56 message after checks are confirmed.
