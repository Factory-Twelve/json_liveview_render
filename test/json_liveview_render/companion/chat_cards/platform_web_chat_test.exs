defmodule JsonLiveviewRender.Companion.ChatCards.PlatformWebChatTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRenderTest.Companion.ChatCards.FixtureHelper

  test "matches golden payload" do
    assert {:ok, result} = FixtureHelper.compile(targets: [:web_chat])

    assert result.outputs.web_chat == FixtureHelper.expected_fixture("web_chat/qc_alert.json")
  end
end
