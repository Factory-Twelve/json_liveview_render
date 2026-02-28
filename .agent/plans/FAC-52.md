# FAC-52 Implementation Plan

## Problem / Current State

Currently, the Registry module validates mappings at compile time but only issues warnings to stderr for unknown component types. This means that registries can map types that don't exist in the catalog and still compile successfully, leading to potential runtime failures.

Key issues:
- Unknown mappings generate warnings but don't fail compilation (registry.ex:116-120)
- Developers might miss warnings in CI logs and deploy broken mappings
- Runtime errors occur when trying to render components with unknown types

## Design

Convert the existing compile-time warnings in `validate_registry_entries!/4` into compile-time errors when unknown mappings are detected. This leverages the existing `@before_compile` hook infrastructure.

**Approach:**
1. Change `validate_registry_entries!/4` to raise compilation errors instead of warnings for unknown mappings
2. Keep the existing `check_catalog_coverage` behavior as warnings (for missing coverage)
3. Preserve all existing runtime APIs (`fetch!/2`, `has_mapping?/2`) unchanged
4. Add meaningful error messages that help developers fix the issue

**Error Message Format:**
```
** (CompileError) registry MyApp.Registry maps unknown component types [:unknown_component] that do not exist in catalog MyApp.Catalog.
Available types: [:metric, :data_table, :admin_panel]
```

## Files to Change

1. **lib/json_liveview_render/registry.ex**
   - Modify `validate_registry_entries!/4` to raise instead of warn for unknown mappings
   - Improve error message with available types for better DX

2. **test/json_liveview_render/registry_test.exs**
   - Update existing warning test to expect compile error instead
   - Add new test for compile failure with meaningful error message
   - Ensure existing runtime tests still pass

## Key Decisions

1. **Fail Fast**: Unknown mappings should fail at compile time, not runtime
2. **Preserve Coverage Warnings**: Keep `check_catalog_coverage` as warnings since missing coverage is less critical than wrong mappings
3. **Better Error Messages**: Include list of available catalog types in error message
4. **No API Changes**: Keep all existing runtime APIs unchanged for backward compatibility
5. **Test Strategy**: Use `Code.compile_string` with `assert_raise CompileError` for negative tests

## Scope Boundaries

**In Scope:**
- Convert unknown mapping warnings to compile errors
- Improve error message clarity with available types
- Add negative compile test coverage
- Update changelog entry

**Out of Scope:**
- Changes to runtime API (`fetch!/2`, `has_mapping?/2`)
- Changes to `check_catalog_coverage` behavior (remains warnings)
- Performance optimization of compilation checks
- Changes to Catalog module
- New Registry features beyond compile-time validation

## Validation

**Success Criteria:**
1. ✅ Registry with unknown mapping fails to compile with clear error
2. ✅ Registry with valid mappings compiles successfully
3. ✅ Existing runtime tests (`fetch!/2`, `has_mapping?/2`) pass unchanged
4. ✅ Negative compile test added using `Code.compile_string`
5. ✅ Error messages include available catalog types
6. ✅ `mix format` and `mix compile --warnings-as-errors` pass

**Test Plan:**
1. Run existing test suite to ensure no regressions
2. Test compilation failure with unknown mapping
3. Verify error message contains helpful information
4. Test that valid registries still compile
5. Test coverage warnings still work as expected

