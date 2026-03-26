defmodule JsonLiveviewRender.StreamTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias JsonLiveviewRender.Stream
  alias JsonLiveviewRenderTest.Fixtures.Catalog

  defmodule ValidationGuardCatalog do
    def component(_type), do: raise("spec validation should not run for incomplete stream")
  end

  defmodule ValidationNeverCatalog do
    def component(_type), do: raise("spec validation should not run for duplicate elements")
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
    {:ok, stream} = Stream.ingest(Stream.new(), {:root, "metric_1"}, Catalog)

    assert {:error, reasons} =
             Stream.ingest(
               stream,
               {:element, "metric_1", %{"type" => "metric", "props" => %{}}},
               Catalog
             )

    assert is_list(reasons)
    assert Enum.any?(reasons, fn {tag, _message} -> tag == :missing_required_prop end)
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
    {:ok, stream} = Stream.ingest(Stream.new(), {:root, "metric_1"}, Catalog)

    {:ok, stream} =
      Stream.ingest(
        stream,
        {:element, "metric_1",
         %{"type" => "metric", "props" => %{"label" => "A", "value" => "1"}}},
        Catalog
      )

    assert {:error, {:element_already_exists, "metric_1"}} =
             Stream.ingest(
               stream,
               {:element, "metric_1",
                %{"type" => "metric", "props" => %{"label" => "A", "value" => "1"}}},
               Catalog
             )

    assert Map.keys(stream.elements) == ["metric_1"]
  end

  test "duplicate element events short-circuit before validation regardless of payload shape" do
    {:ok, stream} = Stream.ingest(Stream.new(), {:root, "metric_1"}, Catalog)

    {:ok, stream} =
      Stream.ingest(
        stream,
        {:element, "metric_1",
         %{"type" => "metric", "props" => %{"label" => "A", "value" => "1"}}},
        Catalog
      )

    assert {:error, {:element_already_exists, "metric_1"}} =
             Stream.ingest(
               stream,
               {:element, "metric_1", %{"type" => "metric", "props" => %{}}},
               ValidationNeverCatalog
             )
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

  test "ingest_many/4 replays ordered update envelopes into the same canonical spec" do
    events = Enum.map(replayable_updates(), &{:update, &1})

    assert {:ok, stream_a} = Stream.ingest_many(Stream.new(), events, Catalog)
    assert {:ok, stream_b} = Stream.ingest_many(Stream.new(), events, Catalog)

    assert Stream.to_spec(stream_a) == Stream.to_spec(stream_b)
    assert stream_a.complete?

    assert {:ok, validated} = Stream.finalize(stream_a, Catalog)
    assert validated["elements"]["page"]["children"] == ["metric_1", "metric_2"]
    assert Map.keys(validated["elements"]) |> Enum.sort() == ["metric_1", "metric_2", "page"]
  end

  test "update envelopes are idempotent when the same sequence is replayed" do
    step_1 = hd(replayable_updates())
    step_2 = Enum.at(replayable_updates(), 1)

    events = [
      {:update, step_1},
      {:update, step_2},
      {:update, step_1},
      {:update, step_2}
    ]

    assert {:ok, stream} = Stream.ingest_many(Stream.new(), events, Catalog)

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

  test "update envelopes reject conflicting duplicate sequences without mutating state" do
    step_1 = hd(replayable_updates())

    conflicting_step =
      put_in(step_1, ["elements", "page", "children"], ["metric_1", "metric_2"])

    assert {:error, {:conflicting_update_sequence, 1}, stream} =
             Stream.ingest_many(
               Stream.new(),
               [{:update, step_1}, {:update, conflicting_step}],
               Catalog
             )

    assert Stream.to_spec(stream) == %{
             "root" => "page",
             "elements" => %{
               "page" => %{"type" => "row", "props" => %{}, "children" => ["metric_1"]}
             }
           }
  end

  test "update envelopes stay idempotent when the finalized step is replayed" do
    updates = replayable_updates()
    finalized_step = List.last(updates)

    assert {:ok, stream} =
             Stream.ingest_many(
               Stream.new(),
               Enum.map(updates ++ [finalized_step], &{:update, &1}),
               Catalog
             )

    assert stream.complete?

    assert Stream.to_spec(stream)["elements"]["page"]["children"] == ["metric_1", "metric_2"]
    assert {:ok, validated} = Stream.finalize(stream, Catalog)
    assert validated["root"] == "page"
  end

  test "update envelopes reject unseen out-of-order sequences" do
    assert {:error, {:out_of_order_update, 3, 2}, stream} =
             Stream.ingest_many(
               Stream.new(),
               [
                 {:update, out_of_order_update(1)},
                 {:update, out_of_order_update(3)},
                 {:update, out_of_order_update(2)}
               ],
               Catalog
             )

    assert Stream.to_spec(stream) == %{
             "root" => "page",
             "elements" => %{
               "metric_2" => %{
                 "type" => "metric",
                 "props" => %{"label" => "B", "value" => "2"},
                 "children" => []
               },
               "page" => %{
                 "type" => "row",
                 "props" => %{},
                 "children" => ["metric_1", "metric_2"]
               }
             }
           }
  end

  test "update envelopes reject non-scalar canonical ids without mutating state" do
    bad_update = %{
      "sequence" => 1,
      "root" => "page",
      "elements" => %{
        "page" => %{"type" => "row", "props" => %{}, "children" => [{:bad, :child}]}
      }
    }

    assert {:error, {:invalid_update_elements, message}, stream} =
             Stream.ingest_many(Stream.new(), [{:update, bad_update}], Catalog)

    assert message =~ "invalid child id"
    assert Stream.to_spec(stream) == %{"root" => nil, "elements" => %{}}
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

    assert {:error, reasons, stream} =
             Stream.ingest_many(Stream.new(), events, Catalog)

    assert is_list(reasons)
    assert Enum.any?(reasons, fn {tag, _message} -> tag == :missing_required_prop end)
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

  test "finalize update refuses invalid specs and keeps the stream open for repair" do
    assert {:error, reasons, stream} =
             Stream.ingest_many(
               Stream.new(),
               [
                 {:update,
                  %{
                    "sequence" => 1,
                    "root" => "page",
                    "elements" => %{
                      "page" => %{
                        "type" => "row",
                        "props" => %{},
                        "children" => ["metric_1"]
                      }
                    }
                  }},
                 {:update, %{"sequence" => 2, "finalize" => true}}
               ],
               Catalog
             )

    assert Enum.any?(reasons, fn {tag, _message} -> tag == :unresolved_child end)
    refute stream.complete?

    assert {:ok, repaired_stream} =
             Stream.ingest_many(
               stream,
               [
                 {:update,
                  %{
                    "sequence" => 2,
                    "elements" => %{
                      "metric_1" => %{
                        "type" => "metric",
                        "props" => %{"label" => "A", "value" => "1"},
                        "children" => []
                      }
                    }
                  }},
                 {:update, %{"sequence" => 3, "finalize" => true}}
               ],
               Catalog
             )

    assert repaired_stream.complete?
    assert {:ok, %{"root" => "page"}} = Stream.finalize(repaired_stream, Catalog)
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
    {:ok, stream} = Stream.ingest(Stream.new(), {:root, "metric_1"}, Catalog)

    strict_event =
      {:element, "metric_1",
       %{"type" => "metric", "props" => %{"label" => "A", "value" => "1", "x" => true}}}

    assert {:error, {:unknown_prop, _}} = Stream.ingest(stream, strict_event, Catalog)

    assert capture_log(fn ->
             assert {:ok, stream} =
                      Stream.ingest(stream, strict_event, Catalog, strict: false)

             assert Map.has_key?(stream.elements, "metric_1")
           end) =~ "ignoring unknown prop"
  end

  test "ingest/3 handles non-stringable prop keys without crashing" do
    {:ok, stream} = Stream.ingest(Stream.new(), {:root, "metric_1"}, Catalog)

    event =
      {:element, "metric_1",
       %{
         "type" => "metric",
         "props" => %{
           %{"nested" => "key"} => "value",
           "label" => "A",
           "value" => "1"
         }
       }}

    assert {:error, {:unknown_prop, _}} = Stream.ingest(stream, event, Catalog)
  end

  test "update replay tracking stays bounded across long streams" do
    updates =
      [
        %{
          "sequence" => 1,
          "root" => "page",
          "elements" => %{
            "page" => %{"type" => "row", "props" => %{}, "children" => []}
          }
        }
      ] ++
        Enum.map(2..300, fn sequence ->
          %{
            "sequence" => sequence,
            "elements" => %{
              "metric_1" => %{
                "type" => "metric",
                "props" => %{"label" => "A", "value" => Integer.to_string(sequence)},
                "children" => []
              }
            }
          }
        end)

    assert {:ok, stream} =
             Stream.ingest_many(Stream.new(), Enum.map(updates, &{:update, &1}), Catalog)

    assert map_size(stream.update_accumulator.applied_updates) <= 256
    assert stream.update_accumulator.last_sequence == 300
    assert Stream.to_spec(stream)["elements"]["metric_1"]["props"]["value"] == "300"
  end

  defp replayable_updates do
    [
      %{
        "sequence" => 1,
        "root" => "page",
        "elements" => %{
          "page" => %{"type" => "row", "props" => %{}, "children" => ["metric_1"]}
        }
      },
      %{
        "sequence" => 2,
        "elements" => %{
          "metric_1" => %{"type" => "metric", "props" => %{"label" => "A", "value" => "1"}}
        }
      },
      %{
        "sequence" => 3,
        "elements" => %{
          "page" => %{
            "type" => "row",
            "props" => %{},
            "children" => ["metric_1", "metric_2"]
          },
          "metric_2" => %{"type" => "metric", "props" => %{"label" => "B", "value" => "2"}}
        },
        "finalize" => true
      }
    ]
  end

  defp out_of_order_update(sequence) do
    updates = %{
      1 => %{
        "sequence" => 1,
        "root" => "page",
        "elements" => %{
          "page" => %{
            "type" => "row",
            "props" => %{},
            "children" => ["metric_1", "metric_2"]
          }
        }
      },
      2 => %{
        "sequence" => 2,
        "elements" => %{
          "metric_1" => %{"type" => "metric", "props" => %{"label" => "A", "value" => "1"}}
        }
      },
      3 => %{
        "sequence" => 3,
        "elements" => %{
          "metric_2" => %{"type" => "metric", "props" => %{"label" => "B", "value" => "2"}}
        }
      }
    }

    Map.fetch!(updates, sequence)
  end
end
