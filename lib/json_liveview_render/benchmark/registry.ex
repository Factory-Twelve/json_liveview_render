defmodule JsonLiveviewRender.Benchmark.Registry do
  use JsonLiveviewRender.Registry, catalog: JsonLiveviewRender.Benchmark.Catalog

  render(:row, &JsonLiveviewRender.Benchmark.Components.row/1)
  render(:column, &JsonLiveviewRender.Benchmark.Components.column/1)
  render(:metric, &JsonLiveviewRender.Benchmark.Components.metric/1)
  render(:section_metric_card, &JsonLiveviewRender.Benchmark.Components.section_metric_card/1)
end
