## Why

Camaleon CMS has OpenSpec commands and skills installed, but its agent entry point does not explain when to use the planning workflow. OpenSpec artifact generation also lacks the durable project context already defined in the repository's agent guidance, which can lead to inconsistent or unnecessary planning.

## What Changes

- Define when agents should use OpenSpec and the command-driven lifecycle in `AGENTS.md`.
- Preserve direct execution for trivial, narrowly scoped, and documentation-only work.
- Add concise Camaleon CMS planning context and artifact rules to `openspec/config.yaml`, referring agents to `AGENTS.md` for the authoritative execution guidance.

## Capabilities

### New Capabilities

- `agent-guidance-openspec-integration`: Guide agents to select and use the appropriate OpenSpec workflow while applying the repository's established planning and execution rules.

### Modified Capabilities

None.

## Impact

- `AGENTS.md`: Adds OpenSpec workflow-selection and lifecycle guidance.
- `openspec/config.yaml`: Adds project context and artifact rules for generated planning documents.
- No application behavior, public API, dependencies, or database schema changes.
