defmodule JsonLiveviewRender.StreamIntegrationTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Stream
  alias JsonLiveviewRender.Stream.Adapter.OpenAI
  alias JsonLiveviewRender.Test
  alias JsonLiveviewRenderTest.Fixtures.Catalog
  alias JsonLiveviewRenderTest.Fixtures.Registry

  @fixtures_dir Path.expand("../fixtures/wire/incremental", __DIR__)

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

  test "incremental update fixtures grow the UI step by step and finalize deterministically" do
    {stream, rendered_steps} =
      Enum.reduce(page_growth_updates(), {Stream.new(), []}, fn update, {stream, html_steps} ->
        assert {:ok, stream} = Stream.ingest(stream, {:update, update}, Catalog)

        html =
          Test.render_spec(Stream.to_spec(stream), Catalog,
            registry: Registry,
            allow_partial: true
          )

        {stream, html_steps ++ [html]}
      end)

    assert length(rendered_steps) == 5

    [step_1, step_2, step_3, step_4, step_5] = rendered_steps

    assert step_1 =~ ~s(class="column")
    refute step_1 =~ "Revenue"

    assert step_2 =~ "Revenue"
    assert step_2 =~ "Pending"
    refute step_2 =~ "$142,300"

    assert step_3 =~ ~s(class="grid")
    refute step_3 =~ "Margin"

    assert step_4 =~ "$142,300"
    assert step_4 =~ "35%"
    refute step_4 =~ "Top performers"

    assert step_5 =~ "Top performers"
    assert step_5 =~ "Alice"
    assert step_5 =~ "Bob"

    assert {:ok, finalized} = Stream.finalize(stream, Catalog)

    assert finalized["elements"]["page"]["children"] == [
             "summary_header",
             "summary_grid",
             "team_cards"
           ]

    assert {:ok, replayed_stream} =
             Stream.ingest_many(
               Stream.new(),
               Enum.map(page_growth_updates(), &{:update, &1}),
               Catalog
             )

    assert Stream.to_spec(replayed_stream) == Stream.to_spec(stream)
  end

  defp page_growth_updates do
    @fixtures_dir
    |> Path.join("page_growth_steps.json")
    |> File.read!()
    |> Jason.decode!()
  end
end
