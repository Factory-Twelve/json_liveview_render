defmodule JsonLiveviewRender.Benchmark.Data do
  @moduledoc false

  @root_node_id "bench_root"
  @rng_mask 0xFFFF_FFFF
  @container_types [:row, :column, :section, :section_metric_card]

  @type setup_context :: %{
          spec: map(),
          catalog: module(),
          registry: module(),
          render_assigns: keyword()
        }

  @spec setup(JsonLiveviewRender.Benchmark.Config.t()) :: setup_context()
  def setup(%JsonLiveviewRender.Benchmark.Config{} = config) do
    spec = build_spec(config)

    %{
      spec: spec,
      catalog: JsonLiveviewRender.Benchmark.Catalog,
      registry: JsonLiveviewRender.Benchmark.Registry,
      render_assigns: render_assigns()
    }
  end

  @spec teardown(setup_context()) :: :ok
  def teardown(_context), do: :ok

  @spec build_spec(JsonLiveviewRender.Benchmark.Config.t()) :: map()
  def build_spec(%JsonLiveviewRender.Benchmark.Config{} = config) do
    seed = normalize_seed(config.seed)

    {elements, _next_id, _rng} =
      build_node(@root_node_id, config.depth, config.node_count, 2, seed, config)

    %{"root" => @root_node_id, "elements" => elements}
  end

  defp build_node(
         node_id,
         _remaining_depth,
         nodes_in_subtree,
         next_id,
         rng,
         _config
       )
       when nodes_in_subtree <= 1 do
    {metric_node, next_rng} = build_metric_node(node_id, rng)
    {%{node_id => metric_node}, next_id, next_rng}
  end

  defp build_node(
         node_id,
         remaining_depth,
         nodes_in_subtree,
         next_id,
         rng,
         config
       ) do
    max_children_nodes = max_nodes_possible(remaining_depth - 1, config.branching_factor)
    max_children = min(config.branching_factor, nodes_in_subtree - 1)
    min_children = ceil_div(nodes_in_subtree - 1, max_children_nodes)
    min_children = min(min_children, max_children)

    {children_count, rng} = rand_between(rng, min_children, max_children)

    {children_sizes, rng} =
      distribute_nodes(
        rng,
        nodes_in_subtree - 1,
        children_count,
        remaining_depth - 1,
        config.branching_factor,
        []
      )

    {children_ids, child_elements, next_id, rng} =
      build_children(children_sizes, config, remaining_depth - 1, next_id, rng)

    {container_type, rng} = pick_container_type(rng)
    {container_props, rng} = container_props(container_type, node_id, rng)

    container_node = %{
      "type" => Atom.to_string(container_type),
      "props" => container_props,
      "children" => children_ids
    }

    elements = Map.put(child_elements, node_id, container_node)
    {elements, next_id, rng}
  end

  defp build_children(sizes, config, child_depth, next_id, rng) do
    build_children(sizes, config, child_depth, next_id, rng, [], %{})
  end

  defp build_children(
         sizes,
         config,
         child_depth,
         next_id,
         rng,
         child_ids,
         child_elements
       ) do
    Enum.reduce(sizes, {child_ids, child_elements, next_id, rng}, fn size,
                                                                     {ids_acc, elements_acc,
                                                                      next_id_acc, rng_acc} ->
      child_id = "node_#{next_id_acc}"

      {child_map, next_id_after, rng_after} =
        build_node(child_id, child_depth, size, next_id_acc + 1, rng_acc, config)

      {[child_id | ids_acc], Map.merge(elements_acc, child_map), next_id_after, rng_after}
    end)
    |> then(fn {ids_acc, elements_acc, final_next, final_rng} ->
      {Enum.reverse(ids_acc), elements_acc, final_next, final_rng}
    end)
  end

  defp distribute_nodes(rng, total_nodes, children_count, _child_depth, _branching_factor, acc)
       when total_nodes == 0 and children_count == 0 do
    {Enum.reverse(acc), rng}
  end

  defp distribute_nodes(rng, total_nodes, children_count, child_depth, branching_factor, acc) do
    max_nodes_per_child = max_nodes_possible(child_depth, branching_factor)
    remaining_children = children_count - 1
    min_for_current = max(1, total_nodes - remaining_children * max_nodes_per_child)
    max_for_current = min(max_nodes_per_child, total_nodes - remaining_children)

    {nodes_for_current, rng} = rand_between(rng, min_for_current, max_for_current)

    distribute_nodes(
      rng,
      total_nodes - nodes_for_current,
      remaining_children,
      child_depth,
      branching_factor,
      [nodes_for_current | acc]
    )
  end

  defp pick_container_type(rng) do
    {index, next_rng} = rand_between(rng, 0, length(@container_types) - 1)
    {Enum.at(@container_types, index), next_rng}
  end

  defp container_props(:section, node_id, rng) do
    {suffix, next_rng} = rand_between(rng, 0, 9_999)
    {%{"title" => "Section #{node_id} ##{suffix}"}, next_rng}
  end

  defp container_props(:section_metric_card, node_id, rng) do
    {suffix, next_rng} = rand_between(rng, 0, 9_999)
    {%{"title" => "Section metric #{node_id} ##{suffix}"}, next_rng}
  end

  defp container_props(_type, _node_id, rng), do: {%{}, rng}

  defp build_metric_node(node_id, rng) do
    {suffix, next_rng} = rand_between(rng, 0, 99_999)
    {value, next_rng} = rand_between(next_rng, 0, 9_999)

    {
      %{
        "type" => "metric",
        "props" => %{
          "label" => "Metric #{node_id} ##{suffix}",
          "value" => Integer.to_string(value)
        },
        "children" => []
      },
      next_rng
    }
  end

  defp rand_between(_rng, min, max) when min > max do
    raise ArgumentError, "invalid random range: #{min}..#{max}"
  end

  defp rand_between(rng, min, max) do
    range = max - min + 1
    next_rng = next_seed(rng)
    {min + rem(next_rng, range), next_rng}
  end

  defp next_seed(seed) do
    step1 = Bitwise.bxor(seed, Bitwise.bsl(seed, 13))
    step2 = Bitwise.bxor(step1, Bitwise.bsr(step1, 17))
    step3 = Bitwise.bxor(step2, Bitwise.bsl(step2, 5))
    Bitwise.band(step3, @rng_mask)
  end

  defp normalize_seed(seed) when is_integer(seed) do
    Bitwise.band(seed, @rng_mask)
  end

  defp ceil_div(numerator, denominator) do
    div(numerator + denominator - 1, denominator)
  end

  defp max_nodes_possible(1, _branching_factor), do: 1

  defp max_nodes_possible(depth, branching_factor) do
    1 + branching_factor * max_nodes_possible(depth - 1, branching_factor)
  end

  defp render_assigns do
    [
      catalog: JsonLiveviewRender.Benchmark.Catalog,
      registry: JsonLiveviewRender.Benchmark.Registry,
      current_user: %{role: :member},
      authorizer: JsonLiveviewRender.Authorizer.AllowAll,
      strict: true,
      bindings: %{},
      check_binding_types: false,
      allow_partial: false,
      dev_tools: false,
      dev_tools_open: false,
      dev_tools_enabled: false,
      dev_tools_force_disable: true
    ]
  end
end
