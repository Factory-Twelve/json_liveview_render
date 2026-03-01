defmodule JsonLiveviewRender.Benchmark.Suites do
  @moduledoc false

  alias JsonLiveviewRender.Benchmark.Config

  @suite_modules %{
    validate: JsonLiveviewRender.Benchmark.Suite.Validate,
    render: JsonLiveviewRender.Benchmark.Suite.Render
  }

  @spec available_suites() :: [Config.suite()]
  def available_suites, do: Map.keys(@suite_modules)

  @spec run(Config.t(), map()) :: [map()]
  def run(%Config{} = config, context) do
    Enum.map(config.suites, fn suite ->
      module = Map.fetch!(@suite_modules, suite)
      module.run(config, context)
    end)
  end
end
