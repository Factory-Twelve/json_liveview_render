defmodule JsonLiveviewRender.Benchmark.Catalog do
  use JsonLiveviewRender.Catalog

  component :metric do
    description("Benchmark metric leaf")
    prop(:label, :string, required: true)
    prop(:value, :string, required: true)
  end

  component :section_metric_card do
    description("Benchmark section wrapper")
    prop(:title, :string, required: true)
  end
end
