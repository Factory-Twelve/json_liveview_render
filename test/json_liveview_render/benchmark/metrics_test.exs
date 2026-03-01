defmodule JsonLiveviewRender.Benchmark.MetricsTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Benchmark.Metrics

  test "collects latency percentiles and throughput" do
    metrics = Metrics.measure(3, fn -> 1 + 1 end)

    assert is_integer(metrics.total_microseconds)
    assert is_integer(metrics.p50_microseconds)
    assert is_integer(metrics.p95_microseconds)
    assert is_integer(metrics.p99_microseconds)
    assert is_float(metrics.throughput_ops_per_second)
  end

  test "collects optional memory statistics when enabled" do
    metrics = Metrics.measure(3, fn -> :ok end, memory: true)

    assert is_integer(metrics.memory_total_bytes)
    assert is_float(metrics.memory_mean_bytes)
    assert is_integer(metrics.memory_min_bytes)
    assert is_integer(metrics.memory_max_bytes)
    assert is_integer(metrics.memory_p50_bytes)
    assert is_integer(metrics.memory_p95_bytes)
  end
end
