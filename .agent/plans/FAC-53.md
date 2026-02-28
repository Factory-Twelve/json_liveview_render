# FAC-53 Implementation Plan

## Problem / Current State

The current renderer has basic child projection behavior but lacks explicit slot semantics:

**Current state:**
- Children are handled as a flat list passed via `:children` assign (line 172 in renderer.ex)
- Children are recursively rendered but with minimal slot support
- No canonical child payload key specification beyond basic `:children`
- Missing slot definitions aren't explicitly handled
- Permission filtering works but child projection semantics aren't deterministic

**Issues:**
- Slot payload shape isn't explicit/deterministic for function components
- No explicit empty render path for missing slot definitions
- Current flat contract works but needs better ergonomics for real-world component trees

## Design

**Core approach:**
1. **Preserve backward compatibility** - maintain current flat `root + elements` contract and basic `:children` behavior
2. **Explicit child payload structure** - use `:children` as the canonical key but make payload shape explicit
3. **Deterministic slot rendering** - ensure child order preservation and predictable structure
4. **Safe missing slot handling** - empty list for missing/undefined slots instead of crashes

**Implementation strategy:**
1. Enhance `to_component_assigns/3` to create explicit child slot structure
2. Add validation/normalization for child payload shape
3. Ensure permission filtering integration (already works at line 32 in permissions.ex)
4. Add integration tests for nested scenarios with permissions

**Child payload structure:**
- Keep `:children` as the primary slot
- Ensure it's always a list (even when empty)
- Preserve rendering order from element children arrays
- Allow for future slot expansion while maintaining current contract

## Files to Change

1. **lib/json_liveview_render/renderer.ex**
   - Enhance `to_component_assigns/3` function (line 149)
   - Add child slot normalization logic
   - Ensure deterministic child payload creation

2. **test/json_liveview_render/renderer_test.exs**
   - Add integration tests for nested permission scenarios
   - Test missing slot definitions don't crash
   - Test child order preservation

3. **test/support/fixtures_helper.exs**
   - Add test components with nested structures for integration testing

## Key Decisions

1. **Canonical child key**: Continue using `:children` as the primary slot key for backward compatibility

2. **Slot payload shape**: Always provide a list structure, empty list for missing slots instead of nil/crash

3. **Permission integration**: Leverage existing permission filtering (line 32 in permissions.ex) - no changes needed there

4. **Backward compatibility**: Preserve current behavior where existing components continue working unchanged

5. **Error handling**: Missing slot definitions produce empty render paths (empty list) instead of errors

6. **Order preservation**: Maintain element order from spec children arrays during slot rendering

## Scope Boundaries

**In scope:**
- Explicit child projection behavior in renderer
- Deterministic slot payload shape via canonical `:children` key
- Safe handling of missing slot definitions (empty render path)
- Integration tests for nested permission filtering
- Backward compatibility with existing component behavior

**Out of scope:**
- Multiple named slots (e.g., `:header`, `:footer`) - beyond v0.2 scope
- Changes to permission filtering logic (already works correctly)
- Changes to spec validation (children handling works correctly)
- Streaming/partial rendering slot behavior (v0.3+ feature)
- Catalog/registry changes for slot definitions

**Preserved contracts:**
- Flat `root + elements` spec structure
- Current permission filtering at component level
- Existing component callback signatures
- Current prop binding behavior

## Validation

**DoD verification:**

1. ✅ **Nested nodes pass children through canonical key**: Test that children array from element spec becomes `:children` list in component assigns

2. ✅ **Slot rendering preserves hierarchy**: Test that nested component tree maintains parent-child relationships and rendering order

3. ✅ **Permission filtering applies before child projection**: Verify existing permission filter (permissions.ex:32) removes unauthorized children before component rendering

4. ✅ **Missing slot definitions don't crash**: Test components with no children field get empty `:children` list, not nil/error

5. ✅ **Integration tests cover nested scenarios**: Add tests with list/card parent containing permitted and denied children

**Test scenarios:**
- Parent component with mixed permitted/denied children
- Component with no children defined (gets empty list)
- Nested 3-level hierarchy with permissions at each level
- Child order preservation through permission filtering

**Acceptance criteria:**
- All existing tests continue passing
- `mix format --check-formatted` passes
- `mix compile --warnings-as-errors` passes
- New integration tests cover all DoD requirements

