defmodule JsonLiveviewRender.Companion.ChatCards.PlatformSlackTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRenderTest.Companion.ChatCards.FixtureHelper

  test "matches golden payload for message surface" do
    assert {:ok, result} = FixtureHelper.compile(targets: [:slack], slack_surface: :message)

    assert result.outputs.slack == FixtureHelper.expected_fixture("slack/qc_alert_message.json")
  end

  test "matches golden payload for home surface" do
    assert {:ok, result} = FixtureHelper.compile(targets: [:slack], slack_surface: :home)

    assert result.outputs.slack == FixtureHelper.expected_fixture("slack/qc_alert_home.json")
  end

  test "matches golden payload for modal surface" do
    assert {:ok, result} = FixtureHelper.compile(targets: [:slack], slack_surface: :modal)

    assert result.outputs.slack == FixtureHelper.expected_fixture("slack/qc_alert_modal.json")
  end
end
