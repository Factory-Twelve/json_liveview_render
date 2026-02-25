defmodule JsonLiveviewRender.RegistryTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias JsonLiveviewRender.Registry
  alias JsonLiveviewRenderTest.Fixtures.Registry, as: FixtureRegistry

  test "fetch! returns mapped callback" do
    callback = Registry.fetch!(FixtureRegistry, :metric)
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

  test "compile-time warns when registry maps unknown catalog types" do
    warning =
      capture_io(:stderr, fn ->
        Code.compile_string("""
        defmodule JsonLiveviewRenderTest.WarnRegistry do
          use JsonLiveviewRender.Registry, catalog: JsonLiveviewRenderTest.Fixtures.Catalog
          render :unknown_component, &Function.identity/1
        end
        """)
      end)

    assert warning =~ "maps unknown component types"
  end
end
