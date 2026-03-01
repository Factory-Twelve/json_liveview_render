defmodule JsonLiveviewRender.Benchmark.Suite.RenderTest do
  use ExUnit.Case, async: false

  alias JsonLiveviewRender.Benchmark.Config
  alias JsonLiveviewRender.Benchmark.Data
  alias JsonLiveviewRender.Benchmark.Suite.Render

  test "render suite includes memory and p50 metrics" do
    config = Config.from_options(iterations: 2, node_count: 1, depth: 1, branching_factor: 1)
    context = Data.setup(config)

    result = Render.run(config, context)

    assert result.name == "render"
    assert result.status == :ok

    metrics = result.metrics
    assert is_integer(metrics.p50_microseconds)
    assert is_integer(metrics.p95_microseconds)
    assert is_float(metrics.throughput_ops_per_second)
    assert is_integer(metrics.memory_total_bytes)
    assert is_float(metrics.memory_mean_bytes)
    assert is_integer(metrics.memory_p50_bytes)
    assert is_integer(metrics.memory_p95_bytes)
  end
end
