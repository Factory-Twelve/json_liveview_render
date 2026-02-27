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
end
