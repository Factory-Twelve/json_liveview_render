defmodule JsonLiveviewRender.Benchmark.Matrix do
  @moduledoc false

  alias JsonLiveviewRender.Benchmark.Config

  @matrix_depths [4, 5]
  @matrix_widths [2, 4]
  @large_node_case_depth 6
  @large_node_case_width 4
  @large_node_case_count 1024

  @spec case_definitions() :: [
          %{
            required(:depth) => pos_integer(),
            required(:branching_factor) => pos_integer(),
            required(:node_count) => pos_integer(),
            required(:case_name) => String.t()
          }
        ]
  def case_definitions do
    base_cases =
      for depth <- @matrix_depths, width <- @matrix_widths do
        %{
          depth: depth,
          branching_factor: width,
          node_count: max_nodes_possible(depth, width),
          case_name: "depth_#{depth}_width_#{width}"
        }
      end

    large_case = %{
      depth: @large_node_case_depth,
      branching_factor: @large_node_case_width,
      node_count: @large_node_case_count,
      case_name:
        "depth_#{@large_node_case_depth}_width_#{@large_node_case_width}_nodes_#{@large_node_case_count}"
    }

    base_cases ++ [large_case]
  end

  @spec configs_for(Config.t()) :: [Config.t()]
  def configs_for(%Config{} = base_config) do
    case_definitions()
    |> Enum.with_index(fn case_opts, index ->
      %{
        iterations: base_config.iterations,
        suites: base_config.suites,
        seed: base_config.seed + index,
        node_count: case_opts.node_count,
        depth: case_opts.depth,
        branching_factor: case_opts.branching_factor,
        ci: base_config.ci,
        format: base_config.format
      }
      |> then(fn options ->
        base_config
        |> Config.from_options(options)
        |> Map.put(:case_name, case_opts.case_name)
      end)
    end)
  end

  defp max_nodes_possible(1, _branching_factor), do: 1

  defp max_nodes_possible(depth, branching_factor) do
    1 + branching_factor * max_nodes_possible(depth - 1, branching_factor)
  end
end
