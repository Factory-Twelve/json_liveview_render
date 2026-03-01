defmodule JsonLiveviewRender.Companion.ChatCards.Warnings do
  @moduledoc """
  Internal helpers for building structured companion warning payloads.
  """

  alias JsonLiveviewRender.Companion.ChatCards.Target

  @typedoc "Structured warning emitted during bridge/render/delivery processing."
  @type t :: Target.warning()

  @doc false
  @spec new(atom(), Target.t() | :bridge | :delivery, [String.t()], String.t()) :: t()
  def new(code, target, path, message), do: new(code, target, path, message, %{})

  @doc false
  @spec new(atom(), Target.t() | :bridge | :delivery, [String.t()], String.t(), map()) :: t()
  def new(code, target, path, message, meta)
      when is_atom(code) and is_list(path) and is_binary(message) and is_map(meta) do
    %{code: code, target: target, path: path, message: message, meta: meta}
  end
end
