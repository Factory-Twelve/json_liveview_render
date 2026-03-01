defmodule JsonLiveviewRender.Benchmark.MatrixTest do
  use ExUnit.Case, async: false

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
end
