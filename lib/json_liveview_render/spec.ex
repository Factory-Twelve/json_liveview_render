defmodule JsonLiveviewRender.Spec do
  @moduledoc "Validates JsonLiveviewRender flat specs against a catalog contract."

  require Logger

  alias JsonLiveviewRender.Catalog.ComponentDef
  alias JsonLiveviewRender.Catalog.PropDef
  alias JsonLiveviewRender.Spec.Errors

  @type validation_result :: {:ok, map()} | {:error, [term()]}

  @spec validate(map() | String.t(), module()) :: validation_result()
  def validate(spec, catalog), do: validate(spec, catalog, strict: true)

  @spec validate(map() | String.t(), module(), keyword()) :: validation_result()
  def validate(spec, catalog, opts) when is_list(opts) do
    strict? = Keyword.get(opts, :strict, true)

    with {:ok, spec_map} <- parse_spec(spec),
         {:ok, root, elements} <- validate_structure(spec_map),
         [] <- validate_references(elements),
         [] <- detect_cycles(root, elements),
         [] <- validate_elements(elements, catalog, strict?) do
      {:ok, %{"root" => root, "elements" => elements}}
    else
      {:error, reasons} when is_list(reasons) -> {:error, reasons}
      reasons when is_list(reasons) -> {:error, reasons}
      reason -> {:error, [reason]}
    end
  end

  @spec validate_element(String.t(), map(), module()) :: :ok | {:error, term()}
  def validate_element(id, element, catalog),
    do: validate_element(id, element, catalog, strict: true)

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

  defp normalize_spec_map(%{"root" => _root, "elements" => _elements} = spec), do: spec

  defp normalize_spec_map(spec) do
    root = Map.get(spec, :root) || Map.get(spec, "root")
    elements = Map.get(spec, :elements) || Map.get(spec, "elements")

    %{"root" => root, "elements" => normalize_elements(elements || %{})}
  end

  defp normalize_elements(elements) when is_map(elements) do
    Map.new(elements, fn {id, element} ->
      {to_string(id), normalize_element(element)}
    end)
  end

  defp normalize_elements(_), do: %{}

  defp normalize_element(element) when is_map(element) do
    type = Map.get(element, "type") || Map.get(element, :type)
    props = Map.get(element, "props") || Map.get(element, :props) || %{}
    children = Map.get(element, "children") || Map.get(element, :children) || []

    %{
      "type" => if(is_atom(type), do: Atom.to_string(type), else: type),
      "props" => normalize_props(props),
      "children" => normalize_children(children)
    }
  end

  defp normalize_element(_), do: %{}

  defp normalize_props(props) when is_map(props) do
    Map.new(props, fn {k, v} -> {to_string(k), v} end)
  end

  defp normalize_props(_), do: %{}

  defp normalize_children(children) when is_list(children), do: Enum.map(children, &to_string/1)
  defp normalize_children(_), do: []

  defp validate_structure(spec) do
    root = spec["root"]
    elements = spec["elements"]

    cond do
      is_nil(root) ->
        {:error, [Errors.root_missing()]}

      not is_binary(root) ->
        {:error, [{:invalid_root_type, "root must be a string"}]}

      not is_map(elements) ->
        {:error, [Errors.elements_missing()]}

      not Map.has_key?(elements, root) ->
        {:error, [Errors.root_not_found(root)]}

      true ->
        {:ok, root, elements}
    end
  end

  defp validate_references(elements) do
    Enum.flat_map(elements, fn {id, element} ->
      case element do
        %{} ->
          children = Map.get(element, "children", [])

          cond do
            not is_list(children) ->
              [Errors.invalid_children_type(id)]

            true ->
              Enum.reduce(children, [], fn child_id, acc ->
                if is_binary(child_id) and Map.has_key?(elements, child_id) do
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

  defp detect_cycles(root, elements) do
    {_visited, cycles} = dfs(root, elements, MapSet.new(), [], [])
    cycles
  end

  defp dfs(id, elements, visited, path, cycles) do
    cond do
      id in path ->
        cycle_path = path ++ [id]
        {visited, cycles ++ [Errors.cycle_detected(cycle_path)]}

      MapSet.member?(visited, id) ->
        {visited, cycles}

      true ->
        children = elements |> Map.get(id, %{}) |> Map.get("children", [])
        new_visited = MapSet.put(visited, id)

        Enum.reduce(children, {new_visited, cycles}, fn child, {acc_visited, acc_cycles} ->
          dfs(child, elements, acc_visited, path ++ [id], acc_cycles)
        end)
    end
  end

  defp validate_elements(elements, catalog, strict?) do
    Enum.flat_map(elements, fn {id, element} ->
      case validate_element(id, element, catalog, strict: strict?) do
        :ok -> []
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

          if prop_valid?(value, prop_def) do
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
      [error | _] -> {:error, error}
    end
  end

  defp validate_element_props(id, _element, _catalog, _strict?),
    do: {:error, {:invalid_props, "element #{inspect(id)} props must be a map"}}

  defp prop_valid?(nil, %PropDef{required: false}), do: true
  defp prop_valid?(nil, _), do: false
  defp prop_valid?(value, %PropDef{type: :string}), do: is_binary(value)
  defp prop_valid?(value, %PropDef{type: :integer}), do: is_integer(value)
  defp prop_valid?(value, %PropDef{type: :float}), do: is_integer(value) or is_float(value)
  defp prop_valid?(value, %PropDef{type: :boolean}), do: is_boolean(value)
  defp prop_valid?(value, %PropDef{type: :map}), do: is_map(value)

  defp prop_valid?(value, %PropDef{type: :enum, values: values}) do
    value in values or to_string(value) in Enum.map(values, &to_string/1)
  end

  defp prop_valid?(value, %PropDef{type: {:list, inner}}) when is_list(value) do
    Enum.all?(value, fn item -> prop_valid?(item, %PropDef{name: :_item, type: inner}) end)
  end

  defp prop_valid?(value, %PropDef{type: :custom, validator: validator})
       when is_function(validator, 1),
       do: validator.(value)

  defp prop_valid?(_value, _prop), do: false
end
