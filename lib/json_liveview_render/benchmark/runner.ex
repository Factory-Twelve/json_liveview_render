defmodule JsonLiveviewRender.Benchmark.Runner do
  @moduledoc false

  alias JsonLiveviewRender.Benchmark.{Config, Data, Suites}

  @spec run(Config.t()) :: map()
  def run(%Config{} = config) do
    context = Data.setup(config)

    suites =
      try do
        Suites.run(config, context)
      after
        Data.teardown(context)
      end

    %{
      metadata: metadata(config),
      config: Config.to_map(config),
      suites: suites
    }
  end

  defp metadata(_config) do
    %{
      benchmarked_at_utc: DateTime.utc_now() |> DateTime.to_iso8601(),
      project: project_metadata(),
      machine: machine_metadata()
    }
  end

  defp project_metadata do
    project = Mix.Project.config()

    %{
      app: project[:app],
      version: project[:version],
      elixir: System.version(),
      otp_release: to_string(:erlang.system_info(:otp_release)),
      source_url: project[:source_url]
    }
  end

  defp machine_metadata do
    os_type =
      :os.type()
      |> Tuple.to_list()
      |> Enum.join("/")

    %{
      os_type: os_type,
      system_version: to_string(:erlang.system_info(:system_version)),
      logical_processors: logical_processor_count(),
      schedulers_online: :erlang.system_info(:schedulers_online),
      process_count: process_count(),
      word_size: word_size()
    }
  end

  defp logical_processor_count do
    case :erlang.system_info(:logical_processors_online) do
      value when is_integer(value) -> value
      :unknown -> :unknown
      _ -> :unknown
    end
  end

  defp process_count do
    :erlang.system_info(:process_count)
  end

  defp word_size do
    fetch_system_info(:wordsize_external) || fetch_system_info(:wordsize)
  end

  defp fetch_system_info(item) do
    try do
      :erlang.system_info(item)
    rescue
      ArgumentError ->
        nil
    end
  end

  @spec format_json(map()) :: iodata()
  def format_json(report), do: Jason.encode_to_iodata!(report, pretty: true)

  @spec render_text(map()) :: iodata()
  def render_text(report) do
    suite_lines =
      Enum.map(report.suites, fn suite ->
        metrics = suite.metrics

        memory_lines =
          if Map.has_key?(metrics, :memory_total_bytes) do
            [
              "    memory_total_bytes=",
              format_memory(metrics.memory_total_bytes),
              "\n",
              "    memory_mean_bytes=",
              format_memory(metrics.memory_mean_bytes),
              "\n",
              "    memory_min_bytes=",
              format_memory(metrics.memory_min_bytes),
              "\n",
              "    memory_max_bytes=",
              format_memory(metrics.memory_max_bytes),
              "\n",
              "    memory_p50_bytes=",
              format_memory(metrics.memory_p50_bytes),
              "\n",
              "    memory_p95_bytes=",
              format_memory(metrics.memory_p95_bytes),
              "\n"
            ]
          else
            []
          end

        [
          "  suite=",
          suite.name,
          "\n",
          "    iterations=",
          Integer.to_string(metrics.iterations),
          "\n",
          "    total_ms=",
          format_ms(metrics.total_microseconds),
          "\n",
          "    mean_ms=",
          format_ms(metrics.mean_microseconds),
          "\n",
          "    min_ms=",
          format_ms(metrics.min_microseconds),
          "\n",
          "    max_ms=",
          format_ms(metrics.max_microseconds),
          "\n",
          "    p50_ms=",
          format_ms(metrics.p50_microseconds),
          "\n",
          "    p95_ms=",
          format_ms(metrics.p95_microseconds),
          "\n",
          "    p99_ms=",
          format_ms(metrics.p99_microseconds),
          "\n",
          "    throughput_ops_per_second=",
          format_rate(metrics.throughput_ops_per_second),
          "\n"
          | memory_lines
        ]
      end)

    [
      "JsonLiveviewRender Bench Harness\n",
      "\n",
      "Config:\n",
      "  iterations=",
      Integer.to_string(report.config.iterations),
      "\n",
      if(Map.get(report.config, :case_name),
        do: ["  case_name=", to_string(Map.get(report.config, :case_name)), "\n"],
        else: []
      ),
      "  suites=",
      Enum.join(report.config.suites, ","),
      "\n",
      "  seed=",
      Integer.to_string(report.config.seed),
      "\n",
      "  node_count=",
      Integer.to_string(report.config.node_count),
      "\n",
      "  depth=",
      Integer.to_string(report.config.depth),
      "\n",
      "  branching_factor=",
      Integer.to_string(report.config.branching_factor),
      "\n",
      "  format=",
      to_string(report.config.format),
      "\n",
      "  ci=",
      to_string(report.config.ci),
      "\n",
      "\n",
      "Metadata:\n",
      "  project=",
      to_string(report.metadata.project.app),
      "/",
      report.metadata.project.version,
      "\n",
      "  elixir=",
      report.metadata.project.elixir,
      "\n",
      "  otp=",
      report.metadata.project.otp_release,
      "\n",
      "  os=",
      report.metadata.machine.os_type,
      "\n",
      "  logical_processors=",
      metric_to_string(report.metadata.machine.logical_processors),
      "\n",
      "  schedulers_online=",
      metric_to_string(report.metadata.machine.schedulers_online),
      "\n",
      "  word_size=",
      metric_to_string(report.metadata.machine.word_size),
      "\n",
      "  timestamp_utc=",
      report.metadata.benchmarked_at_utc,
      "\n",
      "\n",
      "Results:\n",
      suite_lines,
      "\n"
    ]
  end

  defp format_ms(value) do
    (value / 1000)
    |> Float.round(3)
    |> :erlang.float_to_binary(decimals: 3)
  end

  defp format_rate(value) when is_float(value) do
    value
    |> Float.round(3)
    |> :erlang.float_to_binary(decimals: 3)
  end

  defp format_memory(value) when is_integer(value), do: Integer.to_string(value)
  defp format_memory(value) when is_float(value), do: Float.to_string(Float.round(value, 3))
  defp format_memory(value), do: to_string(value)

  defp metric_to_string(value) when is_integer(value), do: Integer.to_string(value)
  defp metric_to_string(value) when value in [:unknown, nil], do: "unknown"
  defp metric_to_string(value), do: to_string(value)
end
