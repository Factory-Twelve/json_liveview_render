defmodule JsonLiveviewRender.Companion.ChatCards.RouterTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Companion.ChatCards
  alias JsonLiveviewRenderTest.Companion.ChatCards.FixtureHelper

  test "compile builds all default targets and action envelopes" do
    assert {:ok, result} =
             FixtureHelper.compile(
               authorizer: JsonLiveviewRenderTest.Companion.ChatCards.Authorizer
             )

    assert result.outputs |> Map.keys() |> Enum.sort() ==
             [:liveview, :slack, :teams, :web_chat, :whatsapp] |> Enum.sort()

    assert length(result.actions) == 15
    assert Enum.all?(result.actions, &(&1.version == "v1"))
    assert result.deliveries == %{}
  end

  test "compile_and_send records mixed delivery outcomes and warning" do
    assert {:ok, result} =
             ChatCards.compile_and_send(
               FixtureHelper.input_spec(),
               catalog: JsonLiveviewRenderTest.Companion.ChatCards.Catalog,
               current_user: %{role: :member},
               authorizer: JsonLiveviewRenderTest.Companion.ChatCards.Authorizer,
               sender: JsonLiveviewRenderTest.Companion.ChatCards.MixedSender
             )

    assert result.deliveries[:slack] == {:ok, :sent}
    assert result.deliveries[:teams] == {:error, :timeout}
    assert result.deliveries[:whatsapp] == {:ok, :sent}

    assert Enum.any?(result.warnings, fn warning -> warning.code == :delivery_failed end)
  end

  test "compile_and_send validates sender contract before compile" do
    assert {:error, :invalid_sender} =
             ChatCards.compile_and_send(
               FixtureHelper.input_spec(),
               catalog: JsonLiveviewRenderTest.Companion.ChatCards.Catalog,
               current_user: %{role: :member},
               sender: :not_a_sender
             )
  end

  test "permission filtering happens before bridge fallback" do
    spec =
      FixtureHelper.input_spec()
      |> put_in(
        ["elements", "alert_card", "children"],
        ["admin_note"] ++ FixtureHelper.input_spec()["elements"]["alert_card"]["children"]
      )
      |> put_in(["elements", "admin_note"], %{
        "type" => "admin_only",
        "props" => %{"message" => "internal escalation"},
        "children" => []
      })

    assert {:ok, member_result} =
             ChatCards.compile(spec,
               catalog: JsonLiveviewRenderTest.Companion.ChatCards.Catalog,
               current_user: %{role: :member},
               authorizer: JsonLiveviewRenderTest.Companion.ChatCards.Authorizer,
               targets: [:web_chat]
             )

    assert {:ok, admin_result} =
             ChatCards.compile(spec,
               catalog: JsonLiveviewRenderTest.Companion.ChatCards.Catalog,
               current_user: %{role: :admin},
               authorizer: JsonLiveviewRenderTest.Companion.ChatCards.Authorizer,
               targets: [:web_chat]
             )

    member_body = member_result.outputs.web_chat["card"]["body"]
    admin_body = admin_result.outputs.web_chat["card"]["body"]

    refute Enum.any?(member_body, &String.contains?(&1, "admin_only"))
    assert Enum.any?(admin_body, &String.contains?(&1, "admin_only"))
  end
end
