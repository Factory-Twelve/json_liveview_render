defmodule JsonLiveviewRender.RendererAliasTest do
  use ExUnit.Case, async: true

  test "renderer aliases and uses DevTools module in template" do
    source = File.read!(Path.expand("../../lib/json_liveview_render/renderer.ex", __DIR__))

    assert String.contains?(source, "alias JsonLiveviewRender.DevTools")
    assert String.contains?(source, "DevTools.render")
  end

  test "renderer guards partial validation when allow_partial is enabled" do
    source = File.read!(Path.expand("../../lib/json_liveview_render/renderer.ex", __DIR__))

    assert Regex.match?(
             ~r/assigns\.allow_partial\s+and\s+function_exported\?\(Spec,\s*:validate_partial,\s*3\)/,
             source
           )
  end

end
