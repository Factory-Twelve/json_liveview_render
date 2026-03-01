# FAC-73 Handoff Notes

Implemented benchmark render hot-path coverage with matrix-style depth/width cases and a dedicated 1k+ tree case.

- Added matrix execution mode via `mix json_liveview_render.bench --matrix`.
- Matrix cases now include deterministic labels and derived seeds:
  - `depth_4_width_2`
  - `depth_4_width_4`
  - `depth_5_width_2`
  - `depth_5_width_4`
  - `depth_6_width_4_nodes_1024`
- `JsonLiveviewRender.Benchmark.Config` now carries optional `case_name` for reporting.
- `JsonLiveviewRender.Benchmark.Metrics` now always reports:
  - p50 latency
  - throughput ops/sec
  - plus optional memory stats when memory collection is enabled.
- `render` suite enables memory collection to measure hot-path render memory behavior.
- `JsonLiveviewRender.Benchmark.Runner` and task text output now include p50 and new throughput/memory fields.
- README benchmark section updated to document matrix mode and new metric fields.

Implementation notes:
- JSON matrix output shape when `--matrix` is enabled: `%{"matrix" => true, "cases" => [report_1, ...]}`.
- Text matrix output prints each case block prefixed with `Case N: <case_name>`.

Potential follow-up:
- If benchmark run time becomes too high, adjust matrix case depth/width counts and/or iterations defaults for CI profiles.
