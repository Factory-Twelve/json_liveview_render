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
      render_assigns: render_assigns(spec)
    }
  end

  @spec teardown(setup_context()) :: :ok
  def teardown(_context), do: :ok

  @spec build_spec(Config.t()) :: map()
  def build_spec(%Config{} = config) do
    section_payloads = Enum.map(section_indices(config), &build_section_payload(&1, config))

    root_section_ids =
      Enum.map(section_payloads, fn {
                                      section_id,
                                      _section_node,
                                      _row_id,
                                      _row_node,
                                      _column_nodes,
                                      _metric_nodes
                                    } ->
        section_id
      end)

    root_node = %{
      "type" => "row",
      "props" => %{},
      "children" => root_section_ids
    }

    section_nodes =
      Map.new(section_payloads, fn {
                                     section_id,
                                     section_node,
                                     _row_id,
                                     _row_node,
                                     _column_nodes,
                                     _metric_nodes
                                   } ->
        {section_id, section_node}
      end)

    row_nodes =
      Map.new(section_payloads, fn {
                                     _section_id,
                                     _section_node,
                                     row_id,
                                     row_node,
                                     _column_nodes,
                                     _metric_nodes
                                   } ->
        {row_id, row_node}
      end)

    column_nodes =
      section_payloads
      |> Enum.flat_map(fn {
                            _section_id,
                            _section_node,
                            _row_id,
                            _row_node,
                            column_nodes,
                            _metric_nodes
                          } ->
        column_nodes
      end)
      |> Map.new()

    metric_nodes =
      section_payloads
      |> Enum.flat_map(fn {
                            _section_id,
                            _section_node,
                            _row_id,
                            _row_node,
                            _column_nodes,
                            metric_nodes
                          } ->
        metric_nodes
      end)
      |> Map.new()

    elements =
      %{"bench_root" => root_node}
      |> Map.merge(section_nodes)
      |> Map.merge(row_nodes)
      |> Map.merge(column_nodes)
      |> Map.merge(metric_nodes)

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

    {"section_#{section_index}", section_node, row_id, row_node, column_nodes, metric_nodes}
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

  defp render_assigns(spec) do
    [
      spec: spec,
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
