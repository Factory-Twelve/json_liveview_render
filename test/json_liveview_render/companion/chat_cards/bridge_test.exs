defmodule JsonLiveviewRender.Companion.ChatCards.BridgeTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Companion.ChatCards.Bridge

  test "unknown components degrade to fallback text with warning" do
    spec = %{
      "root" => "root",
      "elements" => %{
        "root" => %{
          "type" => "card",
          "props" => %{"title" => "Root"},
          "children" => ["unknown_leaf"]
        },
        "unknown_leaf" => %{
          "type" => "mystery_widget",
          "props" => %{"note" => "hello"},
          "children" => []
        }
      }
    }

    assert {:ok, ir, warnings} = Bridge.to_ir(spec)

    assert Enum.any?(ir.body_lines, &String.contains?(&1, "mystery_widget"))
    assert Enum.any?(warnings, &(&1.code == :unknown_leaf_type))
  end
end
