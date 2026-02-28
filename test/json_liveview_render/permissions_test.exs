defmodule JsonLiveviewRender.PermissionsTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Permissions
  alias JsonLiveviewRenderTest.Fixtures.Authorizer
  alias JsonLiveviewRenderTest.Fixtures.Catalog

  defmodule BadAuthorizer do
    @behaviour JsonLiveviewRender.Authorizer

    @impl true
    def allowed?(_current_user, _required_role), do: :ok
  end

  defmodule PolicyAuthorizer do
    @behaviour JsonLiveviewRender.Authorizer

    @impl true
    def allowed?(current_user, required_role) when is_map(current_user) do
      required_role_key = role_key(required_role)

      current_roles =
        current_user |> Map.get(:roles, Map.get(current_user, "roles", [])) |> List.wrap()

      normalized_roles =
        current_roles
        |> Enum.map(&role_key/1)
        |> Enum.reject(&is_nil/1)

      required_role_key in normalized_roles
    end

    defp role_key(role) when is_atom(role), do: Atom.to_string(role)
    defp role_key(role) when is_binary(role), do: role
    defp role_key(_), do: nil
  end

  defmodule PermissionCompositionCatalog do
    use JsonLiveviewRender.Catalog

    component :admin_container do
      description("Container requiring admin")
      permission(:admin)
    end

    component :member_only do
      description("Requires member")
      permission(:member)
    end

    component :member_or_admin do
      description("Requires member or admin")
      permission([:member, :admin])
    end

    component :admin_and_member do
      description("Requires admin and member")
      permission(%{all_of: [:admin, :member]})
    end

    component :member_with_deny do
      description("Allows member but denies disabled")
      permission(%{any_of: [:member], deny: [:disabled]})
    end
  end

  defmodule InvalidPermissionCatalog do
    use JsonLiveviewRender.Catalog

    component :broken_any_of do
      description("Invalid policy map")
      permission(%{any_of: :member})
    end

    component :invalid_role do
      description("Invalid role type")
      permission(["member", 1])
    end
  end

  test "filters unauthorized elements and child refs" do
    spec = %{
      "root" => "page",
      "elements" => %{
        "page" => %{"type" => "row", "props" => %{}, "children" => ["metric_1", "admin_1"]},
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "A", "value" => "1"},
          "children" => []
        },
        "admin_1" => %{
          "type" => "admin_panel",
          "props" => %{"title" => "Top Secret"},
          "children" => []
        }
      }
    }

    filtered = Permissions.filter(spec, %{role: :member}, Catalog, Authorizer)

    assert Map.has_key?(filtered["elements"], "metric_1")
    refute Map.has_key?(filtered["elements"], "admin_1")
    assert get_in(filtered, ["elements", "page", "children"]) == ["metric_1"]
  end

  test "supports list shorthand required roles using any_of semantics" do
    spec = %{
      "root" => "parent",
      "elements" => %{
        "parent" => %{
          "type" => "admin_container",
          "props" => %{},
          "children" => ["member_or_admin"]
        },
        "member_or_admin" => %{"type" => "member_or_admin", "props" => %{}, "children" => []}
      }
    }

    filtered =
      Permissions.filter(
        spec,
        %{roles: :admin},
        PermissionCompositionCatalog,
        PolicyAuthorizer
      )

    assert Map.has_key?(filtered["elements"], "member_or_admin")
  end

  test "supports all_of policy with inherited roles from current_user" do
    spec = %{
      "root" => "parent",
      "elements" => %{
        "parent" => %{
          "type" => "admin_container",
          "props" => %{},
          "children" => ["admin_and_member"]
        },
        "admin_and_member" => %{
          "type" => "admin_and_member",
          "props" => %{},
          "children" => []
        }
      }
    }

    current_user = %{roles: :admin, role_inheritance: %{admin: [:member]}}

    filtered =
      Permissions.filter(
        spec,
        current_user,
        PermissionCompositionCatalog,
        PolicyAuthorizer
      )

    assert Map.has_key?(filtered["elements"], "admin_and_member")
  end

  test "applies deny rules before allow rules" do
    spec = %{
      "root" => "parent",
      "elements" => %{
        "parent" => %{
          "type" => "admin_container",
          "props" => %{},
          "children" => ["member_with_deny"]
        },
        "member_with_deny" => %{
          "type" => "member_with_deny",
          "props" => %{},
          "children" => []
        }
      }
    }

    filtered =
      Permissions.filter(
        spec,
        %{roles: [:member, :disabled]},
        PermissionCompositionCatalog,
        PolicyAuthorizer
      )

    refute Map.has_key?(filtered["elements"], "member_with_deny")
  end

  test "does not let parent permission leak into child unless child policy matches user context" do
    spec = %{
      "root" => "parent",
      "elements" => %{
        "parent" => %{"type" => "admin_container", "props" => %{}, "children" => ["member_only"]},
        "member_only" => %{
          "type" => "member_only",
          "props" => %{},
          "children" => []
        }
      }
    }

    filtered_without_inheritance =
      Permissions.filter(
        spec,
        %{roles: :admin},
        PermissionCompositionCatalog,
        PolicyAuthorizer
      )

    assert Map.has_key?(filtered_without_inheritance["elements"], "parent")
    refute Map.has_key?(filtered_without_inheritance["elements"], "member_only")

    filtered_with_inheritance =
      Permissions.filter(
        spec,
        %{roles: :admin, role_inheritance: %{admin: [:member]}},
        PermissionCompositionCatalog,
        PolicyAuthorizer
      )

    assert Map.has_key?(filtered_with_inheritance["elements"], "member_only")
  end

  test "raises when authorizer returns non-boolean" do
    spec = %{
      "root" => "admin_1",
      "elements" => %{
        "admin_1" => %{
          "type" => "admin_panel",
          "props" => %{"title" => "Top Secret"},
          "children" => []
        }
      }
    }

    assert_raise ArgumentError, ~r/must return boolean/, fn ->
      Permissions.filter(spec, %{role: :member}, Catalog, BadAuthorizer)
    end
  end

  test "raises explicit errors for malformed permission declarations" do
    spec = %{
      "root" => "broken",
      "elements" => %{
        "broken" => %{"type" => "broken_any_of", "props" => %{}, "children" => []}
      }
    }

    assert_raise ArgumentError, ~r/invalid permission policy in catalog component/, fn ->
      Permissions.filter(spec, %{roles: :member}, InvalidPermissionCatalog, Authorizer)
    end
  end

  test "raises explicit errors for malformed role lists" do
    spec = %{
      "root" => "broken",
      "elements" => %{
        "broken" => %{"type" => "invalid_role", "props" => %{}, "children" => []}
      }
    }

    assert_raise ArgumentError, ~r/expected atom or string role/, fn ->
      Permissions.filter(spec, %{roles: :member}, InvalidPermissionCatalog, Authorizer)
    end
  end
end
