defmodule JsonLiveviewRender.Companion.ChatCards.PlatformWhatsAppTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Companion.ChatCards
  alias JsonLiveviewRenderTest.Companion.ChatCards.FixtureHelper

  test "matches golden payload for buttons mode" do
    assert {:ok, result} = FixtureHelper.compile(targets: [:whatsapp], whatsapp_mode: :buttons)

    assert result.outputs.whatsapp ==
             FixtureHelper.expected_fixture("whatsapp/qc_alert_buttons.json")
  end

  test "matches golden payload for list fallback mode" do
    spec =
      Path.expand("../../../fixtures/chat_cards/input/qc_alert_many_actions.json", __DIR__)
      |> File.read!()
      |> Jason.decode!()

    assert {:ok, result} =
             ChatCards.compile(spec,
               catalog: JsonLiveviewRenderTest.Companion.ChatCards.Catalog,
               current_user: %{role: :member},
               targets: [:whatsapp],
               whatsapp_mode: :auto
             )

    assert result.outputs.whatsapp ==
             FixtureHelper.expected_fixture("whatsapp/qc_alert_list.json")
  end
end
