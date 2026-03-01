defmodule Mix.Tasks.JsonLiveviewRender.BenchTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  setup do
    Mix.Task.reenable("json_liveview_render.bench")
    :ok
  end

  test "runs configured suites and prints a report" do
    output =
      capture_io(fn ->
        Mix.Tasks.JsonLiveviewRender.Bench.run([
          "--format",
          "json",
          "--iterations",
          "3",
          "--suites",
          "validate,render",
          "--sections",
          "2",
          "--columns",
          "2",
          "--metrics-per-column",
          "2"
        ])
      end)

    payload = Jason.decode!(String.trim(output))

    assert payload["config"]["iterations"] == 3
    assert payload["config"]["suites"] == ["validate", "render"]
    assert payload["config"]["sections"] == 2
    assert payload["metadata"]["project"]["app"] == "json_liveview_render"
    assert is_integer(payload["metadata"]["machine"]["process_count"])
    assert payload["metadata"]["machine"]["process_count"] > 0
    assert payload["metadata"]["machine"]["process_count"] <= :erlang.system_info(:process_limit)
    refute payload["metadata"]["machine"]["process_count"] == :erlang.system_info(:process_limit)
    assert Enum.map(payload["suites"], & &1["name"]) == ["validate", "render"]

    assert payload["suites"]
           |> Enum.all?(fn entry ->
             entry["metrics"]["iterations"] == 3 and
               is_number(entry["metrics"]["mean_microseconds"])
           end)
  end

  test "honors default format for local invocation" do
    output =
      capture_io(fn ->
        Mix.Tasks.JsonLiveviewRender.Bench.run([
          "--iterations",
          "2",
          "--suites",
          "validate",
          "--sections",
          "1",
          "--columns",
          "1",
          "--metrics-per-column",
          "1"
        ])
      end)

    assert output =~ "JsonLiveviewRender Bench Harness"
    assert output =~ "suite=validate"
  end
end
