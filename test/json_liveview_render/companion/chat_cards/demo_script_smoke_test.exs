defmodule JsonLiveviewRender.Companion.ChatCards.DemoScriptSmokeTest do
  use ExUnit.Case, async: false

  test "demo script prints all target sections" do
    {output, 0} =
      System.cmd("mix", ["run", "scripts/chat_cards_demo.exs"],
        env: [{"MIX_ENV", "test"}],
        stderr_to_stdout: true
      )

    assert output =~ "LIVEVIEW"
    assert output =~ "WEB_CHAT"
    assert output =~ "SLACK"
    assert output =~ "TEAMS"
    assert output =~ "WHATSAPP"
  end
end
