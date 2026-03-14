# Wire Formats

## Goal

`json_liveview_render` supports one canonical UI contract and multiple ingress
or update formats around it.

Every external format must normalize into the same JSON-like document:

```json
{
  "root": "page",
  "elements": {
    "page": {
      "type": "column",
      "props": {},
      "children": []
    }
  }
}
```

This document defines the role of each wire format. It does not introduce a
runtime patch engine by itself.

## Format Roles

| Format | Role | Best fit | Key limit |
| --- | --- | --- | --- |
| Canonical JSON | Authoritative full-document shape | validation, rendering, storage | entire document payload |
| YAML ingress | Human-authored syntax for the same document | prompts, fixtures, hand editing | must normalize to JSON-like data first |
| JSON Merge Patch | Coarse object replacement against canonical JSON | replacing whole elements, props maps, or child arrays | arrays replace atomically |
| JSON Patch | Fine-grained path-based mutation against canonical JSON | single-prop edits, targeted child edits, explicit adds/removes | path validity must be explicit |

## Canonical JSON

Canonical JSON is the internal contract:

- top-level keys are `root` and `elements`
- `elements` is a flat object keyed by stable ids
- each element contains `type`, `props`, and `children`
- ids, prop keys, and patch paths all refer to the same string-keyed document

Anything outside that shape is ingress-only noise and is non-operative once the
document has been normalized.

## YAML Ingress

YAML is an alternate authoring syntax, not a separate AST.

Rules for YAML ingress:

- YAML must parse into the same canonical `root + elements` structure.
- The normalized in-memory state stays JSON-like even when the source text was
  YAML.
- YAML comments, anchors, aliases, tags, and formatting do not carry runtime
  semantics after parse.
- Non-JSON-native YAML values are out of scope in v1. Ingress should coerce
  them into plain strings/numbers/booleans/null/maps/lists or reject them.

Example YAML source:

```yaml
root: page
elements:
  page:
    type: column
    props:
      gap: md
    children:
      - metric_revenue
  metric_revenue:
    type: metric
    props:
      label: Revenue
      value: "$42k"
    children: []
```

After parse and normalization, that YAML document must be indistinguishable from
the equivalent canonical JSON object.

## JSON Merge Patch

JSON Merge Patch is for coarse updates to the canonical document.

Use it when the caller naturally wants to replace:

- `root`
- a whole element at `elements.<id>`
- a whole `props` map
- a whole `children` array

Merge Patch rules in this contract:

- apply the patch to the canonical JSON document, not to YAML source text
- object members omitted from the patch stay unchanged
- `null` removes object members
- arrays are replaced as complete values, never merged by element id
- the resulting document is then validated in complete or partial mode

Merge Patch is the wrong tool for surgical array edits. Replacing one child in
`children` still requires resending the full array.

## JSON Patch

JSON Patch is for fine-grained canonical mutations.

Use it when the caller needs to:

- change one prop without replacing sibling props
- add or remove a single child reference
- add or delete a single element by id

JSON Patch operates against JSON Pointer paths into the canonical document. Path
targets, supported operations, and failure behavior are defined in
`docs/patch-semantics.md`.
The v1 runtime surface supports `add`, `remove`, and `replace`.

## Choosing Between Merge Patch And JSON Patch

Prefer JSON Merge Patch when:

- replacing a whole element object is simpler than editing fields in place
- replacing a whole `props` map is acceptable
- array replacement is acceptable

Prefer JSON Patch when:

- ids need to stay stable while one field changes
- you need to append, insert, or remove one child id
- you need explicit failure on a missing path instead of silent object merge

## Related But Out Of Scope

These are not wire formats in this contract:

- `JsonLiveviewRender.Stream` event tuples such as `{:root, id}` and
  `{:element, id, element}`
- provider-specific stream adapters
- unified diff or ad hoc text patch formats
- event-handler or action payloads

Those surfaces may exist elsewhere in the repo, but they still need to target
the same canonical `root + elements` document.
