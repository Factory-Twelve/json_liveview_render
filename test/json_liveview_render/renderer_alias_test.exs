defmodule JsonLiveviewRender.RendererAliasTest do
  use ExUnit.Case, async: true

  test "renderer renders the full DevTools module path in template" do
    source = File.read!(Path.expand("../../lib/json_liveview_render/renderer.ex", __DIR__))

    assert String.contains?(source, "JsonLiveviewRender.DevTools.render")
  end

  test "renderer guards partial validation to avoid allow_partial without validate_partial" do
    source = File.read!(Path.expand("../../lib/json_liveview_render/renderer.ex", __DIR__))

    assert String.contains?(source, "defp spec_validator(true) do")
    assert String.contains?(source, "function_exported?(Spec, :validate_partial, 3)")
    assert String.contains?(source, "raise ArgumentError")
  end
end
