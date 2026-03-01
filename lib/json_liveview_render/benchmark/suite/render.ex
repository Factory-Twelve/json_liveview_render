defmodule JsonLiveviewRender.Benchmark.Suite.Render do
  @moduledoc false

  alias JsonLiveviewRender.Benchmark.{Config, Metrics}

  @spec run(Config.t(), map()) :: map()
  def run(%Config{} = config, context) do
    render_fn = fn ->
      require Phoenix.LiveViewTest

      Phoenix.LiveViewTest.render_component(
        &JsonLiveviewRender.Renderer.render/1,
        Keyword.put(context.render_assigns, :spec, context.spec)
      )
    end

    %{metrics: Metrics.measure(config.iterations, render_fn)}
    |> Map.merge(%{name: "render", status: :ok})
  end
end
