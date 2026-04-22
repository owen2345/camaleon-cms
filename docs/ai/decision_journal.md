# Decision Journal

## Before Making a Lasting Decision
- If a decision affects more than today's task, search `docs/ai/decisions/` for prior decisions in that area first.
- Follow existing decisions unless new information invalidates their reasoning.

## When to Log a New Decision
Log a decision when:
- no prior decision exists for the topic, or
- you are replacing an existing decision.

## File Naming
Create files as:
- `docs/ai/decisions/YYYY-MM-DD-{topic}.md`

## Format Options

### Lightweight entry
Use for fast, low-ambiguity decisions where a brief record is enough:
```markdown
## Decision: {what you decided}
## Context: {why this came up}
## Reasoning: {why this option won}
## Trade-offs accepted: {what you gave up}
## Supersedes: {link to prior decision, if replacing}
```

### ADR-style entry
Use for architectural, integration, or cross-cutting decisions with meaningful alternatives:
```markdown
## Decision: {what you decided}
## Context: {why this came up}
## Status: {Accepted | Superseded | Deprecated}
## Alternatives considered:
- {option A}: {brief note}
- {option B}: {brief note}
## Reasoning: {why this option won}
## Trade-offs accepted: {what you gave up}
## Consequences: {what becomes easier or harder as a result}
## Supersedes: {link to prior decision, if replacing}
```

**Guidance:** prefer ADR-style when the decision involves external integrations, framework choices, data persistence, or security trade-offs. Use lightweight for process, tooling, or docs-only choices.

## Follow-up Rule
- If new evidence invalidates a prior decision, create a new decision record instead of silently editing history.
