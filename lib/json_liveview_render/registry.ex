defmodule JsonLiveviewRender.Registry do
  @moduledoc """
  Registry DSL for mapping catalog component types to render callbacks.

  Example:

      defmodule MyApp.UIRegistry do
        use JsonLiveviewRender.Registry, catalog: MyApp.UICatalog

        render :metric, &MyAppWeb.Components.metric/1
      end
  """

  defmacro __using__(opts) do
    catalog = Keyword.fetch!(opts, :catalog)
    check_catalog_coverage = Keyword.get(opts, :check_catalog_coverage, false)

    quote bind_quoted: [catalog: catalog, check_catalog_coverage: check_catalog_coverage] do
      import JsonLiveviewRender.Registry, only: [render: 2]

      @genui_registry_catalog catalog
      @genui_registry_check_catalog_coverage check_catalog_coverage
      Module.register_attribute(__MODULE__, :genui_registry_entries, accumulate: true)

      @before_compile JsonLiveviewRender.Registry
    end
  end

  defmacro render(type, fun) do
    normalized_type = normalize_type_literal!(type)

    quote bind_quoted: [type: normalized_type, fun_ast: Macro.escape(fun)] do
      Module.put_attribute(__MODULE__, :genui_registry_entries, {type, fun_ast})
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    entries = env.module |> Module.get_attribute(:genui_registry_entries) |> Enum.reverse()
    catalog = Module.get_attribute(env.module, :genui_registry_catalog)

    check_catalog_coverage =
      Module.get_attribute(env.module, :genui_registry_check_catalog_coverage)

    validate_registry_entries!(env.module, catalog, entries, check_catalog_coverage)

    kv_entries =
      for {type, fun_ast} <- entries do
        quote do
          {unquote(type), unquote(fun_ast)}
        end
      end

    latest_entries = dedupe_latest_entries(entries)

    fetch_clauses =
      for {type, fun_ast} <- latest_entries do
        string_type = Atom.to_string(type)

        quote do
          def __genui_registry_fetch__(unquote(type)), do: {:ok, unquote(fun_ast)}
          def __genui_registry_fetch__(unquote(string_type)), do: {:ok, unquote(fun_ast)}
          def __genui_registry_has_mapping__(unquote(type)), do: true
          def __genui_registry_has_mapping__(unquote(string_type)), do: true
        end
      end

    quote do
      def __genui_registry__ do
        entries = [unquote_splicing(kv_entries)]

        Map.new(entries)
      end

      unquote_splicing(fetch_clauses)
      def __genui_registry_fetch__(_type), do: :error
      def __genui_registry_has_mapping__(_type), do: false

      def __genui_registry_catalog__, do: @genui_registry_catalog
    end
  end

  @doc "Fetches a registry callback by component type, raises on missing mapping."
  @spec fetch!(module(), atom() | String.t()) :: (map() -> term())
  def fetch!(registry_module, component_type) do
    case registry_module.__genui_registry_fetch__(component_type) do
      {:ok, callback} ->
        callback

      :error ->
        raise ArgumentError,
              "missing registry mapping for component #{inspect(component_type)} in #{inspect(registry_module)}"
    end
  end

  @doc "Checks whether a component type is mapped in a registry."
  @spec has_mapping?(module(), atom() | String.t()) :: boolean()
  def has_mapping?(registry_module, component_type),
    do: registry_module.__genui_registry_has_mapping__(component_type)

  defp normalize_type_literal!(type) when is_atom(type), do: type
  defp normalize_type_literal!(type) when is_binary(type), do: String.to_atom(type)

  defp normalize_type_literal!(type) do
    raise ArgumentError, "render/2 type must be atom or string, got: #{Macro.to_string(type)}"
  end

  defp validate_registry_entries!(
         registry_module,
         catalog_module,
         entries,
         check_catalog_coverage
       ) do
    with {:module, _} <- Code.ensure_compiled(catalog_module),
         true <- function_exported?(catalog_module, :types, 0) do
      mapped_types = entries |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort()
      catalog_types = catalog_module.types()

      unknown_mappings = mapped_types -- catalog_types

      if unknown_mappings != [] do
        available_types = catalog_types |> Enum.map(&inspect/1) |> Enum.join(", ")

        raise CompileError,
          description:
            "registry #{inspect(registry_module)} maps unknown component types #{inspect(unknown_mappings)} " <>
              "that do not exist in catalog #{inspect(catalog_module)}.\n" <>
              "Available types: [#{available_types}]"
      end

      if check_catalog_coverage do
        missing_mappings = catalog_types -- mapped_types

        if missing_mappings != [] do
          IO.warn(
            "registry #{inspect(registry_module)} does not map catalog component types #{inspect(missing_mappings)}"
          )
        end
      end
    else
      _ -> :ok
    end
  end

  defp dedupe_latest_entries(entries) do
    entries
    |> Enum.reverse()
    |> Enum.uniq_by(&elem(&1, 0))
    |> Enum.reverse()
  end
end
