defmodule JsonLiveviewRender.RendererAliasTest do
  use ExUnit.Case, async: true

  test "renderer source does not keep an unused DevTools alias" do
    source = File.read!(Path.expand("../../lib/json_liveview_render/renderer.ex", __DIR__))

    refute String.contains?(source, "alias JsonLiveviewRender.DevTools")
  end
end
