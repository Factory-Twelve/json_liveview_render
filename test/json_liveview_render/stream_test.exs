defmodule JsonLiveviewRender.StreamTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Stream
  alias JsonLiveviewRenderTest.Fixtures.Catalog

  test "new/0 initializes empty stream state" do
    assert Stream.new() == %{root: nil, elements: %{}, complete?: false}
  end

  test "ingest root and element events progressively builds a spec" do
    stream = Stream.new()

    {:ok, stream} = Stream.ingest(stream, {:root, "page"}, Catalog)

    {:ok, stream} =
      Stream.ingest(
        stream,
        {:element, "page", %{"type" => "row", "props" => %{}, "children" => ["metric_1"]}},
        Catalog
      )

    {:ok, stream} =
      Stream.ingest(
        stream,
        {:element, "metric_1",
         %{"type" => "metric", "props" => %{"label" => "A", "value" => "1"}}},
        Catalog
      )

    assert Stream.to_spec(stream) == %{
             "root" => "page",
             "elements" => %{
               "page" => %{"type" => "row", "props" => %{}, "children" => ["metric_1"]},
               "metric_1" => %{
                 "type" => "metric",
                 "props" => %{"label" => "A", "value" => "1"},
                 "children" => []
               }
             }
           }
  end

  test "ingest rejects invalid element events" do
    stream = Stream.new()

    assert {:error, {:missing_required_prop, _}} =
             Stream.ingest(
               stream,
               {:element, "metric_1", %{"type" => "metric", "props" => %{}}},
               Catalog
             )
  end

  test "finalize marks stream complete" do
    {:ok, stream} = Stream.ingest(Stream.new(), {:finalize}, Catalog)
    assert stream.complete?
  end

  test "invalid event tuple returns deterministic error" do
    assert {:error, {:invalid_stream_event, {:bogus, :event}}} =
             Stream.ingest(Stream.new(), {:bogus, :event}, Catalog)
  end
end
