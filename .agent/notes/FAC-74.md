# FAC-74 Handoff Notes

Implemented seeded benchmark fixture generation for deterministic benchmark inputs with new `node_count`, `depth`, and `branching_factor` controls.

- `JsonLiveviewRender.Benchmark.Config` now accepts:
  - `--seed`
  - `--node-count`
  - `--depth`
  - `--branching-factor`
- Old shape flags remain mapped to `node_count` for compatibility:
  - `--sections`
  - `--columns`
  - `--metrics-per-column`
- `JsonLiveviewRender.Benchmark.Data` now builds a deterministic tree-shaped spec from the config using a pure deterministic RNG and emits required props for every type used (`metric`, `row`, `column`, `section`, `section_metric_card`).
- All generated elements include `"children"` (empty list for leaves) for validator compatibility.
- Runner text output now reports benchmark shape as `node_count`, `depth`, and `branching_factor`.
- Tests updated to exercise new parameters and alias mapping.

Notes for continuation:
- `JsonLiveviewRender.Benchmark.Data` still uses the existing benchmark catalog module (`JsonLiveviewRender.Benchmark.Catalog`) and registry; no dynamic catalog/module generation was introduced.
- `mix format --check-formatted` and `mix compile --warnings-as-errors` should be run before commit.
- If any follow-up wants to remove legacy shape flags, it can be done with a simple cleanup pass after updating external callers.
