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

  test "render seeds preserve historical base-seed offsets" do
    seed = 111

    render_seed_pairs =
      Config.from_options(seed: seed, suites: [:render])
      |> Matrix.configs_for()
      |> Enum.map(&{&1.case_name, &1.seed})

    assert render_seed_pairs == [
             {"depth_4_width_2", 111},
             {"depth_4_width_4", 112},
             {"depth_5_width_2", 113},
             {"depth_5_width_4", 114},
             {"depth_6_width_4_nodes_1024", 115}
           ]
  end

  test "matrix configs pin each case to its originating suite" do
    case_suite_pairs =
      Config.from_options(seed: 111, suites: [:validate, :render])
      |> Matrix.configs_for()
      |> Enum.map(&{&1.case_name, &1.suites})

    assert case_suite_pairs == [
             {"validate_small_depth_4_width_2_nodes_15", [:validate]},
             {"validate_typical_depth_5_width_4_nodes_341", [:validate]},
             {"validate_pathological_depth_6_width_4_nodes_1024", [:validate]},
             {"depth_4_width_2", [:render]},
             {"depth_4_width_4", [:render]},
             {"depth_5_width_2", [:render]},
             {"depth_5_width_4", [:render]},
             {"depth_6_width_4_nodes_1024", [:render]}
           ]
  end

  test "matrix case seeds stay stable across suite selections and order" do
    seed = 222

    combined =
      Config.from_options(seed: seed, suites: [:validate, :render])
      |> Matrix.configs_for()
      |> Map.new(&{&1.case_name, &1.seed})

    reversed =
      Config.from_options(seed: seed, suites: [:render, :validate])
      |> Matrix.configs_for()
      |> Map.new(&{&1.case_name, &1.seed})

    validate_only =
      Config.from_options(seed: seed, suites: [:validate])
      |> Matrix.configs_for()
      |> Map.new(&{&1.case_name, &1.seed})

    render_only =
      Config.from_options(seed: seed, suites: [:render])
      |> Matrix.configs_for()
      |> Map.new(&{&1.case_name, &1.seed})

    assert combined["validate_small_depth_4_width_2_nodes_15"] ==
             validate_only["validate_small_depth_4_width_2_nodes_15"]

    assert combined["validate_typical_depth_5_width_4_nodes_341"] ==
             validate_only["validate_typical_depth_5_width_4_nodes_341"]

    assert combined["validate_pathological_depth_6_width_4_nodes_1024"] ==
             validate_only["validate_pathological_depth_6_width_4_nodes_1024"]

    assert combined["depth_4_width_2"] == render_only["depth_4_width_2"]
    assert combined["depth_4_width_4"] == render_only["depth_4_width_4"]
    assert combined["depth_5_width_2"] == render_only["depth_5_width_2"]
    assert combined["depth_5_width_4"] == render_only["depth_5_width_4"]
    assert combined["depth_6_width_4_nodes_1024"] == render_only["depth_6_width_4_nodes_1024"]

    assert combined == reversed
  end
end
