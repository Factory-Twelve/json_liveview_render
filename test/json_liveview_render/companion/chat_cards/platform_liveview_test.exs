defmodule JsonLiveviewRender.Companion.ChatCards.PlatformLiveViewTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRenderTest.Companion.ChatCards.FixtureHelper

  test "matches golden payload" do
    assert {:ok, result} = FixtureHelper.compile(targets: [:liveview])

    assert result.outputs.liveview == FixtureHelper.expected_fixture("liveview/qc_alert.json")
  end
end
