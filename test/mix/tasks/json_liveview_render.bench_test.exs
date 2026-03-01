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
          "--node-count",
          "25",
          "--depth",
          "5",
          "--branching-factor",
          "3"
        ])
      end)

    payload = Jason.decode!(String.trim(output))

    assert payload["config"]["iterations"] == 3
    assert payload["config"]["suites"] == ["validate", "render"]
    assert payload["config"]["node_count"] == 25
    assert payload["config"]["depth"] == 5
    assert payload["config"]["branching_factor"] == 3
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

    assert payload["guardrail"]["mode"] == "report_only"
    assert payload["guardrail"]["checked_count"] == 0
    assert payload["guardrail"]["skipped_count"] == 2
  end

  test "honors default format for local invocation" do
    output =
      capture_io(fn ->
        Mix.Tasks.JsonLiveviewRender.Bench.run([
          "--iterations",
          "2",
          "--suites",
          "validate",
          "--node-count",
          "15",
          "--depth",
          "4",
          "--branching-factor",
          "2"
        ])
      end)

    assert output =~ "JsonLiveviewRender Bench Harness"
    assert output =~ "suite=validate"
  end

  test "runs matrix mode with deterministic suite-specific cases and large-case coverage" do
    output =
      capture_io(fn ->
        Mix.Tasks.JsonLiveviewRender.Bench.run([
          "--format",
          "json",
          "--iterations",
          "2",
          "--matrix",
          "--seed",
          "111"
        ])
      end)

    payload = Jason.decode!(String.trim(output))

    assert payload["matrix"] == true
    assert is_list(payload["cases"])
    assert Enum.count(payload["cases"]) == 8
    assert Enum.any?(payload["cases"], &(&1["config"]["node_count"] >= 1000))
    assert payload["guardrail"]["mode"] == "report_only"
    assert payload["guardrail"]["checked_count"] == 8

    case_names =
      Enum.map(payload["cases"], & &1["config"]["case_name"])

    assert case_names == [
             "validate_small_depth_4_width_2_nodes_15",
             "validate_typical_depth_5_width_4_nodes_341",
             "validate_pathological_depth_6_width_4_nodes_1024",
             "depth_4_width_2",
             "depth_4_width_4",
             "depth_5_width_2",
             "depth_5_width_4",
             "depth_6_width_4_nodes_1024"
           ]

    suite_names =
      payload["cases"]
      |> Enum.map(fn entry -> Map.fetch!(entry, "config")["suites"] end)

    assert suite_names == [
             ["validate"],
             ["validate"],
             ["validate"],
             ["render"],
             ["render"],
             ["render"],
             ["render"],
             ["render"]
           ]

    for case_entry <- payload["cases"] do
      configured_suites = case_entry["config"]["suites"]
      assert Enum.map(case_entry["suites"], & &1["name"]) == configured_suites

      suite_entry = hd(case_entry["suites"])
      assert suite_entry["metrics"]["p50_microseconds"] != nil
      assert suite_entry["metrics"]["memory_p95_bytes"] != nil
    end
  end

  test "runs render-only matrix mode with render-specific workload coverage" do
    output =
      capture_io(fn ->
        Mix.Tasks.JsonLiveviewRender.Bench.run([
          "--format",
          "json",
          "--iterations",
          "2",
          "--matrix",
          "--seed",
          "111",
          "--suites",
          "render"
        ])
      end)

    payload = Jason.decode!(String.trim(output))

    assert payload["matrix"] == true
    assert is_list(payload["cases"])
    assert Enum.count(payload["cases"]) == 5
    assert payload["guardrail"]["mode"] == "report_only"
    assert payload["guardrail"]["checked_count"] == 5

    case_names =
      Enum.map(payload["cases"], & &1["config"]["case_name"])

    assert case_names == [
             "depth_4_width_2",
             "depth_4_width_4",
             "depth_5_width_2",
             "depth_5_width_4",
             "depth_6_width_4_nodes_1024"
           ]

    suite_names =
      payload["cases"]
      |> Enum.map(fn entry -> Map.fetch!(entry, "config")["suites"] end)

    assert Enum.all?(suite_names, &(&1 == ["render"]))

    for case_entry <- payload["cases"] do
      render_suite = Map.get(case_entry, "suites") |> Enum.find(&(&1["name"] == "render"))

      assert render_suite["metrics"]["p50_microseconds"] != nil
      assert render_suite["metrics"]["memory_p95_bytes"] != nil
    end
  end

  test "accepts legacy shape flags through parser" do
    output =
      capture_io(fn ->
        Mix.Tasks.JsonLiveviewRender.Bench.run([
          "--format",
          "json",
          "--iterations",
          "2",
          "--suites",
          "validate",
          "--sections",
          "3",
          "--columns",
          "2",
          "--metrics-per-column",
          "4"
        ])
      end)

    payload = Jason.decode!(String.trim(output))

    assert payload["config"]["node_count"] == 34
    assert payload["config"]["depth"] == 6
    assert payload["config"]["branching_factor"] == 4
  end

  test "guardrail-fail raises when thresholds are exceeded" do
    thresholds_path = write_thresholds_fixture!(1)
    on_exit(fn -> File.rm_rf!(Path.dirname(thresholds_path)) end)

    assert_raise Mix.Error, ~r/benchmark guardrail failed/, fn ->
      capture_io(fn ->
        Mix.Tasks.JsonLiveviewRender.Bench.run([
          "--format",
          "json",
          "--matrix",
          "--suites",
          "validate",
          "--iterations",
          "1",
          "--seed",
          "111",
          "--guardrail-thresholds",
          thresholds_path,
          "--guardrail-fail"
        ])
      end)
    end
  end

  test "guardrail-fail cannot be combined with no guardrail" do
    assert_raise Mix.Error, ~r/--guardrail-fail cannot be used with --no-guardrail/, fn ->
      Mix.Tasks.JsonLiveviewRender.Bench.run(["--no-guardrail", "--guardrail-fail"])
    end
  end

  defp write_thresholds_fixture!(max_regression_percent) do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "json_liveview_render_bench_thresholds_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp_dir)
    thresholds_path = Path.join(tmp_dir, "thresholds.json")

    File.write!(
      thresholds_path,
      Jason.encode!(%{
        version: 1,
        suites: %{
          validate: %{
            metric: "p95_microseconds",
            max_regression_percent: max_regression_percent,
            cases: %{
              validate_small_depth_4_width_2_nodes_15: 1,
              validate_typical_depth_5_width_4_nodes_341: 1,
              validate_pathological_depth_6_width_4_nodes_1024: 1
            }
          }
        }
      })
    )

    thresholds_path
  end
end
