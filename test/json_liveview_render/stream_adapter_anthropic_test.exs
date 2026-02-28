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

  test "ignores unrelated payloads with non-stringable keys" do
    assert :ignore = Anthropic.normalize_event(%{"type" => "message_delta", %{} => 1})
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

    assert {:error, {:invalid_adapter_event, _payload}} = Anthropic.normalize_event(payload)
  end

  test "returns explicit error for content_block tool_use schema mismatch" do
    payload = %{
      "type" => "content_block_stop",
      "content_block" => %{
        "type" => "tool_use",
        "name" => "json_liveview_render_event"
      }
    }

    assert {:error, {:invalid_adapter_event, _payload}} = Anthropic.normalize_event(payload)
  end

  test "returns explicit error when tool_use input contains non-stringable keys" do
    payload = %{
      "type" => "tool_use",
      "name" => "json_liveview_render_event",
      "input" => %{"event" => "root", "id" => "page", %{} => "not stringable"}
    }

    assert {:error, {:invalid_adapter_event, _payload}} = Anthropic.normalize_event(payload)
  end

  test "returns explicit error when tool_use input contains keys that cannot be stringified" do
    invalid_key = [0xD800]

    payload = %{
      "type" => "tool_use",
      "name" => "json_liveview_render_event",
      "input" => %{"event" => "root", "id" => "page", invalid_key => "not stringable"}
    }

    assert {:error, {:invalid_adapter_event, _payload}} = Anthropic.normalize_event(payload)
  end
end
