defmodule JsonLiveviewRender.Companion.ChatCards.PlatformTeamsTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRenderTest.Companion.ChatCards.FixtureHelper

  test "matches golden payload" do
    assert {:ok, result} = FixtureHelper.compile(targets: [:teams])

    assert result.outputs.teams == FixtureHelper.expected_fixture("teams/qc_alert.json")
  end
end
