defmodule JsonLiveviewRender.Benchmark.Config do
  @moduledoc false

  @default_iterations 300
  @default_seed 2026_03_01
  @legacy_node_count 637
  @default_node_count @legacy_node_count
  @default_depth 6
  @default_branching_factor 4
  @default_suites [:validate, :render]
  @default_format :text

  @type suite :: :validate | :render

  @type t :: %__MODULE__{
          iterations: pos_integer(),
          suites: [suite()],
          seed: integer(),
          node_count: pos_integer(),
          depth: pos_integer(),
          branching_factor: pos_integer(),
          format: :text | :json,
          ci: boolean()
        }

  defstruct iterations: @default_iterations,
            suites: @default_suites,
            seed: @default_seed,
            node_count: @default_node_count,
            depth: @default_depth,
            branching_factor: @default_branching_factor,
            format: @default_format,
            ci: false

  @doc false
  @spec from_options(Keyword.t()) :: t()
  def from_options(options) when is_list(options) do
    options
    |> sanitize_options()
    |> validate_options()
    |> build_struct()
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = config) do
    %{
      iterations: config.iterations,
      suites: Enum.map(config.suites, &Atom.to_string/1),
      seed: config.seed,
      node_count: config.node_count,
      depth: config.depth,
      branching_factor: config.branching_factor,
      format: config.format,
      ci: config.ci
    }
  end

  defp sanitize_options(raw_options) do
    raw_options
    |> apply_legacy_shape_options()
    |> Keyword.update(:seed, @default_seed, &normalize_integer/1)
    |> Keyword.update(:iterations, @default_iterations, &normalize_integer/1)
    |> Keyword.update(:node_count, @default_node_count, &normalize_integer/1)
    |> Keyword.update(:depth, @default_depth, &normalize_integer/1)
    |> Keyword.update(:branching_factor, @default_branching_factor, &normalize_integer/1)
    |> Keyword.update(:format, @default_format, &normalize_format/1)
    |> Keyword.update(:suites, @default_suites, &normalize_suites/1)
    |> Keyword.put_new(:ci, false)
  end

  defp validate_options(options) do
    Enum.each([:iterations, :seed, :node_count, :depth, :branching_factor], fn key ->
      value = Keyword.fetch!(options, key)
      validate_positive_integer!(key, value)
    end)

    validate_shape_capacity!(options)
    options
  end

  defp apply_legacy_shape_options(options) do
    if Keyword.has_key?(options, :node_count) do
      options
      |> Keyword.delete(:sections)
      |> Keyword.delete(:columns)
      |> Keyword.delete(:metrics_per_column)
    else
      has_legacy_option? =
        Enum.any?([:sections, :columns, :metrics_per_column], &Keyword.has_key?(options, &1))

      if has_legacy_option? do
        options
        |> Keyword.put_new(
          :node_count,
          compute_legacy_node_count(
            Keyword.get(options, :sections, 12),
            Keyword.get(options, :columns, 4),
            Keyword.get(options, :metrics_per_column, 12)
          )
        )
        |> Keyword.delete(:sections)
        |> Keyword.delete(:columns)
        |> Keyword.delete(:metrics_per_column)
      else
        options
      end
    end
  end

  defp compute_legacy_node_count(sections, columns, metrics_per_column) do
    sections = normalize_integer(sections)
    columns = normalize_integer(columns)
    metrics_per_column = normalize_integer(metrics_per_column)

    1 + sections * (1 + columns * (1 + metrics_per_column))
  end

  defp validate_shape_capacity!(options) do
    node_count = Keyword.fetch!(options, :node_count)
    depth = Keyword.fetch!(options, :depth)
    branching_factor = Keyword.fetch!(options, :branching_factor)
    max_nodes = max_nodes_possible(depth, branching_factor)

    if node_count > max_nodes do
      raise ArgumentError,
            "invalid benchmark shape: node_count #{node_count} exceeds max nodes #{max_nodes} for depth #{depth} and branching_factor #{branching_factor}"
    end
  end

  defp build_struct(options) do
    %__MODULE__{
      iterations: Keyword.fetch!(options, :iterations),
      suites: Keyword.fetch!(options, :suites),
      seed: Keyword.fetch!(options, :seed),
      node_count: Keyword.fetch!(options, :node_count),
      depth: Keyword.fetch!(options, :depth),
      branching_factor: Keyword.fetch!(options, :branching_factor),
      format: Keyword.fetch!(options, :format),
      ci: Keyword.fetch!(options, :ci)
    }
  end

  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> parsed
      _ -> raise ArgumentError, "invalid integer value: #{inspect(value)}"
    end
  end

  defp normalize_integer(value),
    do: raise(ArgumentError, "invalid integer value: #{inspect(value)}")

  defp normalize_format(:text), do: :text
  defp normalize_format("text"), do: :text
  defp normalize_format(:json), do: :json
  defp normalize_format("json"), do: :json
  defp normalize_format(value), do: raise(ArgumentError, "invalid format: #{inspect(value)}")

  defp normalize_suites(value) when is_binary(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> validate_non_empty_suites!()
    |> Enum.map(&normalize_suite/1)
  end

  defp normalize_suites(value) when is_list(value) do
    value
    |> Enum.map(&normalize_suite_input/1)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> validate_non_empty_suites!()
    |> Enum.map(&normalize_suite/1)
  end

  defp normalize_suites(value),
    do: raise(ArgumentError, "invalid suites value: #{inspect(value)}")

  defp normalize_suite_input(value) when is_binary(value), do: String.trim(value)
  defp normalize_suite_input(value), do: value

  defp validate_non_empty_suites!([]),
    do: raise(ArgumentError, "expected at least one suite, got: []")

  defp validate_non_empty_suites!(suites), do: suites

  defp normalize_suite("validate"), do: :validate
  defp normalize_suite("render"), do: :render
  defp normalize_suite(:validate), do: :validate
  defp normalize_suite(:render), do: :render
  defp normalize_suite(value), do: raise(ArgumentError, "invalid suite: #{inspect(value)}")

  defp validate_positive_integer!(_key, value) when is_integer(value) and value > 0, do: :ok

  defp validate_positive_integer!(key, value) do
    raise ArgumentError, "expected #{key} to be a positive integer, got: #{inspect(value)}"
  end

  defp max_nodes_possible(1, _branching_factor), do: 1

  defp max_nodes_possible(depth, branching_factor) do
    1 + branching_factor * max_nodes_possible(depth - 1, branching_factor)
  end
end
