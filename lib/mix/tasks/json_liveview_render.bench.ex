defmodule Mix.Tasks.JsonLiveviewRender.Bench do
  use Mix.Task

  @shortdoc "Run JsonLiveviewRender benchmark harness"
  @moduledoc """
  Runs benchmark suites for validate and render hot paths.

  ## Usage

      mix json_liveview_render.bench
      mix json_liveview_render.bench --iterations 200 --suites validate,render
      mix json_liveview_render.bench --seed 42 --sections 20 --columns 3 --metrics-per-column 10
      mix json_liveview_render.bench --format json
  """

  @switches [
    ci: :boolean,
    format: :string,
    iterations: :integer,
    metrics_per_column: :integer,
    seed: :integer,
    sections: :integer,
    columns: :integer,
    suites: :string
  ]

  @impl true
  def run(argv) do
    {parsed, _positionals, invalid} = OptionParser.parse(argv, switches: @switches)

    if invalid != [] do
      raise_invalid_args!(invalid)
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

    report = JsonLiveviewRender.Benchmark.Runner.run(config)

    output =
      case config.format do
        :json ->
          JsonLiveviewRender.Benchmark.Runner.format_json(report)

        :text ->
          JsonLiveviewRender.Benchmark.Runner.render_text(report)
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
end
