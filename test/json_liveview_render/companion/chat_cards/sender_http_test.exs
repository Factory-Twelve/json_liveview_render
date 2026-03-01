defmodule JsonLiveviewRender.Companion.ChatCards.SenderHTTPTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Companion.ChatCards.Sender.HTTP

  defmodule CaptureHTTPClient do
    @behaviour JsonLiveviewRender.Companion.ChatCards.Sender.HTTPClient

    @impl true
    def post(url, headers, body, _opts) do
      decoded_body = Jason.decode!(body)

      response =
        Jason.encode!(%{
          "ok" => true,
          "request" => %{
            "url" => url,
            "headers" => Enum.map(headers, fn {name, value} -> [name, value] end),
            "body" => decoded_body
          }
        })

      {:ok, %{status: 200, body: response}}
    end
  end

  defmodule SlackErrorHTTPClient do
    @behaviour JsonLiveviewRender.Companion.ChatCards.Sender.HTTPClient

    @impl true
    def post(_url, _headers, _body, _opts) do
      {:ok, %{status: 200, body: ~s({"ok":false,"error":"invalid_auth"})}}
    end
  end

  defmodule StatusErrorHTTPClient do
    @behaviour JsonLiveviewRender.Companion.ChatCards.Sender.HTTPClient

    @impl true
    def post(_url, _headers, _body, _opts), do: {:ok, %{status: 500, body: "boom"}}
  end

  defmodule FlakyHTTPClient do
    @behaviour JsonLiveviewRender.Companion.ChatCards.Sender.HTTPClient

    @impl true
    def post(_url, _headers, _body, _opts) do
      attempt = Process.get(:flaky_attempt, 0) + 1
      Process.put(:flaky_attempt, attempt)

      if attempt < 3 do
        {:ok, %{status: 429, body: "rate limited"}}
      else
        {:ok, %{status: 200, body: ~s({"ok":true})}}
      end
    end
  end

  defmodule AlwaysRequestFailHTTPClient do
    @behaviour JsonLiveviewRender.Companion.ChatCards.Sender.HTTPClient

    @impl true
    def post(_url, _headers, _body, _opts) do
      attempt = Process.get(:request_fail_attempt, 0) + 1
      Process.put(:request_fail_attempt, attempt)
      {:error, :econnrefused}
    end
  end

  test "delivers Slack message payload to chat.postMessage" do
    payload = %{
      "blocks" => [
        %{"type" => "header", "text" => %{"type" => "plain_text", "text" => "QC Alert"}},
        %{"type" => "section", "text" => %{"type" => "mrkdwn", "text" => "Body line"}}
      ]
    }

    context = %{
      http_client: CaptureHTTPClient,
      slack: %{bot_token: "xoxb-token", channel: "C123", base_url: "https://slack.test/api"}
    }

    assert {:ok, response} = HTTP.deliver(:slack, payload, context)
    assert response["request"]["url"] == "https://slack.test/api/chat.postMessage"
    assert response["request"]["body"]["channel"] == "C123"
    assert response["request"]["body"]["blocks"] == payload["blocks"]
    assert response["request"]["body"]["text"] == "QC Alert - Body line"
  end

  test "propagates idempotency header and client_msg_id for Slack message delivery" do
    payload = %{
      "blocks" => [%{"type" => "section", "text" => %{"type" => "mrkdwn", "text" => "Body"}}]
    }

    context = %{
      http_client: CaptureHTTPClient,
      idempotency: %{enabled: true, key: "rc1"},
      slack: %{bot_token: "xoxb-token", channel: "C123", base_url: "https://slack.test/api"}
    }

    assert {:ok, response} = HTTP.deliver(:slack, payload, context)
    headers = response["request"]["headers"]

    assert Enum.any?(headers, fn [name, value] ->
             name == "x-idempotency-key" and value =~ "rc1-"
           end)

    client_msg_id = response["request"]["body"]["client_msg_id"]
    assert is_binary(client_msg_id)
    assert String.length(client_msg_id) == 36
  end

  test "delivers Slack home payload to views.publish" do
    payload = %{"type" => "home", "blocks" => [%{"type" => "section"}]}

    context = %{
      http_client: CaptureHTTPClient,
      slack: %{bot_token: "xoxb-token", user_id: "U123", base_url: "https://slack.test/api"}
    }

    assert {:ok, response} = HTTP.deliver(:slack, payload, context)
    assert response["request"]["url"] == "https://slack.test/api/views.publish"
    assert response["request"]["body"]["user_id"] == "U123"
    assert response["request"]["body"]["view"] == payload
  end

  test "delivers Teams payload in adaptive-card attachment envelope" do
    payload = %{"type" => "AdaptiveCard", "version" => "1.5", "body" => []}

    context = %{
      http_client: CaptureHTTPClient,
      teams: %{webhook_url: "https://teams.test/webhook"}
    }

    assert {:ok, response} = HTTP.deliver(:teams, payload, context)
    assert response["request"]["url"] == "https://teams.test/webhook"

    [attachment] = response["request"]["body"]["attachments"]
    assert attachment["contentType"] == "application/vnd.microsoft.card.adaptive"
    assert attachment["content"] == payload
  end

  test "delivers WhatsApp payload to Graph messages endpoint" do
    payload = %{"type" => "interactive", "interactive" => %{"type" => "button"}}

    context = %{
      http_client: CaptureHTTPClient,
      whatsapp: %{
        access_token: "wa-token",
        phone_number_id: "12345",
        to: "15551234567",
        graph_base_url: "https://graph.test",
        api_version: "v99.0"
      }
    }

    assert {:ok, response} = HTTP.deliver(:whatsapp, payload, context)
    assert response["request"]["url"] == "https://graph.test/v99.0/12345/messages"
    assert response["request"]["body"]["to"] == "15551234567"
    assert response["request"]["body"]["type"] == "interactive"
  end

  test "returns missing context error when target config is absent" do
    assert {:error, {:missing_delivery_context, :teams}} =
             HTTP.deliver(:teams, %{}, %{http_client: CaptureHTTPClient})
  end

  test "returns Slack API error when ok=false" do
    context = %{
      http_client: SlackErrorHTTPClient,
      slack: %{bot_token: "xoxb-token", channel: "C123"}
    }

    assert {:error, {:slack_api_error, "invalid_auth"}} =
             HTTP.deliver(:slack, %{"blocks" => []}, context)
  end

  test "returns structured HTTP status errors" do
    context = %{
      http_client: StatusErrorHTTPClient,
      teams: %{webhook_url: "https://teams.test/webhook"}
    }

    assert {:error, {:http_error, :teams, 500, "boom"}} =
             HTTP.deliver(:teams, %{"type" => "AdaptiveCard"}, context)
  end

  test "retries transient HTTP status errors and eventually succeeds" do
    Process.put(:flaky_attempt, 0)

    context = %{
      http_client: FlakyHTTPClient,
      sleep_fn: fn _ms -> :ok end,
      retry: %{max_attempts: 3, base_delay_ms: 1},
      teams: %{webhook_url: "https://teams.test/webhook"}
    }

    assert {:ok, %{"ok" => true}} = HTTP.deliver(:teams, %{"type" => "AdaptiveCard"}, context)
    assert Process.get(:flaky_attempt) == 3
  end

  test "stops retrying after max_attempts on transport failures" do
    Process.put(:request_fail_attempt, 0)

    context = %{
      http_client: AlwaysRequestFailHTTPClient,
      sleep_fn: fn _ms -> :ok end,
      retry: %{max_attempts: 2, base_delay_ms: 1},
      whatsapp: %{access_token: "wa-token", phone_number_id: "123", to: "15551234567"}
    }

    assert {:error, {:request_failed, :whatsapp, :econnrefused}} =
             HTTP.deliver(:whatsapp, %{"type" => "interactive"}, context)

    assert Process.get(:request_fail_attempt) == 2
  end
end
