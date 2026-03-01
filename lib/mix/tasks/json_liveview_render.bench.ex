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
  """

  @switches [
    ci: :boolean,
    matrix: :boolean,
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
      if parsed[:ci] == nil do
        Keyword.put(parsed, :ci, ci_env?())
      else
        parsed
      end

    config =
      try do
        JsonLiveviewRender.Benchmark.Config.from_options(parsed)
      rescue
        exception in [ArgumentError] ->
          Mix.raise("invalid benchmark options: #{Exception.message(exception)}")
      end

    output =
      if Keyword.get(parsed, :matrix, false) do
        matrix_reports =
          JsonLiveviewRender.Benchmark.Matrix.configs_for(config)
          |> Enum.map(&JsonLiveviewRender.Benchmark.Runner.run/1)

        case config.format do
          :json -> format_matrix_json(matrix_reports)
          :text -> format_matrix_text(matrix_reports)
        end
      else
        report = JsonLiveviewRender.Benchmark.Runner.run(config)

        case config.format do
          :json ->
            JsonLiveviewRender.Benchmark.Runner.format_json(report)

          :text ->
            JsonLiveviewRender.Benchmark.Runner.render_text(report)
        end
      end

    Mix.shell().info(output)
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

  defp format_matrix_json(matrix_reports) do
    Jason.encode_to_iodata!(%{matrix: true, cases: matrix_reports}, pretty: true)
  end

  defp format_matrix_text(matrix_reports) do
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

    ["JsonLiveviewRender Bench Harness Matrix\n", "\n" | case_blocks]
  end
end
