defmodule JsonLiveviewRender.Test.GeneratorsTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Test.Generators

  test "valid_linear_spec/1 emits root + elements flat specs" do
    spec = Generators.valid_linear_spec(min_len: 3, max_len: 3) |> Enum.take(1) |> hd()

    assert is_map(spec)
    assert spec["root"] == "n_0"
    assert is_map(spec["elements"])
    assert map_size(spec["elements"]) == 3
  end

  test "cyclic_linear_spec/1 emits graphs with a cycle back to root" do
    spec = Generators.cyclic_linear_spec(min_len: 3, max_len: 3) |> Enum.take(1) |> hd()
    last_id = "n_2"
    children = get_in(spec, ["elements", last_id, "children"])
    assert "n_0" in children
  end
end
