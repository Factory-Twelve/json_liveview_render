defmodule JsonLiveviewRender.Companion.ChatCards.SenderTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Companion.ChatCards
  alias JsonLiveviewRenderTest.Companion.ChatCards.FixtureHelper

  test "compile_and_send leaves deliveries empty without sender" do
    assert {:ok, result} =
             ChatCards.compile_and_send(
               FixtureHelper.input_spec(),
               catalog: JsonLiveviewRenderTest.Companion.ChatCards.Catalog,
               current_user: %{role: :member},
               targets: [:slack]
             )

    assert result.deliveries == %{}
  end

  test "compile_and_send stores sender results" do
    assert {:ok, result} =
             ChatCards.compile_and_send(
               FixtureHelper.input_spec(),
               catalog: JsonLiveviewRenderTest.Companion.ChatCards.Catalog,
               current_user: %{role: :member},
               sender: JsonLiveviewRenderTest.Companion.ChatCards.SuccessSender,
               targets: [:slack, :teams, :whatsapp]
             )

    assert result.deliveries[:slack] == {:ok, {:delivered, :slack}}
    assert result.deliveries[:teams] == {:ok, {:delivered, :teams}}
    assert result.deliveries[:whatsapp] == {:ok, {:delivered, :whatsapp}}
  end
end
