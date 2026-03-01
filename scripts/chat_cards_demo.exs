alias JsonLiveviewRender.Companion.ChatCards
alias JsonLiveviewRender.Companion.ChatCards.Sender.HTTP

# Demo catalog lives in script scope so the script runs in any MIX_ENV without test support modules.
defmodule JsonLiveviewRender.Companion.ChatCards.DemoCatalog do
  use JsonLiveviewRender.Catalog

  component :card do
    description("Card container")
    prop(:title, :string, required: true)
  end

  component :status_badge do
    description("Status badge")
    prop(:severity, :string, required: true)
    prop(:label, :string, required: true)
  end

  component :text do
    description("Body text")
    prop(:content, :string, required: true)
  end

  component :data_row do
    description("Label-value row")
    prop(:label, :string, required: true)
    prop(:value, :string, required: true)
  end

  component :actions do
    description("Button collection")
  end

  component :button do
    description("Action button")
    prop(:id, :string, required: true)
    prop(:label, :string, required: true)
    prop(:style, :string)
  end
end

input_path = Path.expand("../test/fixtures/chat_cards/input/qc_alert.json", __DIR__)
spec = input_path |> File.read!() |> Jason.decode!()

{:ok, result} =
  ChatCards.compile(spec,
    catalog: JsonLiveviewRender.Companion.ChatCards.DemoCatalog,
    current_user: %{role: :member},
    targets: [:liveview, :web_chat, :slack, :teams, :whatsapp]
  )

for target <- [:liveview, :web_chat, :slack, :teams, :whatsapp] do
  IO.puts("\n=== #{String.upcase(to_string(target))} ===")
  IO.puts(Jason.encode!(result.outputs[target], pretty: true))
end

send_enabled? =
  System.get_env("CHAT_CARDS_SEND", "0")
  |> String.downcase()
  |> then(&(&1 in ["1", "true", "yes"]))

if send_enabled? do
  maybe_put = fn map, key, value ->
    if is_nil(value), do: map, else: Map.put(map, key, value)
  end

  slack_context =
    case {System.get_env("SLACK_BOT_TOKEN"), System.get_env("SLACK_CHANNEL")} do
      {token, channel} when is_binary(token) and token != "" and is_binary(channel) and channel != "" ->
        %{
          bot_token: token,
          channel: channel,
          base_url: System.get_env("SLACK_BASE_URL", "https://slack.com/api")
        }

      _ ->
        nil
    end

  teams_context =
    case System.get_env("TEAMS_WEBHOOK_URL") do
      url when is_binary(url) and url != "" -> %{webhook_url: url}
      _ -> nil
    end

  whatsapp_context =
    case {System.get_env("WHATSAPP_ACCESS_TOKEN"), System.get_env("WHATSAPP_PHONE_NUMBER_ID"),
          System.get_env("WHATSAPP_TO")} do
      {token, phone_number_id, to}
      when is_binary(token) and token != "" and is_binary(phone_number_id) and phone_number_id != "" and
             is_binary(to) and to != "" ->
        %{
          access_token: token,
          phone_number_id: phone_number_id,
          to: to,
          graph_base_url: System.get_env("WHATSAPP_GRAPH_BASE_URL", "https://graph.facebook.com"),
          api_version: System.get_env("WHATSAPP_API_VERSION", "v23.0")
        }

      _ ->
        nil
    end

  delivery_context =
    %{}
    |> maybe_put.(:slack, slack_context)
    |> maybe_put.(:teams, teams_context)
    |> maybe_put.(:whatsapp, whatsapp_context)
    |> Map.put(:retry, %{max_attempts: 3, base_delay_ms: 200, max_delay_ms: 2_000})
    |> Map.put(:idempotency, %{enabled: true, key: "chat-cards-demo"})

  targets =
    [:slack, :teams, :whatsapp]
    |> Enum.filter(&Map.has_key?(delivery_context, &1))

  if targets == [] do
    IO.puts("""

No delivery credentials found; set one of:
- SLACK_BOT_TOKEN + SLACK_CHANNEL
- TEAMS_WEBHOOK_URL
- WHATSAPP_ACCESS_TOKEN + WHATSAPP_PHONE_NUMBER_ID + WHATSAPP_TO
""")
  else
    {:ok, delivered} =
      ChatCards.compile_and_send(spec,
        catalog: JsonLiveviewRender.Companion.ChatCards.DemoCatalog,
        current_user: %{role: :member},
        targets: targets,
        sender: HTTP,
        context: delivery_context
      )

    IO.puts("\n=== DELIVERIES ===")
    IO.puts(Jason.encode!(delivered.deliveries, pretty: true))

    if delivered.warnings != [] do
      IO.puts("\n=== WARNINGS ===")
      IO.puts(Jason.encode!(delivered.warnings, pretty: true))
    end
  end
end
