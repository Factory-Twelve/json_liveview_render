defmodule JsonLiveviewRender.BenchmarkDataTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Benchmark.{Config, Data}

  test "build_spec is deterministic for the same config" do
    config =
      Config.from_options(seed: 42, sections: 3, columns: 2, metrics_per_column: 4, iterations: 7)

    left = Data.build_spec(config)
    right = Data.build_spec(config)

    assert left == right
    assert left["root"] == "bench_root"
  end

  test "generated spec validates with benchmark catalog" do
    config = Config.from_options(seed: 24, sections: 2, columns: 2, metrics_per_column: 2)
    spec = Data.build_spec(config)

    assert Enum.all?(spec["elements"], fn {_id, element} ->
             Map.has_key?(element, "children") && is_list(element["children"])
           end)

    assert {:ok, _validated} =
             JsonLiveviewRender.Spec.validate(spec, JsonLiveviewRender.Benchmark.Catalog)
  end
end
