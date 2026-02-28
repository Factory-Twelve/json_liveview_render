defmodule JsonLiveviewRender.StreamTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias JsonLiveviewRender.Stream
  alias JsonLiveviewRenderTest.Fixtures.Catalog

  defmodule ValidationGuardCatalog do
    def component(_type), do: raise("spec validation should not run for incomplete stream")
  end

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
    {:ok, stream} = Stream.ingest(Stream.new(), {:root, "page"}, Catalog)
    {:ok, stream} = Stream.ingest(stream, {:finalize}, Catalog)
    assert stream.complete?
  end

  test "finalize without root is rejected" do
    assert {:error, :root_not_set} = Stream.ingest(Stream.new(), {:finalize}, Catalog)
  end

  test "ingest rejects elements before root" do
    assert {:error, :root_not_set} =
             Stream.ingest(
               Stream.new(),
               {:element, "metric_1",
                %{"type" => "metric", "props" => %{"label" => "A", "value" => "1"}}},
               Catalog
             )
  end

  test "invalid event tuple returns deterministic error" do
    assert {:error, {:invalid_stream_event, {:bogus, :event}}} =
             Stream.ingest(Stream.new(), {:bogus, :event}, Catalog)
  end

  test "duplicate element events return explicit error without mutation" do
    {:ok, stream} =
      Stream.ingest(
        Stream.new(),
        {:element, "metric_1",
         %{"type" => "metric", "props" => %{"label" => "A", "value" => "1"}}},
        Catalog
      )

    assert {:ok, stream} = Stream.ingest(stream, {:root, "metric_1"}, Catalog)

    assert {:error, {:element_already_exists, "metric_1"}} =
             Stream.ingest(
               stream,
               {:element, "metric_1",
                %{"type" => "metric", "props" => %{"label" => "A", "value" => "1"}}},
               Catalog
             )

    assert Map.keys(stream.elements) == ["metric_1"]
  end

  test "ingest_many/3 processes event batches" do
    events = [
      {:root, "page"},
      {:element, "page", %{"type" => "row", "props" => %{}, "children" => ["metric_1"]}},
      {:element, "metric_1", %{"type" => "metric", "props" => %{"label" => "A", "value" => "1"}}}
    ]

    assert {:ok, stream} = Stream.ingest_many(Stream.new(), events, Catalog)
    assert stream.root == "page"
    assert Map.has_key?(stream.elements, "metric_1")
  end

  test "ingest/3 rejects root reassignment and accepts idempotent same root" do
    {:ok, stream} = Stream.ingest(Stream.new(), {:root, "page"}, Catalog)
    assert {:ok, ^stream} = Stream.ingest(stream, {:root, "page"}, Catalog)

    assert {:error, {:root_already_set, "page", "other"}} =
             Stream.ingest(stream, {:root, "other"}, Catalog)
  end

  test "ingest_many/3 stops on first error and returns prior stream state" do
    events = [
      {:root, "page"},
      {:element, "metric_1", %{"type" => "metric", "props" => %{}}}
    ]

    assert {:error, {:missing_required_prop, _}, stream} =
             Stream.ingest_many(Stream.new(), events, Catalog)

    assert stream.root == "page"
    refute Map.has_key?(stream.elements, "metric_1")
  end

  test "finalize/3 validates the completed stream spec" do
    {:ok, stream} =
      Stream.ingest_many(
        Stream.new(),
        [
          {:root, "page"},
          {:element, "page", %{"type" => "row", "props" => %{}, "children" => ["metric_1"]}},
          {:element, "metric_1",
           %{"type" => "metric", "props" => %{"label" => "A", "value" => "1"}}},
          {:finalize}
        ],
        Catalog
      )

    assert {:ok, %{"root" => "page"}} = Stream.finalize(stream, Catalog)
  end

  test "finalize/3 with require_complete: false validates partial stream" do
    {:ok, stream} =
      Stream.ingest_many(
        Stream.new(),
        [
          {:root, "page"},
          {:element, "page", %{"type" => "row", "props" => %{}, "children" => ["metric_1"]}},
          {:element, "metric_1",
           %{"type" => "metric", "props" => %{"label" => "A", "value" => "1"}}}
        ],
        Catalog
      )

    assert {:ok, %{"root" => "page", "elements" => elements}} =
             Stream.finalize(stream, Catalog, require_complete: false)

    assert Map.has_key?(elements, "metric_1")
  end

  test "finalize/3 requires finalize event by default" do
    {:ok, stream} = Stream.ingest(Stream.new(), {:root, "page"}, Catalog)
    assert {:error, :stream_not_finalized} = Stream.finalize(stream, Catalog)
  end

  test "finalize/3 short-circuits before validation when stream incomplete" do
    {:ok, stream} =
      Stream.ingest_many(
        Stream.new(),
        [
          {:root, "page"},
          {:element, "page", %{"type" => "row", "props" => %{}, "children" => ["metric_1"]}},
          {:element, "metric_1",
           %{"type" => "metric", "props" => %{"label" => "A", "value" => "1"}}}
        ],
        Catalog
      )

    assert {:error, :stream_not_finalized} = Stream.finalize(stream, ValidationGuardCatalog)
  end

  test "ingest/3 does not allow mutation after finalize" do
    {:ok, stream} = Stream.ingest_many(Stream.new(), [{:root, "page"}, {:finalize}], Catalog)

    assert {:ok, ^stream} = Stream.ingest(stream, {:finalize}, Catalog)

    assert {:error, :stream_already_finalized} =
             Stream.ingest(stream, {:root, "other"}, Catalog)
  end

  test "ingest/4 supports permissive strict option for unknown props" do
    strict_event =
      {:element, "metric_1",
       %{"type" => "metric", "props" => %{"label" => "A", "value" => "1", "x" => true}}}

    assert {:error, {:unknown_prop, _}} = Stream.ingest(Stream.new(), strict_event, Catalog)

    assert capture_log(fn ->
             assert {:ok, stream} =
                      Stream.ingest(Stream.new(), strict_event, Catalog, strict: false)

             assert Map.has_key?(stream.elements, "metric_1")
           end) =~ "ignoring unknown prop"
  end
end
