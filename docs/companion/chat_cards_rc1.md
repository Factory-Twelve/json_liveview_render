# Companion Chat Cards RC1

Status: Internal experimental companion surface (non-core contract).

## Targets

- `:liveview`
- `:web_chat`
- `:slack` (Block Kit)
- `:teams` (Adaptive Cards)
- `:whatsapp` (Business API interactive messages)

## Entry API

- `JsonLiveviewRender.Companion.ChatCards.compile/2`
- `JsonLiveviewRender.Companion.ChatCards.compile_and_send/2`

## Options

- `catalog` (required)
- `current_user` (required)
- `targets` (default all)
- `strict` (default `true`)
- `authorizer` (default allow-all)
- `slack_surface` (`:message | :home | :modal`, default `:message`)
- `whatsapp_mode` (`:auto | :buttons | :list`, default `:auto`)
- `sender` (optional behavior module for `compile_and_send/2`)

## Notes

- Permission filtering happens before bridge/target rendering.
- If permission filtering removes the root element, compilation returns an
  empty outputs/actions result with a warning instead of failing.
- Unknown mapped components degrade to text fallback with structured warnings.
- Truncation and platform limit adjustments are deterministic and warning-backed.
- Reference stylesheet: `docs/companion/chat_cards_reference.css`.

## HTTP Sender Adapter

For synchronous delivery hooks, RC1 includes:
- `JsonLiveviewRender.Companion.ChatCards.Sender.HTTP`
- `JsonLiveviewRender.Companion.ChatCards.Sender.HTTPClient.Default`

Context shape for `compile_and_send/2`:

```elixir
%{
  slack: %{bot_token: "...", channel: "..."},
  teams: %{webhook_url: "..."},
  whatsapp: %{access_token: "...", phone_number_id: "...", to: "..."}
}
```

Optional:
- `http_client` to inject a custom transport module
- per-target overrides (`slack.base_url`, `whatsapp.api_version`, etc.)
- URL security controls (global via `url_security`, or per-target overrides):
  - `allowed_hosts` (extends target default allowlist)
  - `allow_insecure_http` (default `false`)
  - `allow_private_destinations` (default `false`)
  - `disable_host_allowlist` (default `false`)
  - hostname resolution failures are treated as delivery errors when private
    destinations are disallowed
- retries via `retry: %{max_attempts, base_delay_ms, max_delay_ms, multiplier}`
- idempotency via `idempotency: %{enabled, key, header}` and per-target overrides
