defmodule JsonLiveviewRender.Test.Generators do
  @moduledoc "Reusable StreamData generators for JsonLiveviewRender test fixtures."

  import StreamData

  @spec valid_linear_spec(keyword()) :: StreamData.t()
  def valid_linear_spec(opts \\ []) do
    min_len = Keyword.get(opts, :min_len, 1)
    max_len = Keyword.get(opts, :max_len, 20)

    integer(min_len..max_len)
    |> map(&build_linear_chain_spec/1)
  end

  @spec cyclic_linear_spec(keyword()) :: StreamData.t()
  def cyclic_linear_spec(opts \\ []) do
    min_len = Keyword.get(opts, :min_len, 2)
    max_len = Keyword.get(opts, :max_len, 20)

    integer(min_len..max_len)
    |> map(&build_cyclic_linear_chain_spec/1)
  end

  defp build_cyclic_linear_chain_spec(len) do
    build_linear_chain_spec(len)
    |> update_in(["elements", "n_#{len - 1}", "children"], fn children ->
      ["n_0" | children]
    end)
  end

  defp build_linear_chain_spec(len) do
    elements =
      0..(len - 1)
      |> Enum.map(fn idx ->
        id = "n_#{idx}"

        next_children =
          if idx == len - 1 do
            []
          else
            ["n_#{idx + 1}"]
          end

        type = if idx == 0, do: "row", else: "metric"

        props =
          if type == "row" do
            %{"gap" => "md"}
          else
            %{"label" => "L#{idx}", "value" => Integer.to_string(idx)}
          end

        {id, %{"type" => type, "props" => props, "children" => next_children}}
      end)
      |> Map.new()

    %{"root" => "n_0", "elements" => elements}
  end
end
