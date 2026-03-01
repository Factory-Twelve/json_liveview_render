defmodule JsonLiveviewRender.Benchmark.Suite.Render do
  @moduledoc false

  require Phoenix.LiveViewTest

  alias JsonLiveviewRender.Benchmark.{Config, Metrics}

  @spec run(Config.t(), map()) :: map()
  def run(%Config{} = config, context) do
    assigns = Keyword.put(context.render_assigns, :spec, context.spec)

    render_fn = fn ->
      Phoenix.LiveViewTest.render_component(
        &JsonLiveviewRender.Renderer.render/1,
        assigns
      )
    end

    %{
      name: "render",
      metrics: Metrics.measure(config.iterations, render_fn)
    }
  end
end
