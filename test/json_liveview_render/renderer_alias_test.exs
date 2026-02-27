defmodule JsonLiveviewRender.RendererAliasTest do
  use ExUnit.Case, async: true

  test "renderer renders the full DevTools module path in template" do
    source = File.read!(Path.expand("../../lib/json_liveview_render/renderer.ex", __DIR__))

    assert String.contains?(source, "JsonLiveviewRender.DevTools.render")
  end

  test "renderer dispatches to validate_partial when allow_partial is true" do
    source = File.read!(Path.expand("../../lib/json_liveview_render/renderer.ex", __DIR__))

    assert String.contains?(source, "defp spec_validator(true), do: &Spec.validate_partial/3")
  end
end
