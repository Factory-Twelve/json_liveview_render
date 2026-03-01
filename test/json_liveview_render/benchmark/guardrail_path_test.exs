defmodule JsonLiveviewRender.Benchmark.GuardrailPathTest do
  use ExUnit.Case, async: false

  alias JsonLiveviewRender.Benchmark.Guardrail

  test "default thresholds path resolves relative to project regardless of cwd" do
    expected_path = Path.expand("../../../benchmarks/thresholds.json", __DIR__)

    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "json_liveview_render_guardrail_cwd_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    {resolved_path, thresholds} =
      File.cd!(tmp_dir, fn ->
        {Guardrail.default_thresholds_path(), Guardrail.load_thresholds()}
      end)

    assert Guardrail.default_thresholds_path() == expected_path
    assert resolved_path == expected_path
    assert thresholds.path == expected_path
    assert thresholds.version > 0
    assert map_size(thresholds.suites) > 0
  end
end
