defmodule JsonLiveviewRender.Stream.Adapter.OpenAITest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Stream.Adapter.OpenAI

  test "normalizes output_item function call payload" do
    payload = %{
      "type" => "response.output_item.done",
      "item" => %{
        "type" => "function_call",
        "name" => "json_liveview_render_event",
        "arguments" => ~s({"event":"root","id":"page"})
      }
    }

    assert {:ok, {:root, "page"}} = OpenAI.normalize_event(payload)
  end

  test "normalizes function_call_arguments payload" do
    payload = %{
      "type" => "response.function_call_arguments.done",
      "name" => "json_liveview_render_event",
      "arguments" => %{
        "event" => "element",
        "id" => "metric_1",
        "element" => %{"type" => "metric", "props" => %{"label" => "A", "value" => "1"}}
      }
    }

    assert {:ok, {:element, "metric_1", %{"type" => "metric", "props" => _}}} =
             OpenAI.normalize_event(payload)
  end

  test "ignores unrelated payloads" do
    assert :ignore = OpenAI.normalize_event(%{"type" => "response.output_text.delta"})
  end

  test "normalizes output_item payload with atom keys" do
    payload = %{
      type: "response.output_item.done",
      item: %{
        type: "function_call",
        name: "json_liveview_render_event",
        arguments: %{"event" => "element", "id" => "metric_1", "element" => %{}}
      }
    }

    assert {:ok, {:element, "metric_1", _}} = OpenAI.normalize_event(payload)
  end

  test "returns explicit error for mismatched output_item schema" do
    payload = %{
      "type" => "response.output_item.done",
      "item" => %{"type" => "function_call", "name" => "json_liveview_render_event"}
    }

    assert {:error, {:invalid_adapter_event, payload}} = OpenAI.normalize_event(payload)
  end

  test "returns explicit error for malformed function_call_arguments payload" do
    payload = %{
      "type" => "response.function_call_arguments.done",
      "name" => "json_liveview_render_event"
    }

    assert {:error, {:invalid_adapter_event, payload}} = OpenAI.normalize_event(payload)
  end

  test "returns explicit error when arguments decode to non-map json" do
    payload = %{
      "type" => "response.function_call_arguments.done",
      "name" => "json_liveview_render_event",
      "arguments" => ~s(["event","root"])
    }

    assert {:error, {:invalid_adapter_event, :arguments_must_decode_to_map}} =
             OpenAI.normalize_event(payload)
  end

  test "normalizes event arguments from stringified JSON with atom keys" do
    payload = %{
      "type" => "response.function_call_arguments.done",
      "name" => "json_liveview_render_event",
      "arguments" => %{"event" => "root", "id" => "page"}
    }

    assert {:ok, {:root, "page"}} = OpenAI.normalize_event(payload)
  end
end
