# Knowledge Architecture

## Before Starting a Task
- Review existing domain rules and hypotheses in `knowledge/` before starting a new task.
- Apply rules by default.
- Check whether today's work can confirm or contradict any hypothesis.

## Storage Model
Use domain folders under `docs/ai/knowledge/`, for example:
- `docs/ai/knowledge/camaleon_cms/roles/`
- `docs/ai/knowledge/camaleon_cms/permissions/`

Each domain folder should contain:
- `knowledge.md` — facts, observations, patterns
- `hypotheses.md` — ideas that need more evidence
- `rules.md` — confirmed patterns to apply by default

## Index
- Maintain `docs/ai/knowledge/INDEX.md` as the router to active domain folders.
- Create a new domain entry in the index whenever a new knowledge folder is added.

## Promotion / Demotion Rules
- When a hypothesis is confirmed 3+ times, promote it to `rules.md`.
- When a rule is contradicted by new evidence, demote it back to `hypotheses.md`.

## End of Task
- Extract reusable insights from the task.
- Log them in the relevant domain folder so they are available for later analysis.
