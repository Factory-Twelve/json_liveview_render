# FAC-72 Handoff Notes

Implemented changes for validate/2 benchmark path scenarios with three deterministic tiers and memory-enabled validate metrics.

- Added memory collection to `JsonLiveviewRender.Benchmark.Suite.Validate` via `Metrics.measure(..., memory: true)`.
- Updated matrix definitions in `JsonLiveviewRender.Benchmark.Matrix` to 3 fixed cases:
  - small
  - typical
  - pathological (`1k+` nodes)
- Updated benchmark task tests to match the new matrix case count and naming.
- Expanded validate suite test assertions to include memory metrics.
- Added README benchmark baseline notes for deterministic validate tier measurements.

If the benchmark baseline numbers drift in future runs, rerun `mix json_liveview_render.bench --matrix --suites validate --seed 20260301 --iterations <n> --format json` and update the documented baseline snapshot.
