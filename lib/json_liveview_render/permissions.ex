defmodule JsonLiveviewRender.Permissions do
  @moduledoc """
  Permission filtering contract for `JsonLiveviewRender` specs.

  API scope:

  - Stability: v0.2 core contract
  - Included in the v0.3 package scope lock

  Delegates visibility decisions to an app-provided authorization function or callback
  and removes unauthorized elements before invoking component rendering.
  """

  alias JsonLiveviewRender.Catalog.ComponentDef

  @type normalized_policy :: %{
          required_mode: :any_of | :all_of,
          required_roles: [term()],
          deny_roles: [term()]
        }

  @spec filter(map(), term(), module(), module() | (term(), term() -> boolean())) :: map()
  def filter(%{"root" => root, "elements" => elements} = spec, current_user, catalog, authorizer)
      when is_map(elements) do
    user_role_keys = inherited_role_keys(current_user)

    allowed_ids =
      elements
      |> Enum.filter(fn {_id, element} ->
        allowed_element?(element, catalog, current_user, authorizer, user_role_keys)
      end)
      |> Enum.map(fn {id, _} -> id end)
      |> MapSet.new()

    filtered_elements =
      elements
      |> Enum.filter(fn {id, _} -> MapSet.member?(allowed_ids, id) end)
      |> Enum.into(%{}, fn {id, element} ->
        children =
          Map.get(element, "children", [])
          |> Enum.filter(&MapSet.member?(allowed_ids, &1))

        {id, Map.put(element, "children", children)}
      end)

    spec
    |> Map.put("root", root)
    |> Map.put("elements", filtered_elements)
  end

  def filter(spec, _current_user, _catalog, _authorizer), do: spec

  defp allowed_element?(%{"type" => type}, catalog, current_user, authorizer, user_role_keys) do
    case catalog.component(type) do
      %ComponentDef{permission: nil} ->
        true

      %ComponentDef{permission: required_role} ->
        required_role
        |> normalize_required_role!()
        |> allowed_by_policy?(user_role_keys, current_user, authorizer)

      nil ->
        false
    end
  end

  defp allowed_element?(_element, _catalog, _current_user, _authorizer, _user_role_keys),
    do: false

  defp allowed_by_policy?(
         %{required_mode: mode, required_roles: required_roles, deny_roles: deny_roles},
         user_role_keys,
         current_user,
         authorizer
       ) do
    if Enum.any?(deny_roles, &role_granted?(user_role_keys, current_user, authorizer, &1)) do
      false
    else
      case mode do
        :all_of ->
          Enum.all?(required_roles, &role_granted?(user_role_keys, current_user, authorizer, &1))

        :any_of ->
          Enum.any?(required_roles, &role_granted?(user_role_keys, current_user, authorizer, &1))
      end
    end
  end

  defp role_granted?(user_role_keys, current_user, authorizer, role) do
    role_key = role_key(role)

    if role_key in user_role_keys do
      true
    else
      allowed?(authorizer, current_user, role)
    end
  end

  defp normalize_required_role!(required_role) when is_atom(required_role),
    do: %{
      required_mode: :any_of,
      required_roles: [required_role],
      deny_roles: []
    }

  defp normalize_required_role!(required_role) when is_binary(required_role),
    do: %{
      required_mode: :any_of,
      required_roles: [required_role],
      deny_roles: []
    }

  defp normalize_required_role!(required_roles) when is_list(required_roles),
    do: %{
      required_mode: :any_of,
      required_roles: normalize_role_list!(required_roles, "permission list"),
      deny_roles: []
    }

  defp normalize_required_role!(required_role) when is_map(required_role) do
    unsupported_keys = Map.keys(required_role) -- [:any_of, :all_of, :deny]

    if unsupported_keys != [] do
      raise ArgumentError,
            "invalid permission policy in catalog component: unsupported keys #{inspect(unsupported_keys)}"
    end

    cond do
      Map.has_key?(required_role, :any_of) && Map.has_key?(required_role, :all_of) ->
        raise ArgumentError,
              "invalid permission policy in catalog component: cannot include both :any_of and :all_of"

      Map.has_key?(required_role, :all_of) ->
        required_roles =
          normalize_policy_roles!(Map.get(required_role, :all_of), "permission policy")

        %{
          required_mode: :all_of,
          required_roles: required_roles,
          deny_roles:
            normalize_deny_list!(Map.get(required_role, :deny, []))
        }

      Map.has_key?(required_role, :any_of) ->
        required_roles =
          normalize_policy_roles!(Map.get(required_role, :any_of), "permission policy")

        %{
          required_mode: :any_of,
          required_roles: required_roles,
          deny_roles:
            normalize_deny_list!(Map.get(required_role, :deny, []))
        }

      true ->
        raise ArgumentError,
              "invalid permission policy in catalog component: expected :any_of or :all_of keys when policy is a map"
    end
  end

  defp normalize_required_role!(_required_role) do
    raise ArgumentError, "invalid permission policy in catalog component"
  end

  defp normalize_role_list!(roles, policy_key) when is_list(roles) do
    if Enum.empty?(roles) do
      raise ArgumentError,
            "invalid permission #{policy_key} in catalog component: role list cannot be empty"
    end

    Enum.map(roles, fn role -> normalize_role!(role, policy_key) end)
  end

  defp normalize_role_list!(_roles, policy_key) do
    raise ArgumentError,
          "invalid permission #{policy_key} in catalog component: expected role list"
  end

  defp normalize_policy_roles!(roles, policy_key) when is_list(roles),
    do: normalize_role_list!(roles, policy_key)

  defp normalize_policy_roles!(_roles, _policy_key) do
    raise ArgumentError, "invalid permission policy in catalog component"
  end

  defp normalize_deny_list!(roles) when is_list(roles),
    do: Enum.map(roles, fn role -> normalize_role!(role, "permission deny list") end)

  defp normalize_deny_list!(_roles) do
    raise ArgumentError,
          "invalid permission permission deny list in catalog component: expected role list"
  end

  defp normalize_role!(role, _policy_key) when is_atom(role), do: role
  defp normalize_role!(role, _policy_key) when is_binary(role), do: role

  defp normalize_role!(role, policy_key) do
    raise ArgumentError,
          "invalid permission #{policy_key} in catalog component: expected atom or string role, got #{inspect(role)}"
  end

  defp allowed?(authorizer, current_user, required_role) when is_atom(authorizer) do
    authorizer
    |> apply(:allowed?, [current_user, required_role])
    |> normalize_authorizer_result!(authorizer)
  end

  defp allowed?(authorizer, current_user, required_role) when is_function(authorizer, 2) do
    authorizer
    |> Kernel.apply([current_user, required_role])
    |> normalize_authorizer_result!(authorizer)
  end

  defp normalize_authorizer_result!(result, _authorizer) when is_boolean(result), do: result

  defp normalize_authorizer_result!(result, authorizer) do
    raise ArgumentError,
          "authorizer #{inspect(authorizer)} must return boolean from allowed?/2, got: #{inspect(result)}"
  end

  defp inherited_role_keys(current_user) when is_map(current_user) do
    current_user
    |> declared_roles()
    |> expand_roles(inheritance_graph(current_user))
    |> Enum.map(&role_key!/1)
    |> MapSet.new()
  end

  defp inherited_role_keys(_current_user), do: MapSet.new()

  defp declared_roles(current_user) when is_map(current_user) do
    cond do
      is_list(Map.get(current_user, "roles")) ->
        Map.get(current_user, "roles")

      is_binary(Map.get(current_user, "roles")) || is_atom(Map.get(current_user, "roles")) ->
        [Map.get(current_user, "roles")]

      is_list(Map.get(current_user, :roles)) ->
        Map.get(current_user, :roles)

      is_binary(Map.get(current_user, :roles)) || is_atom(Map.get(current_user, :roles)) ->
        [Map.get(current_user, :roles)]

      is_binary(Map.get(current_user, :role)) || is_atom(Map.get(current_user, :role)) ->
        [Map.get(current_user, :role)]

      true ->
        []
    end
  end

  defp declared_roles(_current_user), do: []

  defp inheritance_graph(current_user) do
    case Map.get(current_user, :role_inheritance) || Map.get(current_user, "role_inheritance") do
      nil ->
        %{}

      inheritance ->
        normalize_role_inheritance(inheritance)
    end
  end

  defp normalize_role_inheritance(inheritance) when is_map(inheritance) do
    Enum.reduce(inheritance, %{}, fn {role, inherited_roles}, acc ->
      key = role_key(role)

      if is_nil(key) do
        acc
      else
        Map.put(acc, key, normalize_inherited_roles(inherited_roles))
      end
    end)
  end

  defp normalize_role_inheritance(_), do: %{}

  defp normalize_inherited_roles(inherited_roles) when is_list(inherited_roles) do
    inherited_roles
    |> Enum.map(&role_key/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_inherited_roles(inherited_roles), do: [role_key!(inherited_roles)]

  defp expand_roles(roles, inheritance_graph) do
    Enum.reduce(roles, [], fn role, acc ->
      do_expand_role(role_key(role), inheritance_graph, acc, MapSet.new())
    end)
  end

  defp do_expand_role(nil, _inheritance_graph, acc, _seen), do: acc

  defp do_expand_role(role_key, inheritance_graph, acc, seen) do
    if MapSet.member?(seen, role_key) do
      acc
    else
      next_seen = MapSet.put(seen, role_key)
      expanded = append_if_missing(acc, role_key)
      inherited = Map.get(inheritance_graph, role_key, [])

      Enum.reduce(inherited, expanded, fn inherited_role_key, seeded ->
        do_expand_role(inherited_role_key, inheritance_graph, seeded, next_seen)
      end)
    end
  end

  defp append_if_missing(acc, role_key) do
    if role_key in acc do
      acc
    else
      acc ++ [role_key]
    end
  end

  defp role_key(value) when is_atom(value), do: Atom.to_string(value)
  defp role_key(value) when is_binary(value), do: value
  defp role_key(_), do: nil

  defp role_key!(value) do
    case role_key(value) do
      nil -> raise ArgumentError, "invalid role in current_user for permission inheritance"
      key -> key
    end
  end
end
