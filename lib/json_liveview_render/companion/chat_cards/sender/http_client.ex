defmodule JsonLiveviewRender.Companion.ChatCards.Sender.HTTPClient do
  @moduledoc """
  Transport behavior used by companion HTTP sender implementations.

  The default implementation uses `:httpc`, but tests can inject a custom
  implementation through sender context.
  """

  @typedoc "HTTP response envelope consumed by sender adapters."
  @type response :: %{required(:status) => non_neg_integer(), required(:body) => String.t()}

  @typedoc "HTTP request headers as `{name, value}` tuples."
  @type headers :: [{String.t(), String.t()}]

  @callback post(String.t(), headers(), String.t(), keyword()) ::
              {:ok, response()} | {:error, term()}
end
