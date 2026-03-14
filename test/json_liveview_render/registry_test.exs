defmodule JsonLiveviewRender.RegistryTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Registry
  alias JsonLiveviewRenderTest.Fixtures.Registry, as: FixtureRegistry

  test "fetch! returns mapped callback" do
    callback = Registry.fetch!(FixtureRegistry, :metric)
    assert is_function(callback, 1)
  end

  test "fetch! supports string component types" do
    callback = Registry.fetch!(FixtureRegistry, "metric")
    assert is_function(callback, 1)
  end

  test "has_mapping?/2 supports atom and string types" do
    assert Registry.has_mapping?(FixtureRegistry, :metric)
    assert Registry.has_mapping?(FixtureRegistry, "metric")
    refute Registry.has_mapping?(FixtureRegistry, :unknown)
  end

  test "fetch! raises for missing mapping" do
    assert_raise ArgumentError, ~r/missing registry mapping/, fn ->
      Registry.fetch!(FixtureRegistry, :unknown)
    end
  end

  test "compile-time error when registry maps unknown catalog types" do
    assert_raise CompileError, ~r/maps unknown component types/, fn ->
      Code.compile_string("""
      defmodule JsonLiveviewRenderTest.ErrorRegistry do
        use JsonLiveviewRender.Registry, catalog: JsonLiveviewRenderTest.Fixtures.Catalog
        render :unknown_component, &Function.identity/1
      end
      """)
    end
  end

  test "compile error includes available types in message" do
    error =
      assert_raise CompileError, fn ->
        Code.compile_string("""
        defmodule JsonLiveviewRenderTest.DetailedErrorRegistry do
          use JsonLiveviewRender.Registry, catalog: JsonLiveviewRenderTest.Fixtures.Catalog
          render :nonexistent_type, &Function.identity/1
        end
        """)
      end

    # Should mention the unknown type
    assert error.description =~ ":nonexistent_type"
    # Should include available types
    assert error.description =~ "Available types:"
    assert error.description =~ ":metric"
    assert error.description =~ ":data_table"
  end

  test "valid registry with known types compiles successfully" do
    # Should not raise
    Code.compile_string("""
    defmodule JsonLiveviewRenderTest.ValidRegistry do
      use JsonLiveviewRender.Registry, catalog: JsonLiveviewRenderTest.Fixtures.Catalog
      render :metric, &Function.identity/1
      render :data_table, &Function.identity/1
    end
    """)
  end

  test "duplicate render mappings preserve last mapping semantics" do
    Code.compile_string("""
    defmodule JsonLiveviewRenderTest.DuplicateRegistryCallbacks do
      def first(assigns), do: Map.put(assigns, :marker, :first)
      def second(assigns), do: Map.put(assigns, :marker, :second)
    end

    defmodule JsonLiveviewRenderTest.DuplicateRegistry do
      use JsonLiveviewRender.Registry, catalog: JsonLiveviewRenderTest.Fixtures.Catalog

      alias JsonLiveviewRenderTest.DuplicateRegistryCallbacks, as: Callbacks

      render :metric, &Callbacks.first/1
      render :metric, &Callbacks.second/1
    end
    """)

    callback = Registry.fetch!(JsonLiveviewRenderTest.DuplicateRegistry, :metric)

    assert callback.(%{}) == %{marker: :second}
    assert Registry.has_mapping?(JsonLiveviewRenderTest.DuplicateRegistry, "metric")
  end
end
