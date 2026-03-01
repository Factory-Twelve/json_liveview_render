defmodule JsonLiveviewRender.Spec do
  @moduledoc """
  v0.2 stable validation contract for flat `root + elements` specs.

  Validates:
  - spec shape and root reference
  - child reference resolution
  - cycle freedom
  - component existence and prop contracts
  """

  require Logger

  alias JsonLiveviewRender.Catalog.ComponentDef
  alias JsonLiveviewRender.Catalog.PropDef
  alias JsonLiveviewRender.Spec.AutoFix
  alias JsonLiveviewRender.Spec.Errors
  alias JsonLiveviewRender.Spec.Normalizer

  @type validation_result :: {:ok, map()} | {:error, [term()]}

  @doc """
  Auto-fixes common AI mistakes in a spec (prop coercion, children normalization).

      iex> defmodule DocCatalog2 do
      ...>   use JsonLiveviewRender.Catalog
      ...>   component :metric do
      ...>     description "KPI"
      ...>     prop :label, :string, required: true
      ...>     prop :value, :integer, required: true
      ...>   end
      ...> end
      iex> spec = %{"root" => "m", "elements" => %{"m" => %{"type" => "metric", "props" => %{"label" => "Rev", "value" => "42"}, "children" => []}}}
      iex> {:ok, fixed, fixes} = JsonLiveviewRender.Spec.auto_fix(spec, DocCatalog2)
      iex> fixed["elements"]["m"]["props"]["value"]
      42
      iex> length(fixes) > 0
      true
  """
  defdelegate auto_fix(spec, catalog), to: AutoFix

  @doc """
  Formats validation errors into a human-readable string for AI re-prompting.

      iex> errors = [{:root_missing, "spec must include a root key"}]
      iex> result = JsonLiveviewRender.Spec.format_errors(errors)
      iex> result =~ "root key"
      true
  """
  defdelegate format_errors(errors), to: Errors
  defdelegate format_errors(errors, catalog), to: Errors

  @doc """
  Validates a UI spec against a component catalog (strict mode).

  Returns `{:ok, normalized_spec}` or `{:error, reasons}`.

      iex> defmodule DocCatalog1 do
      ...>   use JsonLiveviewRender.Catalog
      ...>   component :metric do
      ...>     description "KPI"
      ...>     prop :label, :string, required: true
      ...>     prop :value, :string, required: true
      ...>   end
      ...> end
      iex> spec = %{"root" => "m", "elements" => %{"m" => %{"type" => "metric", "props" => %{"label" => "Rev", "value" => "$1"}, "children" => []}}}
      iex> {:ok, _} = JsonLiveviewRender.Spec.validate(spec, DocCatalog1)
      iex> bad = %{"root" => "m", "elements" => %{"m" => %{"type" => "nope", "props" => %{}, "children" => []}}}
      iex> {:error, [{:unknown_component, _}]} = JsonLiveviewRender.Spec.validate(bad, DocCatalog1)
  """
  @spec validate(map() | String.t(), module()) :: validation_result()
  def validate(spec, catalog), do: validate(spec, catalog, strict: true)

  @doc """
  Validates a partial spec for progressive streaming/rendering scenarios.

  Unlike `validate/3`, partial validation allows:
  - missing `root`
  - unresolved child references (elements that have not arrived yet)
  """
  @spec validate_partial(map() | String.t(), module(), keyword()) :: validation_result()
  def validate_partial(spec, catalog, opts \\ []) when is_list(opts) do
    opts =
      [allow_missing_root: true, allow_unresolved_children: true]
      |> Keyword.merge(opts)

    validate(spec, catalog, opts)
  end

  @doc "Validates a UI spec with explicit options (`:strict`, `:allow_missing_root`, `:allow_unresolved_children`)."
  @spec validate(map() | String.t(), module(), keyword()) :: validation_result()
  def validate(spec, catalog, opts) when is_list(opts) do
    strict? = Keyword.get(opts, :strict, true)
    allow_missing_root? = Keyword.get(opts, :allow_missing_root, false)
    allow_unresolved_children? = Keyword.get(opts, :allow_unresolved_children, false)

    with {:ok, spec_map} <- parse_spec(spec),
         {:ok, root, elements} <- validate_structure(spec_map, allow_missing_root?),
         [] <- validate_references(elements, allow_unresolved_children?),
         [] <- detect_cycles(root, elements),
         [] <- validate_elements(elements, catalog, strict?) do
      {:ok, %{"root" => root, "elements" => elements}}
    else
      {:error, reasons} when is_list(reasons) -> {:error, reasons}
      reasons when is_list(reasons) -> {:error, reasons}
      reason -> {:error, [reason]}
    end
  end

  @doc "Validates a single element against the catalog (strict mode)."
  @spec validate_element(String.t(), map(), module()) :: :ok | {:error, term()}
  def validate_element(id, element, catalog),
    do: validate_element(id, element, catalog, strict: true)

  @doc "Validates a single element with explicit options."
  @spec validate_element(String.t(), map(), module(), keyword()) :: :ok | {:error, term()}
  def validate_element(id, element, catalog, opts) when is_map(element) do
    strict? = Keyword.get(opts, :strict, true)

    with :ok <- validate_element_type(id, element, catalog),
         :ok <- validate_element_children(id, element),
         :ok <- validate_element_props(id, element, catalog, strict?) do
      :ok
    end
  end

  defp parse_spec(spec) when is_map(spec), do: {:ok, normalize_spec_map(spec)}

  defp parse_spec(spec) when is_binary(spec) do
    case Jason.decode(spec) do
      {:ok, decoded} -> {:ok, normalize_spec_map(decoded)}
      {:error, reason} -> {:error, [{:invalid_json, reason}]}
    end
  end

  defp parse_spec(_), do: {:error, [{:invalid_spec, "spec must be a map or JSON string"}]}

  defp normalize_spec_map(%{"root" => _root, "elements" => elements} = spec)
       when is_map(elements),
       do: spec

  defp normalize_spec_map(spec) do
    root = Map.get(spec, :root) || Map.get(spec, "root")
    elements = Map.get(spec, :elements) || Map.get(spec, "elements")

    %{"root" => normalize_root(root), "elements" => normalize_elements(elements)}
  end

  defp normalize_elements(elements) when is_map(elements) do
    Map.new(elements, fn {id, element} ->
      {to_string(id), Normalizer.normalize_element(element)}
    end)
  end

  defp normalize_elements(elements), do: elements

  defp normalize_root(nil), do: nil
  defp normalize_root(root) when is_atom(root), do: Atom.to_string(root)
  defp normalize_root(root), do: root

  defp validate_structure(spec, allow_missing_root?) do
    root = spec["root"]
    elements = spec["elements"]

    cond do
      not is_map(elements) ->
        {:error, [Errors.elements_missing()]}

      is_nil(root) and allow_missing_root? ->
        {:ok, nil, elements}

      is_nil(root) ->
        {:error, [Errors.root_missing()]}

      not is_binary(root) ->
        {:error, [{:invalid_root_type, "root must be a string"}]}

      allow_missing_root? and not Map.has_key?(elements, root) ->
        Logger.warning(
          "[JsonLiveviewRender.Spec] partial validation: root #{inspect(root)} not yet present in elements"
        )

        {:ok, root, elements}

      not Map.has_key?(elements, root) ->
        {:error, [Errors.root_not_found(root)]}

      true ->
        {:ok, root, elements}
    end
  end

  defp validate_references(elements, allow_unresolved_children?) do
    Enum.flat_map(elements, fn {id, element} ->
      case element do
        %{} ->
          children = Map.get(element, "children", [])

          cond do
            not is_list(children) ->
              [Errors.invalid_children_type(id)]

            true ->
              Enum.reduce(children, [], fn child_id, acc ->
                if is_binary(child_id) and
                     (allow_unresolved_children? or Map.has_key?(elements, child_id)) do
                  acc
                else
                  [Errors.unresolved_child(id, child_id) | acc]
                end
              end)
              |> Enum.reverse()
          end

        _ ->
          [Errors.invalid_element(id)]
      end
    end)
  end

  defp detect_cycles(nil, _elements), do: []

  defp detect_cycles(root, elements) do
    {_visited, cycles} = dfs(root, elements, MapSet.new(), [], MapSet.new(), [])
    cycles
  end

  defp dfs(id, elements, visited, path_list, path_set, cycles) do
    cond do
      MapSet.member?(path_set, id) ->
        cycle_path = path_list ++ [id]
        {visited, [Errors.cycle_detected(cycle_path) | cycles]}

      MapSet.member?(visited, id) ->
        {visited, cycles}

      true ->
        children = elements |> Map.get(id, %{}) |> Map.get("children", [])
        new_visited = MapSet.put(visited, id)
        new_path_list = path_list ++ [id]
        new_path_set = MapSet.put(path_set, id)

        Enum.reduce(children, {new_visited, cycles}, fn child, {acc_visited, acc_cycles} ->
          dfs(child, elements, acc_visited, new_path_list, new_path_set, acc_cycles)
        end)
    end
  end

  defp validate_elements(elements, catalog, strict?) do
    Enum.flat_map(elements, fn {id, element} ->
      case validate_element(id, element, catalog, strict: strict?) do
        :ok -> []
        {:error, reasons} when is_list(reasons) -> reasons
        {:error, reason} -> [reason]
      end
    end)
  end

  defp validate_element_type(id, %{"type" => type}, catalog) when is_binary(type) do
    case catalog.component(type) do
      %ComponentDef{} -> :ok
      nil -> {:error, Errors.unknown_component(id, type)}
    end
  end

  defp validate_element_type(id, _element, _catalog), do: {:error, Errors.missing_type(id)}

  defp validate_element_children(id, %{"children" => children}) when is_list(children) do
    if Enum.all?(children, &is_binary/1),
      do: :ok,
      else: {:error, Errors.invalid_children_type(id)}
  end

  defp validate_element_children(id, _), do: {:error, Errors.invalid_children_type(id)}

  defp validate_element_props(id, %{"type" => type, "props" => props}, catalog, strict?)
       when is_map(props) do
    component = catalog.component(type)
    known_props = component.props |> Map.keys() |> Enum.map(&Atom.to_string/1) |> MapSet.new()

    unknown_errors =
      props
      |> Map.keys()
      |> Enum.filter(&(not MapSet.member?(known_props, &1)))
      |> Enum.map(fn prop ->
        if strict? do
          Errors.unknown_prop(id, prop)
        else
          Logger.warning(
            "[JsonLiveviewRender.Spec] ignoring unknown prop #{inspect(prop)} for element #{inspect(id)}"
          )

          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    required_errors =
      component.props
      |> Enum.flat_map(fn {prop_name, %PropDef{required: required?, default: default}} ->
        key = Atom.to_string(prop_name)

        if required? and is_nil(default) and not Map.has_key?(props, key) do
          [Errors.missing_required_prop(id, key)]
        else
          []
        end
      end)

    type_errors =
      component.props
      |> Enum.flat_map(fn {prop_name, prop_def} ->
        key = Atom.to_string(prop_name)

        if Map.has_key?(props, key) do
          value = Map.get(props, key)

          if PropDef.valid?(value, prop_def) do
            []
          else
            [Errors.invalid_prop_type(id, key, prop_def.type, value)]
          end
        else
          []
        end
      end)

    errors = unknown_errors ++ required_errors ++ type_errors

    case errors do
      [] -> :ok
      [error] -> {:error, error}
      many -> {:error, many}
    end
  end

  defp validate_element_props(id, _element, _catalog, _strict?),
    do: {:error, {:invalid_props, "element #{inspect(id)} props must be a map"}}
end
