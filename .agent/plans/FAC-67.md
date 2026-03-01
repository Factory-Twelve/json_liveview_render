# FAC-67 Implementation Plan

## Problem
The v0.3 closeout gate must only evaluate work that is explicitly in scope for the `v0.3 scope` initiative. FAC-67 needs a concrete scope conformance audit that confirms what is in scope, what is excluded, and where any scope ambiguity/delta still exists so the parent gate can close on defensible criteria.

## Design
1. Read and normalize scope sources in Linear:
   - Initiative: `v0.3 scope`
   - Parent gate issue: `FAC-61`
   - FAC-67 itself and sibling gate issues (`FAC-66`..`FAC-70`)
2. Build an explicit scope inventory for gate usage:
   - In-scope capabilities and gate checks
   - Out-of-scope exclusions that should not block v0.3 closeout
3. Identify and document scope deltas/ambiguities between the initiative anchor and current gate framing.
4. Attach a concise scope confirmation note to the parent issue (`FAC-61`) including:
   - Explicit in-scope list
   - Explicit out-of-scope list
   - Delta/ambiguity notes with tracking context
5. Record implementation details and follow-ups in `.agent/notes/FAC-67.md`.

No library/runtime code changes are expected for this ticket.

## Files to Change
- `.agent/plans/FAC-67.md` (create/update)
- `.agent/notes/FAC-67.md` (create/update)

## Key Decisions
- Treat the `v0.3 scope` initiative description as the canonical scope anchor.
- Use FAC-61/FAC-66 gate metadata as operational scope context for closeout checks.
- Satisfy acceptance via a parent-issue comment (instead of body rewrite) to keep the audit additive and traceable.
- Log any residual ambiguity as explicitly tracked notes rather than silently reconciling scope semantics.

## Scope Boundaries
### In scope
- Reconfirm v0.3 scope requirements from the initiative and gate issues.
- Produce explicit in-scope and out-of-scope lists for closeout gating.
- Add a concise scope conformance note to FAC-67 parent issue (`FAC-61`).
- Capture deltas/ambiguities and next-agent context in `.agent/notes/FAC-67.md`.

### Out of scope
- Changing project source code, tests, or runtime behavior.
- Rewriting initiative/project scope definitions.
- Reworking dependency links or issue structure outside what FAC-67 requires.

## Validation
- Verify scope confirmation comment is present on FAC-61 and contains explicit in-scope + out-of-scope lists.
- Verify any identified mismatch/ambiguity is captured in the parent note and handoff notes.
- `mix format --check-formatted`
- `MIX_PUBSUB=0 mix test`
- `mix compile --warnings-as-errors`
