defmodule JsonLiveviewRender.StreamIntegrationTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Stream
  alias JsonLiveviewRender.Stream.Adapter.OpenAI
  alias JsonLiveviewRenderTest.Fixtures.Catalog

  test "adapter-normalized events ingest into stream and finalize to valid spec" do
    provider_payloads = [
      %{
        "type" => "response.function_call_arguments.done",
        "name" => "json_liveview_render_event",
        "arguments" => %{"event" => "root", "id" => "page"}
      },
      %{
        "type" => "response.function_call_arguments.done",
        "name" => "json_liveview_render_event",
        "arguments" => %{
          "event" => "element",
          "id" => "page",
          "element" => %{"type" => "row", "props" => %{}, "children" => ["metric_1"]}
        }
      },
      %{
        "type" => "response.function_call_arguments.done",
        "name" => "json_liveview_render_event",
        "arguments" => %{
          "event" => "element",
          "id" => "metric_1",
          "element" => %{"type" => "metric", "props" => %{"label" => "A", "value" => "1"}}
        }
      },
      %{
        "type" => "response.function_call_arguments.done",
        "name" => "json_liveview_render_event",
        "arguments" => %{"event" => "finalize"}
      }
    ]

    events =
      Enum.map(provider_payloads, fn payload ->
        assert {:ok, event} = OpenAI.normalize_event(payload)
        event
      end)

    assert {:ok, stream} = Stream.ingest_many(Stream.new(), events, Catalog)
    assert {:ok, %{"root" => "page"}} = Stream.finalize(stream, Catalog)
  end

  test "malformed provider payload returns error while unrelated payloads remain ignored" do
    assert {:error, {:invalid_adapter_event, _}} =
             OpenAI.normalize_event(%{
               "type" => "response.function_call_arguments.done",
               "name" => "json_liveview_render_event"
             })

    assert :ignore = OpenAI.normalize_event(%{"type" => "response.output_text.delta"})

    assert Stream.to_spec(Stream.new()) == %{"root" => nil, "elements" => %{}}
  end
end
