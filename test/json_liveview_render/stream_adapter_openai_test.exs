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
end
