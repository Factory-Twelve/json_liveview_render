defmodule JsonLiveviewRender.Companion.ChatCards.Sender do
  @moduledoc """
  Optional synchronous sender behavior for companion chat-card targets.

  Implementations are app-owned and are called only by
  `JsonLiveviewRender.Companion.ChatCards.compile_and_send/2`.
  """

  @typedoc "Delivery targets supported by sender hooks."
  @type target :: :slack | :teams | :whatsapp

  @callback deliver(target(), map(), map()) :: {:ok, term()} | {:error, term()}
end
