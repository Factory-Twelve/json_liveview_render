# FAC-54 Implementation Plan

## Problem

Streaming support is intended for the v0.3 candidate surface but still has implicit behavior:

- `JsonLiveviewRender.Stream` accepts broad event shapes and mutates state in ways that are not explicitly documented.
- Invalid or out-of-order transitions can be silently accepted or become terminal in confusing ways.
- Provider adapters currently do not distinguish malformed provider payloads from unrelated/noise events in all edge cases.
- Spec validation behavior around strict/permissive mode is not explicitly preserved across `ingest`, `finalize`, and `to_spec`.

## Design

1. Formalize a stream state machine for `{:root, id}`, `{:element, id, element}`, and `{:finalize}` with an explicit `:ok`/`:error` path for each transition.
2. Add internal helpers that:
   - classify valid state transitions
   - validate event shape by transition type
   - apply strict-mode behavior consistently using `Spec.validate_element/4` and `Spec.validate_partial/3` / `Spec.validate/3`.
3. Harden adapter normalization with deterministic payload parsing:
   - normalize incoming keys to string keys
   - distinguish malformed target-provider payloads from noise
   - return explicit `{:error, {:invalid_adapter_event, reason_or_payload}}` for malformed payloads.
4. Expand tests for stream transitions, post-finalize behavior, and malformed adapter payload vectors (truncated/missing fields and schema mismatch).
5. Update migration-facing docs:
   - explicit stream contract and transition/error matrix in `JsonLiveviewRender.Stream` module docs
   - explicit adapter section under experimental/companion surface in `README.md`
   - migration note entry in `CHANGELOG.md`.

## Files to Change

- `lib/json_liveview_render/stream.ex`
  - Add transition helper(s) and explicit transition validation
  - Add explicit malformed transition errors
  - Keep finalize/idempotency behavior safe after completion
  - Make `finalize/3` use partial validation when `require_complete: false`
  - Expand public module docs for allowed transitions and malformed sequence errors
- `lib/json_liveview_render/stream/adapter/openai.ex`
  - Normalize payload keys
  - Tighten mismatch/partial-payload handling to return explicit errors for malformed target payloads
- `lib/json_liveview_render/stream/adapter/anthropic.ex`
  - Mirror OpenAI deterministic normalization behavior for target-tool payloads
  - Add malformed target-payload explicit error path
- `test/json_liveview_render/stream_test.exs`
  - Add transition tests for out-of-order/duplicate cases and invalid root/event shapes
  - Add post-finalize and strict/permissive consistency assertions
- `test/json_liveview_render/stream_adapter_openai_test.exs`
  - Add malformed/noop/noise vectors for partial fields, decode shape mismatches, and schema mismatch cases
- `test/json_liveview_render/stream_adapter_anthropic_test.exs`
  - Add malformed/noop/noise vectors for partial fields and schema mismatch cases
- `test/json_liveview_render/stream_integration_test.exs`
  - Extend malformed adapter integration scenarios and ensure invalid events do not corrupt stream state
- `README.md`
  - Add adapter examples section under experimental/companion scope with explicit out-of-scope notes
- `CHANGELOG.md`
  - Add v0.3 migration note for stream state-machine normalization and adapter edge-case hardening
- `.agent/notes/FAC-54.md`
  - Record implementation handoff details and any risks/assumptions.

## Key Decisions

- Keep `:root` setting idempotent when receiving the same id to preserve existing compatibility for retries.
- Reject duplicate `{:element, id, _}` events as malformed transitions with explicit reasons to avoid silent overwrites.
- Treat recognized provider tool-use payloads with malformed fields as errors, while unrecognized payloads remain `:ignore`.
- Preserve `Stream.finalize/3` signature and defaults, but make partial validation explicit when `require_complete: false`.
- Keep stream state immutable on transition errors; successful transitions remain the only source of mutations.

## Scope Boundaries

### In scope
- Deterministic stream event transition rules for the existing event tuple contract
- Deterministic adapter normalization for malformed/missing fields and schema mismatch noise
- Public docs updates tied to `JsonLiveviewRender.Stream` and migration notes
- Expanded tests to cover malformed sequences and transition edges

### Out of scope
- Changes to transport adapters outside this package (`JsonLiveviewRender.Stream.Adapter.*` reference modules only)
- Changes to catalog/spec validation internals beyond explicit call patterns from stream
- Broadening event tuple grammar beyond the three documented events

## Validation

- Required docs check: `stream` and adapter docs describe allowed transitions and malformed returns.
- Stream tests confirm:
  - out-of-order events return explicit errors
  - duplicate elements error without state mutation
  - finalize idempotency and post-finalize reject behavior
  - strict/permissive behavior remains aligned with `Spec` element validation
- Adapter tests confirm:
  - deterministic handling of malformed payloads
  - malformed vs noise behavior is explicit
- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- Update `.agent/notes/FAC-54.md` with any follow-on assumptions before handoff.
