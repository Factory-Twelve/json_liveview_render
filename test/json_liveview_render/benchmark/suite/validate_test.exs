defmodule JsonLiveviewRender.Benchmark.Suite.ValidateTest do
  use ExUnit.Case, async: false

  alias JsonLiveviewRender.Benchmark.Config
  alias JsonLiveviewRender.Benchmark.Data
  alias JsonLiveviewRender.Benchmark.Suite.Validate

  test "run returns validate result with expected map shape" do
    config = Config.from_options(iterations: 1, node_count: 1, depth: 1, branching_factor: 1)
    context = Data.setup(config)

    result = Validate.run(config, context)

    assert is_map(result)
    assert map_size(result) == 3

    assert %{
             name: "validate",
             status: :ok,
             metrics: metrics
           } = result

    assert map_size(metrics) >= 13
    assert metrics.iterations == 1
    assert is_integer(metrics.total_microseconds)
    assert is_number(metrics.mean_microseconds)
    assert is_integer(metrics.p50_microseconds)
    assert is_float(metrics.throughput_ops_per_second)
    assert is_integer(metrics.memory_total_bytes)
    assert is_float(metrics.memory_mean_bytes)
    assert is_integer(metrics.memory_p50_bytes)
    assert is_integer(metrics.memory_p95_bytes)
  end
end
