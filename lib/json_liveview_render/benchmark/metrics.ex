defmodule JsonLiveviewRender.Benchmark.Metrics do
  @moduledoc false

  @type benchmark_metric :: %{
          required(:iterations) => non_neg_integer(),
          required(:total_microseconds) => integer(),
          required(:mean_microseconds) => float(),
          required(:min_microseconds) => integer(),
          required(:max_microseconds) => integer(),
          required(:p50_microseconds) => integer(),
          required(:p95_microseconds) => integer(),
          required(:p99_microseconds) => integer(),
          required(:throughput_ops_per_second) => float(),
          optional(:memory_total_bytes) => integer(),
          optional(:memory_mean_bytes) => float(),
          optional(:memory_min_bytes) => integer(),
          optional(:memory_max_bytes) => integer(),
          optional(:memory_p50_bytes) => integer(),
          optional(:memory_p95_bytes) => integer()
        }

  @spec measure(integer(), (-> any())) :: benchmark_metric()
  @spec measure(integer(), (-> any()), Keyword.t()) :: benchmark_metric()
  def measure(iterations, fun, opts \\ [])
      when is_integer(iterations) and iterations > 0 and is_function(fun, 0) and is_list(opts) do
    include_memory = Keyword.get(opts, :memory, false)

    samples =
      Enum.map(1..iterations, fn _ ->
        before = if include_memory, do: :erlang.memory(:total), else: 0

        {time, _result} = :timer.tc(fun)

        after_mem = if include_memory, do: :erlang.memory(:total), else: 0
        memory_bytes = if include_memory, do: max(after_mem - before, 0), else: nil

        {time, memory_bytes}
      end)

    timings = Enum.map(samples, &elem(&1, 0))
    memory_samples = Enum.map(samples, &elem(&1, 1)) |> Enum.filter(&is_integer/1)

    analyze(iterations, timings, memory_samples, include_memory)
  end

  defp analyze(iterations, timings, memory_samples, true) do
    timings_tuple = List.to_tuple(Enum.sort(timings))
    memory_tuple = List.to_tuple(Enum.sort(memory_samples))
    analyze_metrics(iterations, timings_tuple, memory_tuple, memory_samples)
  end

  defp analyze(iterations, timings, _memory_samples, false) do
    timings_tuple = List.to_tuple(Enum.sort(timings))
    analyze_metrics(iterations, timings_tuple, nil, [])
  end

  defp analyze_metrics(iterations, timings_tuple, memory_tuple, memory_samples) do
    count = tuple_size(timings_tuple)
    total = tuple_sum(timings_tuple)
    throughput = if total > 0, do: iterations * 1_000_000.0 / total, else: 0.0

    base_metrics = %{
      iterations: count,
      total_microseconds: total,
      mean_microseconds: total / count,
      min_microseconds: elem(timings_tuple, 0),
      max_microseconds: elem(timings_tuple, count - 1),
      p50_microseconds: percentile(timings_tuple, count, 50),
      p95_microseconds: percentile(timings_tuple, count, 95),
      p99_microseconds: percentile(timings_tuple, count, 99),
      throughput_ops_per_second: throughput
    }

    if memory_tuple == nil do
      base_metrics
    else
      memory_count = length(memory_samples)
      memory_total = Enum.sum(memory_samples)
      memory_min = elem(memory_tuple, 0)
      memory_max = elem(memory_tuple, memory_count - 1)

      base_metrics
      |> Map.put(:memory_total_bytes, memory_total)
      |> Map.put(:memory_mean_bytes, memory_total / memory_count)
      |> Map.put(:memory_min_bytes, memory_min)
      |> Map.put(:memory_max_bytes, memory_max)
      |> Map.put(:memory_p50_bytes, percentile(memory_tuple, memory_count, 50))
      |> Map.put(:memory_p95_bytes, percentile(memory_tuple, memory_count, 95))
    end
  end

  defp tuple_sum(tuple) do
    tuple_size = tuple_size(tuple)

    Enum.reduce(0..(tuple_size - 1), 0, fn index, acc ->
      acc + elem(tuple, index)
    end)
  end

  defp percentile(sorted_tuple, size, pct) do
    index = max(round(size * pct / 100.0) - 1, 0)
    elem(sorted_tuple, index)
  end
end
