defmodule JsonLiveviewRender.Benchmark.Suite.Validate do
  @moduledoc false

  alias JsonLiveviewRender.Benchmark.{Config, Metrics}

  @spec run(Config.t(), map()) :: map()
  def run(%Config{} = config, context) do
    case JsonLiveviewRender.Spec.validate(context.spec, JsonLiveviewRender.Benchmark.Catalog) do
      {:ok, _} ->
        :ok

      {:error, reasons} ->
        raise "benchmark validate suite failed: spec validation returned errors: #{inspect(reasons)}"
    end

    metrics =
      Metrics.measure(
        config.iterations,
        fn ->
          JsonLiveviewRender.Spec.validate(context.spec, JsonLiveviewRender.Benchmark.Catalog)
        end,
        memory: true
      )

    %{
      metrics: metrics,
      status: :ok,
      name: "validate"
    }
  end
end
