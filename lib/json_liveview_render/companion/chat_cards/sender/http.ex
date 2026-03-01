defmodule JsonLiveviewRender.Companion.ChatCards.Sender.HTTP do
  @moduledoc """
  Concrete sender that delivers compiled chat-card payloads over HTTP.

  Supported targets and context keys:
  - `:slack` with `%{slack: %{bot_token: "...", channel: "..."} }`
  - `:teams` with `%{teams: %{webhook_url: "..."}}`
  - `:whatsapp` with `%{whatsapp: %{access_token: "...", phone_number_id: "...", to: "..."}}`

  Optional context keys:
  - `:http_client` custom module implementing
    `JsonLiveviewRender.Companion.ChatCards.Sender.HTTPClient`
  - `:slack.base_url`, `:whatsapp.graph_base_url`, `:whatsapp.api_version`
  - `:timeout` and per-target timeout overrides (`:slack.timeout`, etc.)
  - `:retry` and per-target `:retry` (`max_attempts`, `base_delay_ms`, `max_delay_ms`)
  - `:idempotency` and per-target idempotency (`idempotency_key`, `idempotency_header`)
  """

  @behaviour JsonLiveviewRender.Companion.ChatCards.Sender

  alias JsonLiveviewRender.Companion.ChatCards.Sender.HTTPClient.Default, as: DefaultHTTPClient

  @type target :: :slack | :teams | :whatsapp

  @doc """
  Delivers a compiled platform payload to the configured HTTP endpoint.

  ## Examples

      iex> JsonLiveviewRender.Companion.ChatCards.Sender.HTTP.deliver(:slack, %{"blocks" => []}, %{})
      {:error, {:missing_delivery_context, :slack}}

      iex> JsonLiveviewRender.Companion.ChatCards.Sender.HTTP.deliver(:unknown, %{}, %{})
      {:error, {:unsupported_target, :unknown}}
  """
  @impl true
  @spec deliver(target(), map(), map()) :: {:ok, term()} | {:error, term()}
  def deliver(target, payload, context) when target in [:slack, :teams, :whatsapp] do
    with {:ok, config} <- fetch_target_config(context, target),
         {:ok, request} <- build_request(target, payload, config, context),
         {:ok, response} <- execute_request(request, context, target, config) do
      normalize_platform_response(target, response)
    end
  end

  def deliver(target, _payload, _context), do: {:error, {:unsupported_target, target}}

  defp build_request(:slack, payload, config, context) do
    with {:ok, bot_token} <- fetch_required(config, :bot_token),
         {:ok, endpoint_url, request_body} <- slack_endpoint_and_body(payload, config, context) do
      {:ok,
       %{
         url: endpoint_url,
         headers:
           [{"authorization", "Bearer #{bot_token}"}, {"content-type", "application/json"}] ++
             idempotency_headers(config, context, :slack, payload),
         body: Jason.encode!(request_body),
         timeout: Map.get(config, :timeout)
       }}
    end
  end

  defp build_request(:teams, payload, config, context) do
    with {:ok, webhook_url} <- fetch_required(config, :webhook_url) do
      body = %{
        "type" => "message",
        "attachments" => [
          %{
            "contentType" => "application/vnd.microsoft.card.adaptive",
            "contentUrl" => nil,
            "content" => payload
          }
        ]
      }

      headers =
        [{"content-type", "application/json"}] ++
          normalize_headers(Map.get(config, :headers, %{})) ++
          idempotency_headers(config, context, :teams, payload)

      {:ok,
       %{
         url: webhook_url,
         headers: headers,
         body: Jason.encode!(body),
         timeout: Map.get(config, :timeout)
       }}
    end
  end

  defp build_request(:whatsapp, payload, config, context) do
    with {:ok, access_token} <- fetch_required(config, :access_token),
         {:ok, phone_number_id} <- fetch_required(config, :phone_number_id),
         {:ok, to} <- fetch_required(config, :to) do
      graph_base_url = Map.get(config, :graph_base_url, "https://graph.facebook.com")
      api_version = Map.get(config, :api_version, "v23.0")

      endpoint_url =
        "#{String.trim_trailing(graph_base_url, "/")}/#{api_version}/#{phone_number_id}/messages"

      body =
        payload
        |> Map.put("to", to)
        |> Map.put_new("messaging_product", "whatsapp")
        |> Map.put_new("recipient_type", "individual")

      {:ok,
       %{
         url: endpoint_url,
         headers:
           [
             {"authorization", "Bearer #{access_token}"},
             {"content-type", "application/json"}
           ] ++ idempotency_headers(config, context, :whatsapp, payload),
         body: Jason.encode!(body),
         timeout: Map.get(config, :timeout)
       }}
    end
  end

  defp slack_endpoint_and_body(payload, config, context) do
    base_url = Map.get(config, :base_url, "https://slack.com/api")

    case Map.get(payload, "type") do
      "home" ->
        with {:ok, user_id} <- fetch_required(config, :user_id) do
          {:ok, "#{String.trim_trailing(base_url, "/")}/views.publish",
           %{"user_id" => user_id, "view" => payload}}
        end

      "modal" ->
        with {:ok, trigger_id} <- fetch_required(config, :trigger_id) do
          {:ok, "#{String.trim_trailing(base_url, "/")}/views.open",
           %{"trigger_id" => trigger_id, "view" => payload}}
        end

      _ ->
        with {:ok, channel} <- fetch_required(config, :channel) do
          message_payload = with_slack_idempotency(payload, config, context)

          body =
            %{
              "channel" => channel,
              "text" => slack_fallback_text(payload),
              "blocks" => Map.get(message_payload, "blocks", [])
            }
            |> maybe_put_client_msg_id(message_payload)

          {:ok, "#{String.trim_trailing(base_url, "/")}/chat.postMessage", body}
        end
    end
  end

  defp execute_request(request, context, target, config) do
    client = resolve_http_client(context)
    retry = normalize_retry_config(Map.get(config, :retry) || Map.get(context, :retry, %{}))
    sleep_fn = resolve_sleep_fn(context)

    timeout =
      request.timeout ||
        context
        |> Map.get(:timeout, 5_000)

    execute_with_retry(client, request, target, timeout, retry, sleep_fn, 1)
  end

  defp normalize_platform_response(:slack, %{body: body}) do
    case decode_json(body) do
      {:ok, %{"ok" => true} = decoded} -> {:ok, decoded}
      {:ok, %{"ok" => false, "error" => error}} -> {:error, {:slack_api_error, error}}
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:ok, body}
    end
  end

  defp normalize_platform_response(:teams, %{body: body}) do
    case decode_json(body) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:ok, body}
    end
  end

  defp normalize_platform_response(:whatsapp, %{body: body}) do
    case decode_json(body) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:ok, body}
    end
  end

  defp resolve_http_client(context) do
    case Map.get(context, :http_client) do
      module when is_atom(module) ->
        if function_exported?(module, :post, 4), do: module, else: DefaultHTTPClient

      _ ->
        DefaultHTTPClient
    end
  end

  defp resolve_sleep_fn(context) do
    case Map.get(context, :sleep_fn) do
      sleep_fn when is_function(sleep_fn, 1) -> sleep_fn
      _ -> &:timer.sleep/1
    end
  end

  defp fetch_target_config(context, target) when is_map(context) do
    case Map.get(context, target) do
      %{} = config -> {:ok, config}
      _ -> {:error, {:missing_delivery_context, target}}
    end
  end

  defp fetch_target_config(_context, target), do: {:error, {:missing_delivery_context, target}}

  defp fetch_required(map, key) do
    case Map.get(map, key) do
      nil -> {:error, {:missing_required_field, key}}
      "" -> {:error, {:missing_required_field, key}}
      value -> {:ok, value}
    end
  end

  defp normalize_headers(map) when is_map(map) do
    Enum.map(map, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize_headers(_), do: []

  defp decode_json(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      _ -> :error
    end
  end

  defp decode_json(_), do: :error

  defp execute_with_retry(client, request, target, timeout, retry, sleep_fn, attempt) do
    case client.post(request.url, request.headers, request.body, timeout: timeout) do
      {:ok, %{status: status} = response} when status >= 200 and status < 300 ->
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        error = {:http_error, target, status, body}

        maybe_retry(
          error,
          attempt,
          retry.max_attempts,
          retryable_status?(status, retry.retry_statuses),
          retry_delay_ms(retry, attempt),
          sleep_fn,
          fn ->
            execute_with_retry(client, request, target, timeout, retry, sleep_fn, attempt + 1)
          end
        )

      {:error, reason} ->
        error = {:request_failed, target, reason}

        maybe_retry(
          error,
          attempt,
          retry.max_attempts,
          true,
          retry_delay_ms(retry, attempt),
          sleep_fn,
          fn ->
            execute_with_retry(client, request, target, timeout, retry, sleep_fn, attempt + 1)
          end
        )
    end
  end

  defp maybe_retry(_error, attempt, max_attempts, true, delay_ms, sleep_fn, retry_fun)
       when attempt < max_attempts do
    sleep_fn.(delay_ms)
    retry_fun.()
  end

  defp maybe_retry(error, _attempt, _max_attempts, _retryable?, _delay_ms, _sleep_fn, _retry_fun),
    do: {:error, error}

  defp normalize_retry_config(%{} = config) do
    %{
      max_attempts: positive_int(Map.get(config, :max_attempts), 1),
      base_delay_ms: non_negative_int(Map.get(config, :base_delay_ms), 150),
      max_delay_ms: positive_int(Map.get(config, :max_delay_ms), 2_000),
      multiplier: positive_number(Map.get(config, :multiplier), 2.0),
      retry_statuses: normalize_retry_statuses(Map.get(config, :retry_statuses))
    }
  end

  defp normalize_retry_config(_), do: normalize_retry_config(%{})

  defp normalize_retry_statuses(nil), do: default_retry_statuses()

  defp normalize_retry_statuses(list) when is_list(list) do
    list
    |> Enum.filter(&is_integer/1)
    |> Enum.filter(&(&1 >= 100 and &1 <= 599))
    |> Enum.uniq()
    |> case do
      [] -> default_retry_statuses()
      statuses -> statuses
    end
  end

  defp normalize_retry_statuses(_), do: default_retry_statuses()

  defp default_retry_statuses, do: [408, 409, 425, 429] ++ Enum.to_list(500..599)

  defp retryable_status?(status, retry_statuses), do: status in retry_statuses

  defp retry_delay_ms(retry, attempt) do
    exponent = max(attempt - 1, 0)
    scaled = retry.base_delay_ms * :math.pow(retry.multiplier, exponent)
    min(retry.max_delay_ms, trunc(Float.floor(scaled)))
  end

  defp idempotency_headers(config, context, target, payload) do
    case resolve_idempotency(config, context, target, payload) do
      nil -> []
      idempotency -> [{idempotency.header, idempotency.key}]
    end
  end

  defp with_slack_idempotency(payload, config, context) do
    case resolve_idempotency(config, context, :slack, payload) do
      nil -> payload
      idempotency -> Map.put(payload, "_idempotency_key", idempotency.key)
    end
  end

  defp maybe_put_client_msg_id(body, payload) do
    case Map.get(payload, "_idempotency_key") do
      nil ->
        body

      key ->
        Map.put(body, "client_msg_id", idempotency_uuid(key))
    end
  end

  defp resolve_idempotency(config, context, target, payload) do
    target_key = Map.get(config, :idempotency_key)
    target_header = Map.get(config, :idempotency_header)
    idempotency = Map.get(context, :idempotency, %{})
    enabled? = Map.get(idempotency, :enabled, false) or is_binary(target_key)

    if enabled? do
      header = target_header || Map.get(idempotency, :header, "x-idempotency-key")
      base_key = target_key || Map.get(idempotency, :key, "chat-cards-#{target}")
      digest = payload_digest(target, payload)
      %{header: to_string(header), key: "#{base_key}-#{digest}"}
    else
      nil
    end
  end

  defp payload_digest(target, payload) do
    encoded_payload = Jason.encode!(payload)

    :crypto.hash(:sha256, "#{target}|#{encoded_payload}")
    |> Base.encode16(case: :lower)
    |> binary_part(0, 32)
  end

  defp idempotency_uuid(key) do
    digest =
      :crypto.hash(:sha256, key)
      |> Base.encode16(case: :lower)
      |> binary_part(0, 32)

    [
      binary_part(digest, 0, 8),
      binary_part(digest, 8, 4),
      binary_part(digest, 12, 4),
      binary_part(digest, 16, 4),
      binary_part(digest, 20, 12)
    ]
    |> Enum.join("-")
  end

  defp positive_int(value, _default) when is_integer(value) and value > 0, do: value
  defp positive_int(_value, default), do: default

  defp non_negative_int(value, _default) when is_integer(value) and value >= 0, do: value
  defp non_negative_int(_value, default), do: default

  defp positive_number(value, _default) when is_integer(value) and value > 0, do: value * 1.0
  defp positive_number(value, _default) when is_float(value) and value > 0.0, do: value
  defp positive_number(_value, default), do: default

  defp slack_fallback_text(payload) do
    blocks = Map.get(payload, "blocks", [])

    header =
      Enum.find_value(blocks, "", fn
        %{"type" => "header", "text" => %{"text" => text}} -> text
        _ -> nil
      end)

    section =
      Enum.find_value(blocks, "", fn
        %{"type" => "section", "text" => %{"text" => text}} -> text
        _ -> nil
      end)

    [header, section]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" - ")
    |> case do
      "" -> "Companion card"
      text -> text
    end
  end
end
