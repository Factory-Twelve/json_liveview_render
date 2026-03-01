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
      metrics: Metrics.measure(config.iterations, render_fn),
      name: "render",
      status: :ok
    }
  end
end
