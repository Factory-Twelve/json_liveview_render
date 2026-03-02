# Security Best Practices Report

Date: 2026-03-02  
Repository: `/Users/jeff/dev/GenUI`  
Reviewer mode: `$security-best-practices` skill (best-effort fallback)

## Executive Summary

This repository is an Elixir/Phoenix LiveView library (`mix.exs`), which is outside the skill's first-class coverage (Python/JavaScript/Go reference packs). I completed a manual security-focused review and found **1 high-severity** issue and **2 hardening gaps** (medium/low).  

The highest-risk issue is in the chat-card HTTP sender: endpoint URLs are configurable but not validated, allowing potential SSRF and credential exfiltration if delivery context is attacker-influenced.

## Stack Identification (Evidence)

- Elixir project: [`/Users/jeff/dev/GenUI/mix.exs:1`](/Users/jeff/dev/GenUI/mix.exs:1)
- Phoenix LiveView dependency: [`/Users/jeff/dev/GenUI/mix.exs:33`](/Users/jeff/dev/GenUI/mix.exs:33)

## Critical Findings

No critical findings identified.

## High Findings

### [SBP-001] Unvalidated outbound endpoint configuration enables SSRF and token exfiltration risk

**Severity:** High  
**Impact:** If untrusted input can influence `context` delivery settings, the library can send authenticated requests to attacker-controlled or internal endpoints.

**Evidence**

- Teams webhook URL is used directly without URL validation: [`/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:64`](/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:64), [`/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:83`](/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:83)
- Slack base URL is configurable and used to build API endpoints; bearer token is attached: [`/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:122`](/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:122), [`/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:127`](/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:127), [`/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:149`](/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:149), [`/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:55`](/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:55)
- WhatsApp graph base URL is configurable and used to build authenticated endpoint calls: [`/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:95`](/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:95), [`/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:99`](/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:99), [`/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:112`](/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http.ex:112)

**Why this matters**

- The adapter currently accepts arbitrary host/scheme values for destination URLs.
- For Slack/WhatsApp flows, authorization headers are sent to whatever destination is configured.
- In AI-integrated systems where context assembly may involve partially untrusted data, this can become a direct exfiltration path.

**Recommended remediation**

- Parse and validate all outbound URLs before request execution.
- Enforce `https` scheme for all external destinations.
- Add per-target host allowlists (for example: `*.slack.com`, `graph.facebook.com`, known Teams webhook domains), with explicit opt-in escape hatches.
- Resolve and reject loopback, link-local, and RFC1918 private IP destinations.
- Disable `base_url`/`graph_base_url` overrides by default in production.

## Medium Findings

### [SBP-002] DevTools can expose full spec payloads in rendered HTML when enabled

**Severity:** Medium  
**Impact:** Misconfiguration can expose sensitive prompt/business data to client-side users through debug UI output.

**Evidence**

- DevTools rendering gate is configuration/assign-based only (no explicit production guard): [`/Users/jeff/dev/GenUI/lib/json_liveview_render/renderer.ex:90`](/Users/jeff/dev/GenUI/lib/json_liveview_render/renderer.ex:90), [`/Users/jeff/dev/GenUI/lib/json_liveview_render/renderer.ex:74`](/Users/jeff/dev/GenUI/lib/json_liveview_render/renderer.ex:74)
- DevTools prints full input and rendered JSON payloads into the DOM: [`/Users/jeff/dev/GenUI/lib/json_liveview_render/dev_tools.ex:56`](/Users/jeff/dev/GenUI/lib/json_liveview_render/dev_tools.ex:56), [`/Users/jeff/dev/GenUI/lib/json_liveview_render/dev_tools.ex:64`](/Users/jeff/dev/GenUI/lib/json_liveview_render/dev_tools.ex:64)

**Recommended remediation**

- Add an explicit non-production guard (`Mix.env() != :prod`) unless a dedicated override is present.
- Redact known sensitive keys (`token`, `secret`, `password`, etc.) before rendering debug JSON.
- Keep `dev_tools_force_disable` enabled for production pages handling sensitive data.

## Low Findings

### [SBP-003] Default HTTP transport does not explicitly set TLS verification policy

**Severity:** Low (hardening)  
**Impact:** TLS posture depends on runtime defaults; explicit settings reduce ambiguity and environment drift risk.

**Evidence**

- `:httpc.request/4` is called without explicit SSL options: [`/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http_client/default.ex:20`](/Users/jeff/dev/GenUI/lib/json_liveview_render/companion/chat_cards/sender/http_client/default.ex:20)

**Recommended remediation**

- Provide explicit TLS options for HTTPS requests (certificate verification and hostname validation) in transport configuration.

## Notes

- This report is scoped to repository code and documented behavior; runtime deployment controls were not assessed.
- No code changes were applied in this pass.
