defmodule JsonLiveviewRender.Companion.ChatCards.Sender.HTTPClient.Default do
  @moduledoc """
  Default HTTP transport for companion sender adapters.
  """

  @behaviour JsonLiveviewRender.Companion.ChatCards.Sender.HTTPClient

  @doc false
  @impl true
  @spec post(String.t(), [{String.t(), String.t()}], String.t(), keyword()) ::
          {:ok, %{status: non_neg_integer(), body: String.t()}} | {:error, term()}
  def post(url, headers, body, opts) do
    :inets.start()
    Application.ensure_all_started(:ssl)

    timeout = Keyword.get(opts, :timeout, 5_000)
    ssl_options = Keyword.get(opts, :ssl, [])

    request =
      {to_charlist(url), to_charlist_headers(headers), ~c"application/json", body}

    http_options =
      case url do
        "https://" <> _rest -> [{:timeout, timeout}, {:ssl, ssl_options}]
        _ -> [{:timeout, timeout}]
      end

    case :httpc.request(:post, request, http_options, []) do
      {:ok, {{_http_version, status, _reason_phrase}, _response_headers, response_body}} ->
        {:ok, %{status: status, body: to_string(response_body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp to_charlist_headers(headers) do
    Enum.map(headers, fn {name, value} -> {to_charlist(name), to_charlist(value)} end)
  end
end
