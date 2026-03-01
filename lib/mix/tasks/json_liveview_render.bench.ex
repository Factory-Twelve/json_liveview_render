defmodule Mix.Tasks.JsonLiveviewRender.Bench do
  use Mix.Task

  @shortdoc "Run JsonLiveviewRender benchmark harness"
  @moduledoc """
  Runs benchmark suites for validate and render hot paths.

  ## Usage

      mix json_liveview_render.bench
      mix json_liveview_render.bench --iterations 200 --suites validate,render
      mix json_liveview_render.bench --seed 42 --node-count 20 --depth 4 --branching-factor 3
      mix json_liveview_render.bench --format json
      mix json_liveview_render.bench --matrix --seed 20260301 --iterations 3
      mix json_liveview_render.bench --matrix --guardrail-fail
  """

  @switches [
    ci: :boolean,
    matrix: :boolean,
    guardrail: :boolean,
    guardrail_fail: :boolean,
    guardrail_thresholds: :string,
    format: :string,
    iterations: :integer,
    seed: :integer,
    suites: :string,
    sections: :integer,
    columns: :integer,
    metrics_per_column: :integer,
    node_count: :integer,
    depth: :integer,
    branching_factor: :integer
  ]

  @impl true
  def run(argv) do
    {parsed, positionals, invalid} = OptionParser.parse(argv, switches: @switches)

    if invalid != [] do
      raise_invalid_args!(invalid)
    end

    if positionals != [] do
      Mix.raise("unexpected positional argument(s): #{inspect(positionals)}")
    end

    parsed =
      parsed
      |> put_default(:ci, ci_env?())
      |> put_default(:guardrail, true)
      |> put_default(:guardrail_fail, guardrail_fail_env?())

    validate_guardrail_options!(parsed)

    matrix? = Keyword.get(parsed, :matrix, false)
    guardrail_enabled? = Keyword.get(parsed, :guardrail, true)
    guardrail_fail? = Keyword.get(parsed, :guardrail_fail, false)
    guardrail_thresholds = Keyword.get(parsed, :guardrail_thresholds)

    config =
      try do
        parsed
        |> config_options()
        |> JsonLiveviewRender.Benchmark.Config.from_options()
      rescue
        exception in [ArgumentError] ->
          Mix.raise("invalid benchmark options: #{Exception.message(exception)}")
      end

    reports =
      if matrix? do
        JsonLiveviewRender.Benchmark.Matrix.configs_for(config)
        |> Enum.map(&JsonLiveviewRender.Benchmark.Runner.run/1)
      else
        [JsonLiveviewRender.Benchmark.Runner.run(config)]
      end

    guardrail_result =
      if guardrail_enabled? do
        thresholds =
          JsonLiveviewRender.Benchmark.Guardrail.load_thresholds(
            guardrail_thresholds ||
              JsonLiveviewRender.Benchmark.Guardrail.default_thresholds_path()
          )

        JsonLiveviewRender.Benchmark.Guardrail.evaluate(reports, thresholds)
        |> Map.put(:mode, guardrail_mode(guardrail_fail?))
      end

    output =
      if matrix? do
        matrix_output(reports, config.format, guardrail_result)
      else
        report = hd(reports)
        single_report_output(report, config.format, guardrail_result)
      end

    output
    |> IO.iodata_to_binary()
    |> String.trim_trailing()
    |> Mix.shell().info()

    if guardrail_fail? and guardrail_result != nil and guardrail_result.status == :fail do
      Mix.raise(
        "benchmark guardrail failed: #{guardrail_result.failure_count} regression(s) exceeded thresholds"
      )
    end
  end

  defp raise_invalid_args!(entries) do
    details =
      entries
      |> Enum.map(fn {name, value} ->
        "  #{name}: #{inspect(value)}"
      end)
      |> Enum.join("\n")

    Mix.raise("Invalid option(s) detected:\n#{details}")
  end

  defp ci_env? do
    System.get_env("CI") == "true"
  end

  defp put_default(options, key, default_value) do
    if options[key] == nil do
      Keyword.put(options, key, default_value)
    else
      options
    end
  end

  defp guardrail_fail_env? do
    case System.get_env("BENCH_GUARDRAIL_FAIL") do
      value when value in ["1", "true", "TRUE", "yes", "YES"] -> true
      _ -> false
    end
  end

  defp validate_guardrail_options!(parsed) do
    if Keyword.get(parsed, :guardrail, true) == false and
         Keyword.get(parsed, :guardrail_fail, false) do
      Mix.raise("--guardrail-fail cannot be used with --no-guardrail")
    end
  end

  defp config_options(options) do
    Keyword.drop(options, [:matrix, :guardrail, :guardrail_fail, :guardrail_thresholds])
  end

  defp guardrail_mode(true), do: :fail_on_regression
  defp guardrail_mode(false), do: :report_only

  defp single_report_output(report, :json, guardrail_result) do
    report
    |> maybe_attach_guardrail(guardrail_result)
    |> JsonLiveviewRender.Benchmark.Runner.format_json()
  end

  defp single_report_output(report, :text, guardrail_result) do
    [
      JsonLiveviewRender.Benchmark.Runner.render_text(report),
      maybe_render_guardrail_text(guardrail_result)
    ]
  end

  defp matrix_output(matrix_reports, :json, guardrail_result) do
    %{matrix: true, cases: matrix_reports}
    |> maybe_attach_guardrail(guardrail_result)
    |> Jason.encode_to_iodata!(pretty: true)
  end

  defp matrix_output(matrix_reports, :text, guardrail_result) do
    case_blocks =
      matrix_reports
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {report, index} ->
        [
          "Case ",
          Integer.to_string(index),
          ": ",
          report.config.case_name || "default",
          "\n",
          JsonLiveviewRender.Benchmark.Runner.render_text(report)
        ]
      end)

    [
      "JsonLiveviewRender Bench Harness Matrix\n",
      "\n",
      case_blocks,
      maybe_render_guardrail_text(guardrail_result)
    ]
  end

  defp maybe_attach_guardrail(payload, nil), do: payload

  defp maybe_attach_guardrail(payload, guardrail_result),
    do: Map.put(payload, :guardrail, guardrail_result)

  defp maybe_render_guardrail_text(nil), do: []

  defp maybe_render_guardrail_text(guardrail_result) do
    [
      "\n",
      JsonLiveviewRender.Benchmark.Guardrail.render_text(guardrail_result),
      "  mode=",
      Atom.to_string(guardrail_result.mode),
      "\n"
    ]
  end
end
