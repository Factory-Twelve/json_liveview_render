defmodule JsonLiveviewRender.BindingsTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Bindings
  alias JsonLiveviewRender.Bindings.Error
  alias JsonLiveviewRenderTest.Fixtures.Catalog

  test "resolves *_binding keys and strips suffix" do
    props = %{"rows_binding" => "rows", "label" => "Revenue"}
    bindings = %{"rows" => [1, 2, 3]}

    assert Bindings.resolve_props(props, bindings) == %{"rows" => [1, 2, 3], "label" => "Revenue"}
  end

  test "supports atom binding keys in assigns" do
    props = %{"rows_binding" => "rows"}
    bindings = %{rows: [1]}

    assert Bindings.resolve_props(props, bindings) == %{"rows" => [1]}
  end

  test "raises when binding key is missing" do
    assert_raise Error, ~r/missing binding/, fn ->
      Bindings.resolve_props(%{"rows_binding" => "missing"}, %{})
    end
  end

  test "optional type checks validate resolved binding values" do
    {:ok, prop_defs} = Catalog.props_for(:data_table)

    assert Bindings.resolve_props(
             %{"rows_binding" => "rows"},
             %{"rows" => [%{"id" => 1}]},
             check_types: true,
             prop_defs: prop_defs
           ) == %{"rows" => [%{"id" => 1}]}
  end

  test "optional type checks raise deterministic type errors" do
    {:ok, prop_defs} = Catalog.props_for(:data_table)

    assert_raise Error, ~r/invalid type/, fn ->
      Bindings.resolve_props(
        %{"rows_binding" => "rows"},
        %{"rows" => ["not a map"]},
        check_types: true,
        prop_defs: prop_defs
      )
    end
  end
end
