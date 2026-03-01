defmodule JsonLiveviewRender.Benchmark.Matrix do
  @moduledoc false

  alias JsonLiveviewRender.Benchmark.Config

  @suite_order [:validate, :render]

  @validate_case_definitions [
    %{
      case_name: "validate_small_depth_4_width_2_nodes_15",
      seed_offset: 0,
      depth: 4,
      branching_factor: 2,
      node_count: 15
    },
    %{
      case_name: "validate_typical_depth_5_width_4_nodes_341",
      seed_offset: 1,
      depth: 5,
      branching_factor: 4,
      node_count: 341
    },
    %{
      case_name: "validate_pathological_depth_6_width_4_nodes_1024",
      seed_offset: 2,
      depth: 6,
      branching_factor: 4,
      node_count: 1024
    }
  ]

  @render_case_definitions [
    %{
      case_name: "depth_4_width_2",
      seed_offset: 0,
      depth: 4,
      branching_factor: 2,
      node_count: 15
    },
    %{
      case_name: "depth_4_width_4",
      seed_offset: 1,
      depth: 4,
      branching_factor: 4,
      node_count: 85
    },
    %{
      case_name: "depth_5_width_2",
      seed_offset: 2,
      depth: 5,
      branching_factor: 2,
      node_count: 31
    },
    %{
      case_name: "depth_5_width_4",
      seed_offset: 3,
      depth: 5,
      branching_factor: 4,
      node_count: 341
    },
    %{
      case_name: "depth_6_width_4_nodes_1024",
      seed_offset: 4,
      depth: 6,
      branching_factor: 4,
      node_count: 1024
    }
  ]

  @spec case_definitions() :: [
          %{
            required(:depth) => pos_integer(),
            required(:branching_factor) => pos_integer(),
            required(:node_count) => pos_integer(),
            required(:case_name) => String.t(),
            required(:seed_offset) => non_neg_integer()
          }
        ]
  def case_definitions do
    case_definitions([:validate, :render])
  end

  @spec case_definitions([Config.suite()]) :: [
          %{
            required(:depth) => pos_integer(),
            required(:branching_factor) => pos_integer(),
            required(:node_count) => pos_integer(),
            required(:case_name) => String.t(),
            required(:seed_offset) => non_neg_integer()
          }
        ]
  def case_definitions(suites) when is_list(suites) do
    suites
    |> ordered_suites()
    |> Enum.flat_map(&case_definitions_for_suite/1)
  end

  defp case_definitions_for_suite(:validate), do: @validate_case_definitions
  defp case_definitions_for_suite(:render), do: @render_case_definitions

  defp case_definitions_for_suite(_), do: []

  @spec configs_for(Config.t()) :: [Config.t()]
  def configs_for(%Config{} = base_config) do
    base_config.suites
    |> ordered_suites()
    |> Enum.flat_map(fn suite ->
      case_definitions_for_suite(suite)
      |> Enum.map(fn case_opts ->
        [
          iterations: base_config.iterations,
          suites: [suite],
          seed: base_config.seed + case_opts.seed_offset,
          node_count: case_opts.node_count,
          depth: case_opts.depth,
          branching_factor: case_opts.branching_factor,
          ci: base_config.ci,
          format: base_config.format,
          case_name: case_opts.case_name
        ]
        |> Config.from_options()
      end)
    end)
  end

  defp ordered_suites(suites) do
    unique_suites = Enum.uniq(suites)

    @suite_order
    |> Enum.filter(&(&1 in unique_suites))
  end
end
