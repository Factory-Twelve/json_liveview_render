defmodule JsonLiveviewRender.Benchmark.Suite.Validate do
  @moduledoc false

  alias JsonLiveviewRender.Benchmark.{Config, Metrics}

  @spec run(Config.t(), map()) :: map()
  def run(%Config{} = config, context) do
    %{
      metrics:
        Metrics.measure(config.iterations, fn ->
          JsonLiveviewRender.Spec.validate(context.spec, JsonLiveviewRender.Benchmark.Catalog)
        end)
    }
    |> Map.merge(%{name: "validate", kind: "validate", status: :ok})
  end
end
