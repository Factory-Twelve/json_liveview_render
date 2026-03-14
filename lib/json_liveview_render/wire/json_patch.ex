defmodule JsonLiveviewRender.Wire.JsonPatch do
  @moduledoc """
  Applies a narrow JSON Patch surface to canonical specs.

  Supported operations:

  - `add`
  - `remove`
  - `replace`

  Supported paths:

  - `/root`
  - `/elements`
  - `/elements/<id>`
  - `/elements/<id>/type`
  - `/elements/<id>/props`
  - `/elements/<id>/props/<prop>`
  - `/elements/<id>/children`
  - `/elements/<id>/children/<index>`
  - `/elements/<id>/children/-`

  Patch application first canonicalizes the input spec, applies the supported
  operations against canonical paths, and then reuses `JsonLiveviewRender.Spec`
  validation on the patched result.
  """

  alias JsonLiveviewRender.Spec
  alias JsonLiveviewRender.Spec.Normalize
  alias JsonLiveviewRender.Spec.Normalizer

  @type result :: {:ok, map()} | {:error, [term()]}

  @supported_ops ~w(add remove replace)

  @spec apply(map() | String.t(), [map()] | String.t(), module(), keyword()) :: result()
  def apply(spec, patch, catalog, opts \\ []) when is_list(opts) do
    with {:ok, canonical_spec} <- canonical_patchable_spec(spec),
         {:ok, operations} <- normalize_patch(patch),
         {:ok, patched_spec} <- apply_operations(canonical_spec, operations) do
      Spec.validate(patched_spec, catalog, opts)
    end
  end

  defp canonical_patchable_spec(spec) do
    with {:ok, canonical_spec} <- Normalize.canonical(spec),
         {:ok, top_level_presence} <- top_level_presence(spec) do
      {:ok, strip_absent_top_level_keys(canonical_spec, top_level_presence)}
    end
  end

  defp normalize_patch(patch) when is_list(patch) do
    patch
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {operation, index}, {:ok, acc} ->
      case normalize_operation(operation, index) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, operations} -> {:ok, Enum.reverse(operations)}
      {:error, _} = error -> error
    end
  end

  defp normalize_patch(patch) when is_binary(patch) do
    with {:ok, decoded} <- Jason.decode(patch),
         {:ok, operations} <- normalize_patch(decoded) do
      {:ok, operations}
    else
      {:error, %Jason.DecodeError{} = reason} ->
        {:error, [invalid_patch("patch must be valid JSON: #{Exception.message(reason)}")]}

      {:error, _} = error ->
        error
    end
  end

  defp normalize_patch(_patch),
    do: {:error, [invalid_patch("patch must be a list of operations or a JSON array")]}

  defp top_level_presence(spec) when is_map(spec) do
    {:ok,
     %{
       "root" => Map.has_key?(spec, :root) or Map.has_key?(spec, "root"),
       "elements" => Map.has_key?(spec, :elements) or Map.has_key?(spec, "elements")
     }}
  end

  defp top_level_presence(spec) when is_binary(spec) do
    with {:ok, decoded} <- Jason.decode(spec),
         true <- is_map(decoded) or {:error, [invalid_patch("spec must decode to a JSON object")]} do
      top_level_presence(decoded)
    end
  end

  defp strip_absent_top_level_keys(spec, presence) do
    Enum.reduce(presence, spec, fn
      {_key, true}, acc -> acc
      {key, false}, acc -> Map.delete(acc, key)
    end)
  end

  defp normalize_operation(operation, index) when is_map(operation) do
    with {:ok, op} <- normalize_op(operation, index),
         :ok <- ensure_supported_op(op),
         {:ok, path} <- normalize_path(operation, index),
         {:ok, tokens} <- decode_pointer(path),
         :ok <- ensure_value_present(op, operation, index) do
      {:ok,
       %{
         op: op,
         path: path,
         tokens: tokens,
         value_present?: value_present?(operation),
         value: fetch_value(operation)
       }}
    end
  end

  defp normalize_operation(_operation, index) do
    {:error,
     [invalid_patch_operation(index, "must be an object with `op`, `path`, and optional `value`")]}
  end

  defp normalize_op(operation, index) do
    case fetch_key(operation, :op, "op") do
      {:ok, op} when is_binary(op) -> {:ok, op}
      {:ok, op} when is_atom(op) -> {:ok, Atom.to_string(op)}
      {:ok, _op} -> {:error, [invalid_patch_operation(index, "`op` must be a string")]}
      :error -> {:error, [invalid_patch_operation(index, "is missing `op`")]}
    end
  end

  defp normalize_path(operation, index) do
    case fetch_key(operation, :path, "path") do
      {:ok, path} when is_binary(path) -> {:ok, path}
      {:ok, _path} -> {:error, [invalid_patch_operation(index, "`path` must be a string")]}
      :error -> {:error, [invalid_patch_operation(index, "is missing `path`")]}
    end
  end

  defp ensure_supported_op(op) when op in @supported_ops, do: :ok
  defp ensure_supported_op(op), do: {:error, [unsupported_operation(op)]}

  defp ensure_value_present(op, operation, index) when op in ~w(add replace) do
    if value_present?(operation) do
      :ok
    else
      {:error, [invalid_patch_operation(index, "`#{op}` requires a `value`")]}
    end
  end

  defp ensure_value_present(_op, _operation, _index), do: :ok

  defp apply_operations(spec, operations) do
    Enum.reduce_while(operations, {:ok, spec}, fn operation, {:ok, current_spec} ->
      case apply_operation(current_spec, operation) do
        {:ok, updated_spec} -> {:cont, {:ok, updated_spec}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp apply_operation(spec, %{op: "add", path: path, tokens: ["root"], value: value}) do
    if Map.has_key?(spec, "root") do
      {:error, [path_exists(path)]}
    else
      with {:ok, normalized} <- normalize_root_value(path, value) do
        {:ok, Map.put(spec, "root", normalized)}
      end
    end
  end

  defp apply_operation(spec, %{op: "remove", path: path, tokens: ["root"]}) do
    if Map.has_key?(spec, "root") do
      {:ok, Map.delete(spec, "root")}
    else
      {:error, [path_not_found(path)]}
    end
  end

  defp apply_operation(spec, %{op: "replace", path: path, tokens: ["root"], value: value}) do
    if Map.has_key?(spec, "root") do
      with {:ok, normalized} <- normalize_root_value(path, value) do
        {:ok, Map.put(spec, "root", normalized)}
      end
    else
      {:error, [path_not_found(path)]}
    end
  end

  defp apply_operation(spec, %{op: "add", path: path, tokens: ["elements"], value: value}) do
    if Map.has_key?(spec, "elements") do
      {:error, [path_exists(path)]}
    else
      with {:ok, normalized} <- normalize_elements_value(path, value) do
        {:ok, Map.put(spec, "elements", normalized)}
      end
    end
  end

  defp apply_operation(spec, %{op: "remove", path: path, tokens: ["elements"]}) do
    if Map.has_key?(spec, "elements") do
      {:ok, Map.delete(spec, "elements")}
    else
      {:error, [path_not_found(path)]}
    end
  end

  defp apply_operation(spec, %{op: "replace", path: path, tokens: ["elements"], value: value}) do
    if Map.has_key?(spec, "elements") do
      with {:ok, normalized} <- normalize_elements_value(path, value) do
        {:ok, Map.put(spec, "elements", normalized)}
      end
    else
      {:error, [path_not_found(path)]}
    end
  end

  defp apply_operation(spec, %{op: op, path: path, tokens: ["elements", id]} = operation)
       when op in ~w(add remove replace) do
    with {:ok, elements} <- fetch_elements(spec, path) do
      apply_elements_entry_operation(spec, elements, id, operation)
    end
  end

  defp apply_operation(spec, %{op: op, path: path, tokens: ["elements", id, "type"]} = operation)
       when op in ~w(add remove replace) do
    with {:ok, elements} <- fetch_elements(spec, path),
         {:ok, element} <- fetch_element(elements, id, path) do
      apply_object_member_operation(
        element,
        "type",
        path,
        op,
        fn value -> normalize_type_value(path, value) end,
        operation
      )
      |> update_element(spec, elements, id)
    end
  end

  defp apply_operation(spec, %{op: op, path: path, tokens: ["elements", id, "props"]} = operation)
       when op in ~w(add remove replace) do
    with {:ok, elements} <- fetch_elements(spec, path),
         {:ok, element} <- fetch_element(elements, id, path) do
      apply_object_member_operation(
        element,
        "props",
        path,
        op,
        fn value -> normalize_props_value(path, value) end,
        operation
      )
      |> update_element(spec, elements, id)
    end
  end

  defp apply_operation(
         spec,
         %{op: op, path: path, tokens: ["elements", id, "props", prop]} = operation
       )
       when op in ~w(add remove replace) do
    with {:ok, elements} <- fetch_elements(spec, path),
         {:ok, element} <- fetch_element(elements, id, path),
         {:ok, props} <- fetch_map_member(element, "props", path) do
      apply_props_entry_operation(spec, elements, element, props, id, prop, operation)
    end
  end

  defp apply_operation(
         spec,
         %{op: op, path: path, tokens: ["elements", id, "children"]} = operation
       )
       when op in ~w(add remove replace) do
    with {:ok, elements} <- fetch_elements(spec, path),
         {:ok, element} <- fetch_element(elements, id, path) do
      apply_object_member_operation(
        element,
        "children",
        path,
        op,
        fn value -> normalize_children_value(path, value) end,
        operation
      )
      |> update_element(spec, elements, id)
    end
  end

  defp apply_operation(
         spec,
         %{op: op, path: path, tokens: ["elements", id, "children", index_token]} = operation
       )
       when op in ~w(add remove replace) do
    with {:ok, elements} <- fetch_elements(spec, path),
         {:ok, element} <- fetch_element(elements, id, path),
         {:ok, children} <- fetch_list_member(element, "children", path) do
      apply_children_entry_operation(
        spec,
        elements,
        element,
        children,
        id,
        index_token,
        operation
      )
    end
  end

  defp apply_operation(_spec, %{path: path}), do: {:error, [unsupported_path(path)]}

  defp apply_elements_entry_operation(spec, elements, id, %{op: "add", path: path, value: value}) do
    if Map.has_key?(elements, id) do
      {:error, [path_exists(path)]}
    else
      with {:ok, element} <- normalize_element_value(path, value) do
        {:ok, spec |> Map.put("elements", Map.put(elements, id, element))}
      end
    end
  end

  defp apply_elements_entry_operation(spec, elements, id, %{op: "remove", path: path}) do
    if Map.has_key?(elements, id) do
      {:ok, spec |> Map.put("elements", Map.delete(elements, id))}
    else
      {:error, [path_not_found(path)]}
    end
  end

  defp apply_elements_entry_operation(spec, elements, id, %{
         op: "replace",
         path: path,
         value: value
       }) do
    if Map.has_key?(elements, id) do
      with {:ok, element} <- normalize_element_value(path, value) do
        {:ok, spec |> Map.put("elements", Map.put(elements, id, element))}
      end
    else
      {:error, [path_not_found(path)]}
    end
  end

  defp apply_props_entry_operation(spec, elements, element, props, id, prop, %{
         op: "add",
         path: path,
         value: value
       }) do
    if Map.has_key?(props, prop) do
      {:error, [path_exists(path)]}
    else
      updated_element = Map.put(element, "props", Map.put(props, prop, value))
      {:ok, spec |> Map.put("elements", Map.put(elements, id, updated_element))}
    end
  end

  defp apply_props_entry_operation(spec, elements, element, props, id, prop, %{
         op: "remove",
         path: path
       }) do
    if Map.has_key?(props, prop) do
      updated_element = Map.put(element, "props", Map.delete(props, prop))
      {:ok, spec |> Map.put("elements", Map.put(elements, id, updated_element))}
    else
      {:error, [path_not_found(path)]}
    end
  end

  defp apply_props_entry_operation(spec, elements, element, props, id, prop, %{
         op: "replace",
         path: path,
         value: value
       }) do
    if Map.has_key?(props, prop) do
      updated_element = Map.put(element, "props", Map.put(props, prop, value))
      {:ok, spec |> Map.put("elements", Map.put(elements, id, updated_element))}
    else
      {:error, [path_not_found(path)]}
    end
  end

  defp apply_children_entry_operation(spec, elements, element, children, id, "-", %{
         op: "add",
         path: path,
         value: value
       }) do
    with {:ok, child_id} <- normalize_child_id(path, value) do
      updated_element = Map.put(element, "children", children ++ [child_id])
      {:ok, spec |> Map.put("elements", Map.put(elements, id, updated_element))}
    end
  end

  defp apply_children_entry_operation(_spec, _elements, _element, _children, _id, "-", %{
         path: path
       }) do
    {:error, [invalid_array_index(path, "-")]}
  end

  defp apply_children_entry_operation(spec, elements, element, children, id, index_token, %{
         op: "add",
         path: path,
         value: value
       }) do
    with {:ok, index} <- decode_array_index(path, index_token),
         true <- index <= length(children) or {:error, [invalid_array_index(path, index_token)]},
         {:ok, child_id} <- normalize_child_id(path, value) do
      updated_children = List.insert_at(children, index, child_id)
      updated_element = Map.put(element, "children", updated_children)
      {:ok, spec |> Map.put("elements", Map.put(elements, id, updated_element))}
    end
  end

  defp apply_children_entry_operation(spec, elements, element, children, id, index_token, %{
         op: "remove",
         path: path
       }) do
    with {:ok, index} <- decode_array_index(path, index_token),
         true <- index < length(children) or {:error, [path_not_found(path)]} do
      updated_children = List.delete_at(children, index)
      updated_element = Map.put(element, "children", updated_children)
      {:ok, spec |> Map.put("elements", Map.put(elements, id, updated_element))}
    end
  end

  defp apply_children_entry_operation(spec, elements, element, children, id, index_token, %{
         op: "replace",
         path: path,
         value: value
       }) do
    with {:ok, index} <- decode_array_index(path, index_token),
         true <- index < length(children) or {:error, [path_not_found(path)]},
         {:ok, child_id} <- normalize_child_id(path, value) do
      updated_children = List.replace_at(children, index, child_id)
      updated_element = Map.put(element, "children", updated_children)
      {:ok, spec |> Map.put("elements", Map.put(elements, id, updated_element))}
    end
  end

  defp apply_object_member_operation(container, key, path, "add", normalize_fun, %{value: value}) do
    if Map.has_key?(container, key) do
      {:error, [path_exists(path)]}
    else
      with {:ok, normalized} <- normalize_fun.(value) do
        {:ok, Map.put(container, key, normalized)}
      end
    end
  end

  defp apply_object_member_operation(container, key, path, "remove", _normalize_fun, _operation) do
    if Map.has_key?(container, key) do
      {:ok, Map.delete(container, key)}
    else
      {:error, [path_not_found(path)]}
    end
  end

  defp apply_object_member_operation(container, key, path, "replace", normalize_fun, %{
         value: value
       }) do
    if Map.has_key?(container, key) do
      with {:ok, normalized} <- normalize_fun.(value) do
        {:ok, Map.put(container, key, normalized)}
      end
    else
      {:error, [path_not_found(path)]}
    end
  end

  defp update_element({:ok, updated_element}, spec, elements, id) do
    {:ok, spec |> Map.put("elements", Map.put(elements, id, updated_element))}
  end

  defp update_element({:error, _} = error, _spec, _elements, _id), do: error

  defp fetch_elements(spec, path), do: fetch_map_member(spec, "elements", path)
  defp fetch_element(elements, id, path), do: fetch_map_member(elements, id, path)

  defp fetch_map_member(container, key, path) when is_map(container) do
    case Map.fetch(container, key) do
      {:ok, value} when is_map(value) -> {:ok, value}
      {:ok, _value} -> {:error, [path_not_found(path)]}
      :error -> {:error, [path_not_found(path)]}
    end
  end

  defp fetch_map_member(_container, _key, path), do: {:error, [path_not_found(path)]}

  defp fetch_list_member(container, key, path) when is_map(container) do
    case Map.fetch(container, key) do
      {:ok, value} when is_list(value) -> {:ok, value}
      {:ok, _value} -> {:error, [path_not_found(path)]}
      :error -> {:error, [path_not_found(path)]}
    end
  end

  defp fetch_list_member(_container, _key, path), do: {:error, [path_not_found(path)]}

  defp normalize_root_value(_path, nil), do: {:ok, nil}
  defp normalize_root_value(path, value), do: normalize_scalar_string(path, value)

  defp normalize_elements_value(path, elements) when is_map(elements) do
    elements
    |> Enum.reduce_while({:ok, %{}}, fn {id, element}, {:ok, acc} ->
      with {:ok, normalized_id} <- normalize_scalar_string(path, id),
           {:ok, normalized_element} <- normalize_element_value(path, element) do
        {:cont, {:ok, Map.put(acc, normalized_id, normalized_element)}}
      else
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp normalize_elements_value(path, _elements),
    do: {:error, [invalid_value(path, "must be a map of canonical elements")]}

  defp normalize_element_value(path, element) when is_map(element) do
    with {:ok, type} <-
           fetch_required_member(element, :type, "type", path, &normalize_type_value(path, &1)),
         {:ok, props} <-
           fetch_required_member(element, :props, "props", path, &normalize_props_value(path, &1)),
         {:ok, children} <-
           fetch_required_member(
             element,
             :children,
             "children",
             path,
             &normalize_children_value(path, &1)
           ) do
      {:ok, %{"type" => type, "props" => props, "children" => children}}
    end
  end

  defp normalize_element_value(path, _element),
    do: {:error, [invalid_value(path, "must be a canonical element map")]}

  defp normalize_type_value(_path, value) when is_binary(value), do: {:ok, value}
  defp normalize_type_value(_path, value) when is_atom(value), do: {:ok, Atom.to_string(value)}

  defp normalize_type_value(path, _value),
    do: {:error, [invalid_value(path, "must have a string `type`")]}

  defp normalize_props_value(_path, value) when is_map(value),
    do: {:ok, Normalizer.normalize_props(value)}

  defp normalize_props_value(path, _value), do: {:error, [invalid_value(path, "must be a map")]}

  defp normalize_children_value(path, value) when is_list(value) do
    value
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {child, index}, {:ok, acc} ->
      child_path = path <> "/#{index}"

      case normalize_child_id(child_path, child) do
        {:ok, child_id} -> {:cont, {:ok, [child_id | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, children} -> {:ok, Enum.reverse(children)}
      {:error, _} = error -> error
    end
  end

  defp normalize_children_value(path, _value),
    do: {:error, [invalid_value(path, "must be a list of child ids")]}

  defp normalize_child_id(path, value), do: normalize_scalar_string(path, value)

  defp normalize_scalar_string(_path, value)
       when is_binary(value) or is_atom(value) or is_integer(value) or is_float(value) or
              is_boolean(value) do
    {:ok, Normalizer.safe_to_string(value)}
  end

  defp normalize_scalar_string(path, _value),
    do: {:error, [invalid_value(path, "must be a scalar id or string value")]}

  defp fetch_required_member(container, atom_key, string_key, path, normalize_fun) do
    case fetch_key(container, atom_key, string_key) do
      {:ok, value} -> normalize_fun.(value)
      :error -> {:error, [invalid_value(path, "must include #{inspect(string_key)}")]}
    end
  end

  defp decode_pointer(""), do: {:ok, []}

  defp decode_pointer(path) when is_binary(path) do
    if String.starts_with?(path, "/") do
      path
      |> String.split("/", trim: false)
      |> tl()
      |> Enum.reduce_while({:ok, []}, fn token, {:ok, acc} ->
        case decode_pointer_token(token) do
          {:ok, decoded} -> {:cont, {:ok, [decoded | acc]}}
          {:error, _} = error -> {:halt, error}
        end
      end)
      |> case do
        {:ok, tokens} -> {:ok, Enum.reverse(tokens)}
        {:error, _} = error -> error
      end
    else
      {:error, [invalid_pointer(path)]}
    end
  end

  defp decode_pointer(_path), do: {:error, [invalid_pointer("non-string path")]}

  defp decode_pointer_token(token), do: decode_pointer_token(token, "")

  defp decode_pointer_token(<<"~0", rest::binary>>, acc),
    do: decode_pointer_token(rest, acc <> "~")

  defp decode_pointer_token(<<"~1", rest::binary>>, acc),
    do: decode_pointer_token(rest, acc <> "/")

  defp decode_pointer_token(<<"~", _rest::binary>>, _acc), do: {:error, [invalid_pointer("~")]}

  defp decode_pointer_token(<<char::utf8, rest::binary>>, acc),
    do: decode_pointer_token(rest, acc <> <<char::utf8>>)

  defp decode_pointer_token(<<>>, acc), do: {:ok, acc}

  defp decode_array_index(path, token) do
    if String.match?(token, ~r/^(0|[1-9]\d*)$/) do
      {:ok, String.to_integer(token)}
    else
      {:error, [invalid_array_index(path, token)]}
    end
  end

  defp fetch_key(container, atom_key, string_key) do
    cond do
      is_map(container) and Map.has_key?(container, atom_key) ->
        {:ok, Map.get(container, atom_key)}

      is_map(container) and Map.has_key?(container, string_key) ->
        {:ok, Map.get(container, string_key)}

      true ->
        :error
    end
  end

  defp value_present?(operation) do
    (is_map(operation) and Map.has_key?(operation, :value)) or
      (is_map(operation) and Map.has_key?(operation, "value"))
  end

  defp fetch_value(operation) do
    case fetch_key(operation, :value, "value") do
      {:ok, value} -> value
      :error -> nil
    end
  end

  defp invalid_patch(message), do: {:invalid_patch, message}

  defp invalid_patch_operation(index, message) do
    {:invalid_patch_operation, "JSON Patch operation #{index} #{message}"}
  end

  defp unsupported_operation(op) do
    {:unsupported_patch_operation, "JSON Patch operation #{inspect(op)} is not supported"}
  end

  defp unsupported_path(path) do
    {:unsupported_patch_path, "JSON Patch path #{inspect(path)} is not supported"}
  end

  defp invalid_pointer(path) do
    {:invalid_patch_path, "JSON Pointer #{inspect(path)} is invalid"}
  end

  defp path_not_found(path) do
    {:patch_path_not_found, "JSON Patch path #{inspect(path)} was not found"}
  end

  defp path_exists(path) do
    {:patch_path_exists, "JSON Patch path #{inspect(path)} already exists; use `replace` instead"}
  end

  defp invalid_array_index(path, index) do
    {:invalid_patch_index,
     "JSON Patch path #{inspect(path)} has invalid array index #{inspect(index)}"}
  end

  defp invalid_value(path, message) do
    {:invalid_patch_value, "JSON Patch path #{inspect(path)} #{message}"}
  end
end
