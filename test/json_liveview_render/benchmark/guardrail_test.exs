defmodule JsonLiveviewRender.Benchmark.GuardrailTest do
  use ExUnit.Case, async: true

  @thresholds %{
    path: "/tmp/thresholds.json",
    version: 1,
    suites: %{
      "validate" => %{
        metric: "p95_microseconds",
        max_regression_percent: 10.0,
        cases: %{"validate_case" => 100.0}
      }
    }
  }

  test "evaluate/2 passes when observed value stays within threshold" do
    report = report("validate_case", "validate", 108)
    result = JsonLiveviewRender.Benchmark.Guardrail.evaluate([report], @thresholds)

    assert result.status == :pass
    assert result.checked_count == 1
    assert result.failure_count == 0
    assert result.skipped_count == 0
    assert result.failures == []
  end

  test "evaluate/2 reports failure when observed value exceeds allowed max" do
    report = report("validate_case", "validate", 130)
    result = JsonLiveviewRender.Benchmark.Guardrail.evaluate([report], @thresholds)

    assert result.status == :fail
    assert result.checked_count == 1
    assert result.failure_count == 1

    [failure] = result.failures
    assert failure.suite == "validate"
    assert failure.case_name == "validate_case"
    assert failure.metric == "p95_microseconds"
    assert failure.baseline == 100.0
    assert failure.actual == 130.0
    assert failure.allowed_max == 110.0
    assert failure.regression_percent == 30.0
  end

  test "evaluate/2 reports skipped cases when threshold case is missing" do
    report = report("unknown_case", "validate", 90)
    result = JsonLiveviewRender.Benchmark.Guardrail.evaluate([report], @thresholds)

    assert result.status == :pass
    assert result.checked_count == 0
    assert result.failure_count == 0
    assert result.skipped_count == 1

    assert result.skipped == [
             %{suite: "validate", case_name: "unknown_case", reason: "missing_case_threshold"}
           ]
  end

  test "load_thresholds/1 parses and normalizes threshold json" do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "json_liveview_render_guardrail_#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    path = Path.join(tmp_dir, "thresholds.json")

    File.mkdir_p!(tmp_dir)

    File.write!(path, """
    {
      "version": 1,
      "suites": {
        "render": {
          "metric": "p95_microseconds",
          "max_regression_percent": 25,
          "cases": {
            "depth_4_width_2": 145
          }
        }
      }
    }
    """)

    thresholds = JsonLiveviewRender.Benchmark.Guardrail.load_thresholds(path)

    assert thresholds.path == Path.expand(path)
    assert thresholds.version == 1
    assert thresholds.suites["render"].metric == "p95_microseconds"
    assert thresholds.suites["render"].max_regression_percent == 25.0
    assert thresholds.suites["render"].cases["depth_4_width_2"] == 145.0
  end

  test "load_thresholds/1 raises ArgumentError for valid JSON with non-object root" do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "json_liveview_render_guardrail_#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    path = Path.join(tmp_dir, "thresholds.json")
    File.mkdir_p!(tmp_dir)
    File.write!(path, "[]")

    assert_raise ArgumentError,
                 ~r/invalid benchmark guardrail thresholds at .*thresholds\.json/,
                 fn ->
                   JsonLiveviewRender.Benchmark.Guardrail.load_thresholds(path)
                 end
  end

  test "render_text/1 includes mode-independent summary lines" do
    result =
      JsonLiveviewRender.Benchmark.Guardrail.evaluate(
        [report("validate_case", "validate", 108)],
        @thresholds
      )

    output =
      result
      |> JsonLiveviewRender.Benchmark.Guardrail.render_text()
      |> IO.iodata_to_binary()

    assert output =~ "Guardrail:"
    assert output =~ "status=pass"
    assert output =~ "threshold_version=1"
    assert output =~ "checked=1"
  end

  defp report(case_name, suite_name, p95_microseconds) do
    %{
      config: %{case_name: case_name},
      suites: [
        %{
          name: suite_name,
          metrics: %{p95_microseconds: p95_microseconds}
        }
      ]
    }
  end
end
