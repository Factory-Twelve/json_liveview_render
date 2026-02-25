defmodule JsonLiveviewRender.PermissionsTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Permissions
  alias JsonLiveviewRenderTest.Fixtures.Authorizer
  alias JsonLiveviewRenderTest.Fixtures.Catalog

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
end
