defmodule JsonLiveviewRender.Benchmark.Config do
  @moduledoc false

  @default_iterations 300
  @default_seed 2026_03_01
  @default_sections 12
  @default_columns 4
  @default_metrics_per_column 12
  @default_suites [:validate, :render]
  @default_format :text

  @type suite :: :validate | :render

  @type t :: %__MODULE__{
          iterations: pos_integer(),
          suites: [suite()],
          seed: integer(),
          sections: pos_integer(),
          columns: pos_integer(),
          metrics_per_column: pos_integer(),
          format: :text | :json,
          ci: boolean()
        }

  defstruct iterations: @default_iterations,
            suites: @default_suites,
            seed: @default_seed,
            sections: @default_sections,
            columns: @default_columns,
            metrics_per_column: @default_metrics_per_column,
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
      sections: config.sections,
      columns: config.columns,
      metrics_per_column: config.metrics_per_column,
      format: config.format,
      ci: config.ci
    }
  end

  defp sanitize_options(raw_options) do
    raw_options
    |> Keyword.update(:seed, @default_seed, &normalize_integer/1)
    |> Keyword.update(:iterations, @default_iterations, &normalize_integer/1)
    |> Keyword.update(:sections, @default_sections, &normalize_integer/1)
    |> Keyword.update(:columns, @default_columns, &normalize_integer/1)
    |> Keyword.update(:metrics_per_column, @default_metrics_per_column, &normalize_integer/1)
    |> Keyword.update(:format, @default_format, &normalize_format/1)
    |> Keyword.update(:suites, @default_suites, &normalize_suites/1)
    |> Keyword.put_new(:ci, false)
  end

  defp validate_options(options) do
    Enum.each([:iterations, :seed, :sections, :columns, :metrics_per_column], fn key ->
      value = Keyword.fetch!(options, key)
      validate_positive_integer!(key, value)
    end)

    options
  end

  defp build_struct(options) do
    %__MODULE__{
      iterations: Keyword.fetch!(options, :iterations),
      suites: Keyword.fetch!(options, :suites),
      seed: Keyword.fetch!(options, :seed),
      sections: Keyword.fetch!(options, :sections),
      columns: Keyword.fetch!(options, :columns),
      metrics_per_column: Keyword.fetch!(options, :metrics_per_column),
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
    |> Enum.map(&normalize_suite/1)
  end

  defp normalize_suites(value) when is_list(value) do
    Enum.map(value, &normalize_suite/1)
  end

  defp normalize_suites(value),
    do: raise(ArgumentError, "invalid suites value: #{inspect(value)}")

  defp normalize_suite("validate"), do: :validate
  defp normalize_suite("render"), do: :render
  defp normalize_suite(:validate), do: :validate
  defp normalize_suite(:render), do: :render
  defp normalize_suite(value), do: raise(ArgumentError, "invalid suite: #{inspect(value)}")

  defp validate_positive_integer!(_key, value) when is_integer(value) and value > 0, do: :ok

  defp validate_positive_integer!(key, value) do
    raise ArgumentError, "expected #{key} to be a positive integer, got: #{inspect(value)}"
  end
end
