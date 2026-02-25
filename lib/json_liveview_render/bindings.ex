defmodule JsonLiveviewRender.Bindings do
  @moduledoc "Resolves `*_binding` props into runtime values from bindings assigns."

  alias JsonLiveviewRender.Catalog.PropDef
  alias JsonLiveviewRender.Bindings.Error

  @spec resolve_props(map(), map()) :: map()
  def resolve_props(props, bindings), do: resolve_props(props, bindings, [])

  @spec resolve_props(map(), map(), keyword()) :: map()
  def resolve_props(props, bindings, opts)
      when is_map(props) and is_map(bindings) and is_list(opts) do
    prop_defs = Keyword.get(opts, :prop_defs, %{})
    check_types? = Keyword.get(opts, :check_types, false)

    Enum.reduce(props, %{}, fn {key, value}, acc ->
      key = to_string(key)

      if String.ends_with?(key, "_binding") do
        binding_key = extract_binding_key(value)
        resolved_key = String.replace_suffix(key, "_binding", "")
        resolved = fetch_binding!(bindings, binding_key)

        if check_types? do
          validate_binding_type!(resolved_key, key, resolved, prop_defs)
        end

        Map.put(acc, resolved_key, resolved)
      else
        Map.put(acc, key, value)
      end
    end)
  end

  defp extract_binding_key(value) when is_binary(value), do: value
  defp extract_binding_key(value) when is_atom(value), do: Atom.to_string(value)

  defp extract_binding_key(value) do
    raise Error,
      type: :invalid_binding_key,
      key: inspect(value),
      message: "invalid binding key #{inspect(value)}; expected string or atom"
  end

  defp fetch_binding!(bindings, key) do
    cond do
      Map.has_key?(bindings, key) ->
        Map.fetch!(bindings, key)

      maybe_atom_key = maybe_existing_atom(key) ->
        if Map.has_key?(bindings, maybe_atom_key) do
          Map.fetch!(bindings, maybe_atom_key)
        else
          raise Error,
            type: :missing_binding,
            key: key,
            message: "missing binding for key #{inspect(key)}"
        end

      true ->
        raise Error,
          type: :missing_binding,
          key: key,
          message: "missing binding for key #{inspect(key)}"
    end
  end

  defp validate_binding_type!(resolved_key, binding_key, value, prop_defs) do
    expected_prop_def = expected_prop_def(prop_defs, binding_key, resolved_key)

    case expected_prop_def do
      nil ->
        :ok

      %PropDef{} = prop_def ->
        if prop_valid?(value, prop_def) do
          :ok
        else
          raise Error,
            type: :invalid_binding_type,
            key: resolved_key,
            expected: prop_def.type,
            actual: value,
            message:
              "binding for #{inspect(resolved_key)} has invalid type; expected #{inspect(prop_def.type)}, got #{inspect(value)}"
        end
    end
  end

  defp expected_prop_def(prop_defs, binding_key, resolved_key) do
    case find_prop_def(prop_defs, binding_key) do
      %PropDef{binding_type: nil} ->
        find_prop_def(prop_defs, resolved_key)

      %PropDef{} = binding_prop_def ->
        %PropDef{
          binding_prop_def
          | type: binding_prop_def.binding_type,
            values: binding_prop_def.values
        }

      nil ->
        find_prop_def(prop_defs, resolved_key)
    end
  end

  defp find_prop_def(prop_defs, key) do
    Enum.find_value(prop_defs, fn
      {prop_name, %PropDef{} = prop_def} ->
        if Atom.to_string(prop_name) == key, do: prop_def

      _ ->
        nil
    end)
  end

  defp prop_valid?(nil, %PropDef{required: false}), do: true
  defp prop_valid?(nil, _), do: false
  defp prop_valid?(value, %PropDef{type: :string}), do: is_binary(value)
  defp prop_valid?(value, %PropDef{type: :integer}), do: is_integer(value)
  defp prop_valid?(value, %PropDef{type: :float}), do: is_integer(value) or is_float(value)
  defp prop_valid?(value, %PropDef{type: :boolean}), do: is_boolean(value)
  defp prop_valid?(value, %PropDef{type: :map}), do: is_map(value)

  defp prop_valid?(value, %PropDef{type: :enum, values: values}) do
    value in values or to_string(value) in Enum.map(values || [], &to_string/1)
  end

  defp prop_valid?(value, %PropDef{type: {:list, inner}}) when is_list(value) do
    Enum.all?(value, fn item -> prop_valid?(item, %PropDef{name: :_item, type: inner}) end)
  end

  defp prop_valid?(value, %PropDef{type: :custom, validator: validator})
       when is_function(validator, 1),
       do: validator.(value)

  defp prop_valid?(_value, _prop), do: false

  defp maybe_existing_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end
