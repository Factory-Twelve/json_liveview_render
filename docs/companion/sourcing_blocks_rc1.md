# Sourcing Blocks RC1

Status: Internal experimental companion surface (non-core contract).

`JsonLiveviewRender.Blocks.SourcingCatalog` and
`JsonLiveviewRender.Blocks.SourcingRegistry` provide a narrow reference bundle
for the sourcing wedge's non-grid side-panel surfaces.

Included block types:

- `sourcing_evidence_card`
- `sourcing_artifact_summary`
- `sourcing_policy_flag`
- `sourcing_approval_widget`
- `sourcing_approval_action`

Scope notes:

- This bundle is for declarative cards, badges, and approval widgets only.
- Spreadsheet-like comparison data remains out of scope and should stay in AG Grid.
- Approval actions are static renderers only; workflow/event wiring stays outside
  `json_liveview_render`.

Example render setup:

```elixir
JsonLiveviewRender.Test.render_spec(spec, JsonLiveviewRender.Blocks.SourcingCatalog,
  registry: JsonLiveviewRender.Blocks.SourcingRegistry,
  current_user: %{}
)
```
