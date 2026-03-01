defmodule JsonLiveviewRender.Benchmark.Data do
  @moduledoc false

  alias JsonLiveviewRender.Benchmark.Config

  @type setup_context :: %{
          spec: map(),
          catalog: module(),
          registry: module(),
          render_assigns: keyword()
        }

  @spec setup(Config.t()) :: setup_context()
  def setup(%Config{} = config) do
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

  @spec build_spec(Config.t()) :: map()
  def build_spec(%Config{} = config) do
    section_payloads = Enum.map(section_indices(config), &build_section_payload(&1, config))

    {root_section_ids, elements} =
      Enum.reduce(section_payloads, {[], %{}}, fn payload, {ids, elems} ->
        elems =
          elems
          |> Map.put(payload.section_id, payload.section_node)
          |> Map.put(payload.row_id, payload.row_node)
          |> Map.merge(Map.new(payload.column_nodes))
          |> Map.merge(Map.new(payload.metric_nodes))

        {[payload.section_id | ids], elems}
      end)

    root_node = %{
      "type" => "row",
      "props" => %{},
      "children" => Enum.reverse(root_section_ids)
    }

    elements = Map.put(elements, "bench_root", root_node)

    %{"root" => "bench_root", "elements" => elements}
  end

  defp section_indices(%Config{} = config), do: 1..config.sections

  defp build_section_payload(section_index, %Config{} = config) do
    row_id = "section_#{section_index}_row"
    column_nodes = build_column_nodes(section_index, config)
    metric_nodes = build_metric_nodes(section_index, config)

    section_node = %{
      "type" => "section_metric_card",
      "props" => %{"title" => "Benchmark section #{section_index}"},
      "children" => [row_id]
    }

    row_node = %{
      "type" => "row",
      "props" => %{},
      "children" => Enum.map(column_nodes, fn {id, _node} -> id end)
    }

    %{
      section_id: "section_#{section_index}",
      section_node: section_node,
      row_id: row_id,
      row_node: row_node,
      column_nodes: column_nodes,
      metric_nodes: metric_nodes
    }
  end

  defp build_column_nodes(section_index, %Config{} = config) do
    1..config.columns
    |> Enum.map(fn column_index ->
      metric_ids =
        1..config.metrics_per_column
        |> Enum.map(fn metric_index ->
          "metric_#{section_index}_#{column_index}_#{metric_index}"
        end)

      {"section_#{section_index}_col_#{column_index}",
       %{
         "type" => "column",
         "props" => %{},
         "children" => metric_ids
       }}
    end)
  end

  defp build_metric_nodes(section_index, %Config{} = config) do
    for column_index <- 1..config.columns,
        metric_index <- 1..config.metrics_per_column do
      id = "metric_#{section_index}_#{column_index}_#{metric_index}"
      value = metric_value(section_index, column_index, metric_index, config.seed)

      {id,
       %{
         "type" => "metric",
         "props" => %{
           "label" => "Metric #{section_index}.#{column_index}.#{metric_index}",
           "value" => Integer.to_string(value)
         },
         "children" => []
       }}
    end
  end

  defp metric_value(section_index, column_index, metric_index, seed) do
    rem(section_index * 19_231 + column_index * 971 + metric_index * 37 + seed, 10_000)
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
