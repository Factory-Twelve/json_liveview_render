defmodule JsonLiveviewRender.Benchmark.MatrixTest do
  use ExUnit.Case, async: false

  alias JsonLiveviewRender.Benchmark.Config
  alias JsonLiveviewRender.Benchmark.Matrix

  test "default matrix definitions include validate tiers and render coverage cases" do
    assert Enum.map(Matrix.case_definitions(), & &1.case_name) == [
             "validate_small_depth_4_width_2_nodes_15",
             "validate_typical_depth_5_width_4_nodes_341",
             "validate_pathological_depth_6_width_4_nodes_1024",
             "depth_4_width_2",
             "depth_4_width_4",
             "depth_5_width_2",
             "depth_5_width_4",
             "depth_6_width_4_nodes_1024"
           ]
  end

  test "render-only matrix definitions preserve historical depth and width combinations" do
    render_cases = Matrix.case_definitions([:render])

    assert Enum.map(render_cases, & &1.case_name) == [
             "depth_4_width_2",
             "depth_4_width_4",
             "depth_5_width_2",
             "depth_5_width_4",
             "depth_6_width_4_nodes_1024"
           ]

    assert Enum.map(render_cases, &{&1.depth, &1.branching_factor, &1.node_count}) == [
             {4, 2, 15},
             {4, 4, 85},
             {5, 2, 31},
             {5, 4, 341},
             {6, 4, 1024}
           ]
  end

  test "render seeds stay stable when default matrix includes validate tiers" do
    seed = 111
    render_case_names = MapSet.new(Enum.map(Matrix.case_definitions([:render]), & &1.case_name))

    default_render_seed_pairs =
      Config.from_options(seed: seed)
      |> Matrix.configs_for()
      |> Enum.filter(&MapSet.member?(render_case_names, &1.case_name))
      |> Enum.map(&{&1.case_name, &1.seed})

    render_only_seed_pairs =
      Config.from_options(seed: seed, suites: [:render])
      |> Matrix.configs_for()
      |> Enum.map(&{&1.case_name, &1.seed})

    assert default_render_seed_pairs == render_only_seed_pairs
  end
end
