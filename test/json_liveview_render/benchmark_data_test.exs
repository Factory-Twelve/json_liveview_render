defmodule JsonLiveviewRender.BenchmarkDataTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Benchmark.{Config, Data}

  test "build_spec is deterministic for the same config" do
    config =
      Config.from_options(
        seed: 42,
        node_count: 75,
        depth: 5,
        branching_factor: 3,
        iterations: 7
      )

    left = Data.build_spec(config)
    right = Data.build_spec(config)

    assert left == right
    assert left["root"] == "bench_root"
    assert map_size(left["elements"]) == config.node_count
  end

  test "generated spec validates with benchmark catalog" do
    config = Config.from_options(seed: 24, node_count: 25, depth: 4, branching_factor: 3)
    spec = Data.build_spec(config)

    assert Enum.all?(spec["elements"], fn {_id, element} ->
             Map.has_key?(element, "children") && is_list(element["children"])
           end)

    assert {:ok, _validated} =
             JsonLiveviewRender.Spec.validate(spec, JsonLiveviewRender.Benchmark.Catalog)
  end

  test "generated spec respects configured depth and shape" do
    config = Config.from_options(seed: 11, node_count: 25, depth: 5, branching_factor: 3)
    spec = Data.build_spec(config)

    assert max_depth(spec, spec["root"]) <= config.depth
  end

  defp max_depth(spec, root_id), do: max_depth(spec["elements"], root_id, 1, MapSet.new())

  defp max_depth(elements, node_id, current_depth, visited) do
    element = Map.fetch!(elements, node_id)
    child_ids = element["children"]

    if child_ids == [] or MapSet.member?(visited, node_id) do
      current_depth
    else
      child_depths =
        Enum.map(
          child_ids,
          &max_depth(elements, &1, current_depth + 1, MapSet.put(visited, node_id))
        )

      Enum.max([current_depth | child_depths])
    end
  end
end
