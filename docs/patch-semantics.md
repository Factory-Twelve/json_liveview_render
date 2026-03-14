# Patch Semantics

## Scope

This document defines how patch formats are expected to mutate the canonical
`root + elements` document described in `ARCHITECTURE.md`.

It defines the contract future patch code must implement. This ticket does not
add runtime patch application.

## Application Modes

Patch application can target one of two validation modes:

- Complete mode: the post-patch document must satisfy full validation.
- Accumulation mode: the post-patch document may temporarily omit `root` or
  contain unresolved child references, matching the current
  `Spec.validate_partial/3` allowance.

Both modes still operate on the same canonical JSON-like document. Accumulation
mode is a temporary relaxation, not a second document model.

## Structural Rules

After any accepted patch:

- the document root stays a JSON object
- `elements` stays an object
- canonical ids stay string keys
- every materialized element remains a map with `type`, `props`, and `children`
- `props` stays an object
- `children` stays an ordered array of child ids

In complete mode:

- `root` must be a string
- `root` must resolve to an entry in `elements`
- every child id must resolve to an entry in `elements`

In accumulation mode:

- `root` may be absent or unresolved temporarily
- child ids may point at not-yet-materialized elements temporarily

## Merge Patch Semantics

JSON Merge Patch applies coarse replacement semantics to canonical JSON.

Contract rules:

- omitted keys mean "leave unchanged"
- object values merge by key
- `null` deletes an object member
- arrays replace the entire prior array
- there is no id-aware merge inside `children`

Allowed coarse targets include:

- top-level `root`
- top-level `elements`
- `elements.<id>`
- `elements.<id>.props`
- `elements.<id>.children`

Examples:

Replace one prop map wholesale:

```json
{
  "elements": {
    "metric_revenue": {
      "props": {
        "label": "Revenue",
        "value": "$48k",
        "trend": "up"
      }
    }
  }
}
```

Replace an entire child list:

```json
{
  "elements": {
    "summary_row": {
      "children": ["metric_revenue", "metric_margin", "metric_forecast"]
    }
  }
}
```

Delete an element entry:

```json
{
  "elements": {
    "metric_margin": null
  }
}
```

Deletion can make the document invalid if `root` or any remaining `children`
still reference the removed id. That invalidation is intentional and must be
caught by post-apply validation.

## JSON Patch Semantics

JSON Patch is the fine-grained mutation format for canonical documents.

### Supported Operations

The v1 contract reserves these operations:

- `add`
- `remove`
- `replace`
- `test`

These operations are non-goals in v1:

- `move`
- `copy`

`move` and `copy` are intentionally excluded because they blur id stability and
make patch intent harder to reason about in agent-generated updates.

### Supported Paths

Supported JSON Pointer targets:

- `/root`
- `/elements`
- `/elements/<id>`
- `/elements/<id>/type`
- `/elements/<id>/props`
- `/elements/<id>/props/<prop>`
- `/elements/<id>/children`
- `/elements/<id>/children/<index>`
- `/elements/<id>/children/-`

Path segments use standard JSON Pointer escaping:

- `~1` for `/`
- `~0` for `~`

Element ids and prop names are always interpreted as literal object keys after
unescaping.

### Path Rules

- `add` may create the final object member when its parent object already
  exists.
- `add` to `/elements/<id>` must provide a full canonical element object.
- `add` to `/elements/<id>/props/<prop>` may create a new prop on an existing
  element.
- `add` to `/elements/<id>/children/-` appends one child id.
- `add` to `/elements/<id>/children/<index>` inserts before the given index.
- `remove`, `replace`, and `test` require the target path to exist.
- JSON Patch does not create missing intermediate containers. A missing element,
  missing `props`, or missing `children` array is a patch error for nested
  paths.

### Value Rules

- `/root` accepts only string values in complete mode.
- `/root` may be removed or set to `null` only in accumulation mode.
- `/elements/<id>` values must be canonical element objects.
- `/elements/<id>/type` values must be strings.
- `/elements/<id>/props` values must be objects.
- `/elements/<id>/children` values must be arrays of child ids.
- `/elements/<id>/children/<index>` and `/-` values must be single child ids.

## Error Handling

Patch application must fail explicitly when:

- the patch path points at a nonexistent element for `remove`, `replace`, or
  `test`
- a nested path is used without its parent object/array existing
- a value would make `elements`, `props`, or `children` the wrong container type
- a JSON Patch operation outside the supported set is used
- complete mode ends with missing `root` or unresolved child references

Merge Patch and JSON Patch differ here:

- Merge Patch may create or delete object members through object merge.
- JSON Patch must error on missing targets except for the final member created
  by a valid `add`.

## Merge Patch vs JSON Patch On Arrays

This is the main semantic difference the contract cares about:

- Merge Patch replaces arrays atomically.
- JSON Patch can append, insert, replace, or remove one array entry by index.

Example: append one child id with JSON Patch.

```json
[
  {
    "op": "add",
    "path": "/elements/summary_row/children/-",
    "value": "metric_forecast"
  },
  {
    "op": "add",
    "path": "/elements/metric_forecast",
    "value": {
      "type": "metric",
      "props": {
        "label": "Forecast",
        "value": "$52k",
        "trend": "up"
      },
      "children": []
    }
  }
]
```

The equivalent Merge Patch would have to replace the whole `children` array.

## Edge Cases

### Missing `root` During Partial Accumulation

Allowed only in accumulation mode. A patch format does not implicitly grant
partial-mode behavior; the caller chooses the validation mode.

### Patch Paths That Target Nonexistent Elements Or Props

- Merge Patch may create a new object member if the parent object exists.
- JSON Patch must fail when a nested target path is missing, except for a valid
  `add` creating the final member.

### Array Replacement Under Merge Patch

Replacing `children` replaces ordering, membership, and duplicates as one unit.
If the caller needs to preserve surrounding entries while editing one child
reference, use JSON Patch instead.

## V1 Non-Goals

The patch contract explicitly does not include:

- auto-generating ids
- semantic array merge by id
- patching through derived views or rendered output
- provider-specific patch dialects
- unified diff ingestion
