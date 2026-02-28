defmodule JsonLiveviewRender.Stream.Adapter.AnthropicTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Stream.Adapter.Anthropic

  test "normalizes direct tool_use payload" do
    payload = %{
      "type" => "tool_use",
      "name" => "json_liveview_render_event",
      "input" => %{"event" => "finalize"}
    }

    assert {:ok, {:finalize}} = Anthropic.normalize_event(payload)
  end

  test "normalizes content_block tool_use payload" do
    payload = %{
      "type" => "content_block_stop",
      "content_block" => %{
        "type" => "tool_use",
        "name" => "json_liveview_render_event",
        "input" => %{"event" => "root", "id" => "page"}
      }
    }

    assert {:ok, {:root, "page"}} = Anthropic.normalize_event(payload)
  end

  test "ignores unrelated payloads" do
    assert :ignore = Anthropic.normalize_event(%{"type" => "message_delta"})
  end

  test "normalizes atom-keyed payloads" do
    payload = %{
      type: "content_block_stop",
      content_block: %{
        type: "tool_use",
        name: "json_liveview_render_event",
        input: %{"event" => "root", "id" => "page"}
      }
    }

    assert {:ok, {:root, "page"}} = Anthropic.normalize_event(payload)
  end

  test "returns explicit error for tool_use schema mismatch" do
    payload = %{
      "type" => "tool_use",
      "name" => "json_liveview_render_event"
    }

    assert {:error, {:invalid_adapter_event, payload}} = Anthropic.normalize_event(payload)
  end

  test "returns explicit error for content_block tool_use schema mismatch" do
    payload = %{
      "type" => "content_block_stop",
      "content_block" => %{
        "type" => "tool_use",
        "name" => "json_liveview_render_event"
      }
    }

    assert {:error, {:invalid_adapter_event, payload}} = Anthropic.normalize_event(payload)
  end
end
