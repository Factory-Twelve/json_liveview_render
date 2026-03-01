defmodule JsonLiveviewRender.Benchmark.Suites do
  @moduledoc false

  alias JsonLiveviewRender.Benchmark.Config

  @spec available_suites() :: [Config.suite()]
  def available_suites, do: [:validate, :render]

  @spec run(Config.t(), map()) :: [map()]
  def run(%Config{} = config, context) do
    Enum.map(config.suites, fn suite ->
      case suite do
        :validate -> JsonLiveviewRender.Benchmark.Suite.Validate.run(config, context)
        :render -> JsonLiveviewRender.Benchmark.Suite.Render.run(config, context)
      end
    end)
  end
end
