defmodule JsonLiveviewRender.Companion.ChatCards.IR do
  @moduledoc """
  Internal normalized card intermediate representation shared by all target renderers.
  """

  @typedoc "Normalized action in the companion IR."
  @type action :: %{
          required(:action_id) => String.t(),
          required(:label) => String.t(),
          required(:style) => String.t(),
          required(:metadata) => map()
        }

  @typedoc "Normalized fact row in the companion IR."
  @type fact :: %{required(:label) => String.t(), required(:value) => String.t()}

  @typedoc "Normalized card payload used by all target renderers."
  @type t :: %{
          required(:card_id) => String.t(),
          required(:title) => String.t(),
          required(:severity) => String.t() | nil,
          required(:body_lines) => [String.t()],
          required(:facts) => [fact()],
          required(:actions) => [action()],
          required(:filtered_spec) => map()
        }

  @doc false
  @spec new(String.t(), map()) :: t()
  def new(card_id, filtered_spec) when is_binary(card_id) and is_map(filtered_spec) do
    %{
      card_id: card_id,
      title: card_id,
      severity: nil,
      body_lines: [],
      facts: [],
      actions: [],
      filtered_spec: filtered_spec
    }
  end

  @doc false
  @spec message_text(t()) :: String.t()
  def message_text(ir) do
    cond do
      ir.title != "" and ir.body_lines == [] -> ir.title
      ir.title == "" and ir.body_lines != [] -> Enum.join(ir.body_lines, "\n")
      ir.title == "" -> "Card update"
      true -> ir.title <> "\n\n" <> Enum.join(ir.body_lines, "\n")
    end
  end

  @doc false
  @spec fact_lines(t()) :: [String.t()]
  def fact_lines(ir) do
    Enum.map(ir.facts, fn %{label: label, value: value} -> "#{label}: #{value}" end)
  end
end
