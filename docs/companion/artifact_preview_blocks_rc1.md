# Artifact Preview Blocks RC1

Status: Internal experimental companion surface (non-core contract).

`JsonLiveviewRender.Blocks.ArtifactPreviewCatalog` and
`JsonLiveviewRender.Blocks.ArtifactPreviewRegistry` provide a reusable reference
bundle for artifact detail side panels consumed by Artifact Library and related
ops surfaces.

Included block types:

- `artifact_preview_header`
- `artifact_preview_lineage_summary`
- `artifact_preview_approval_summary`
- `artifact_preview_evidence_summary`

Scope notes:

- This bundle is for declarative preview/detail summaries only.
- Workbench should shape runtime data before rendering; workflow logic stays
  outside `json_liveview_render`.
- Spreadsheet-like comparison data remains out of scope and should stay outside
  this bundle.

Nested payload shape notes:

- `artifact_preview_lineage_summary.relationships` expects a list of maps with
  `label` plus a `refs` list. Each ref should include `artifact_id` and may
  include `title` and `status`.
- `artifact_preview_approval_summary.reviewers` expects reviewer maps with
  `name`, `status`, and optional `role`, `decided_at`, and `note`.
- `artifact_preview_evidence_summary.source_breakdown` expects maps with
  `label` and `count`.
- `artifact_preview_evidence_summary.evidence_refs` expects maps with `ref_id`,
  `title`, and optional `source_type`, `captured_at`, and `uri`.

Example render setup:

```elixir
JsonLiveviewRender.Test.render_spec(spec, JsonLiveviewRender.Blocks.ArtifactPreviewCatalog,
  registry: JsonLiveviewRender.Blocks.ArtifactPreviewRegistry,
  current_user: %{}
)
```

Example summary payload excerpt:

```elixir
%{
  "type" => "artifact_preview_approval_summary",
  "props" => %{
    "artifact_id" => "artifact_spec_digest_v3",
    "overall_state" => "needs_review",
    "summary" => "Merch approved, ops still pending final warehouse constraints.",
    "reviewers" => [
      %{
        "name" => "Merch lead",
        "status" => "approved",
        "role" => "Merchandising",
        "decided_at" => "2026-03-02T10:30:00Z"
      },
      %{
        "name" => "Ops lead",
        "status" => "needs_review",
        "note" => "Awaiting final warehouse bin fit."
      }
    ]
  },
  "children" => []
}
```
