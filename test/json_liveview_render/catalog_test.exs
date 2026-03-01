defmodule JsonLiveviewRender.CatalogTest do
  use ExUnit.Case, async: true

  doctest JsonLiveviewRender.Catalog

  alias JsonLiveviewRender.Catalog, as: CatalogAPI
  alias JsonLiveviewRenderTest.Fixtures.Catalog

  test "exposes introspection APIs" do
    components = Catalog.components()

    assert is_map(components)
    assert Map.has_key?(components, :metric)
    assert Map.has_key?(components, :row)
    assert Catalog.has_component?(:metric)
    assert Catalog.has_component?("metric")

    assert Catalog.component(:metric).name == :metric
    assert Catalog.component("metric").name == :metric
    refute Catalog.has_component?(:does_not_exist)
    assert Catalog.exists?(:metric)
    assert :metric in Catalog.types()
    assert {:ok, props} = Catalog.props_for(:metric)
    assert Map.has_key?(props, :label)
  end

  test "module-level catalog helpers provide introspection for any catalog module" do
    assert :metric in CatalogAPI.types(Catalog)
    assert CatalogAPI.exists?(Catalog, "metric")
    assert {:ok, props} = CatalogAPI.props_for(Catalog, :metric)
    assert Map.has_key?(props, :value)
    assert :error = CatalogAPI.props_for(Catalog, :missing)
  end

  test "includes built-in primitives by default" do
    for primitive <- [:row, :column, :section, :grid] do
      assert Catalog.has_component?(primitive)
    end
  end

  test "raises for enum prop without values" do
    code = """
    defmodule JsonLiveviewRenderTest.BadEnumCatalog do
      use JsonLiveviewRender.Catalog

      component :broken do
        prop :status, :enum
      end
    end
    """

    assert_raise ArgumentError, ~r/enum prop type requires non-empty :values option/, fn ->
      Code.compile_string(code)
    end
  end

  test "raises for custom prop without validator" do
    code = """
    defmodule JsonLiveviewRenderTest.BadCustomCatalog do
      use JsonLiveviewRender.Catalog

      component :broken do
        prop :x, :custom
      end
    end
    """

    assert_raise ArgumentError, ~r/custom prop type requires :validator option/, fn ->
      Code.compile_string(code)
    end
  end
end
