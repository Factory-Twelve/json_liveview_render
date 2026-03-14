# Quality

## Required Checks

- `mix test`

## Documentation Rules

- Update `ARCHITECTURE.md` when public module boundaries or release-family scope change.
- Keep release-family promises aligned across `README.md`, `CHANGELOG.md`, and the architecture docs.
- Document any new experimental or deferred surface before exposing it.

## Review Bar

- Public APIs should fit the Catalog -> Spec -> Render model.
- Mix tasks should call into library code rather than silently forking behavior.
- New modules should make their dependency direction obvious.

## Future Enforcement

Later checks can verify:

- root architecture docs exist and are linked from `AGENTS.md`
- release-family docs stay consistent
- new public modules are documented
