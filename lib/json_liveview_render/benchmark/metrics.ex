defmodule JsonLiveviewRender.Benchmark.Metrics do
  @moduledoc false

  @type benchmark_metric :: %{
          required(:iterations) => non_neg_integer(),
          required(:total_microseconds) => integer(),
          required(:mean_microseconds) => float(),
          required(:min_microseconds) => integer(),
          required(:max_microseconds) => integer(),
          required(:p95_microseconds) => integer(),
          required(:p99_microseconds) => integer()
        }

  @spec measure(integer(), (-> any())) :: benchmark_metric()
  def measure(iterations, fun)
      when is_integer(iterations) and iterations > 0 and is_function(fun, 0) do
    timings =
      Enum.map(1..iterations, fn _ ->
        {time, _result} = :timer.tc(fun)
        time
      end)

    sorted_timings = Enum.sort(timings)
    analyze(sorted_timings)
  end

  defp analyze(sorted_timings) do
    count = length(sorted_timings)
    total = Enum.sum(sorted_timings)

    %{
      iterations: count,
      total_microseconds: total,
      mean_microseconds: total / count,
      min_microseconds: List.first(sorted_timings),
      max_microseconds: List.last(sorted_timings),
      p95_microseconds: percentile(sorted_timings, 95),
      p99_microseconds: percentile(sorted_timings, 99)
    }
  end

  defp percentile(sorted_timings, percentile) when is_list(sorted_timings) do
    size = length(sorted_timings)
    index = max(round(size * percentile / 100.0) - 1, 0)
    Enum.at(sorted_timings, index)
  end
end
