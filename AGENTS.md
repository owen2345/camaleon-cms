# Camaleon CMS

A Ruby Gem implementing a Ruby on Rails content management system (Rails Engine). Ruby >= 3.0, Rails >= 6.1.
Current development targets are Ruby `3.4.8` and Rails `8.1.2` (see `./docs/ai/rails-conventions.md` and `./.tool-versions`).

## Agent Behaviour

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" -> "Write tests for invalid inputs, then make them pass"
- "Fix the bug" -> "Write a test that reproduces it, then make it pass"
- "Refactor X" -> "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
When providing "Further Considerations," wait for explicit confirmation before proceeding with any next steps or implementations.

## Progressive Guidance
- [Workflow and branch/PR flow](./docs/ai/workflows.md) `must-read`
- [Mechanical execution overrides](./docs/ai/mechanical_overrides.md) `must-read`
- [Secrets handling policy](./docs/ai/secrets.md) `must-read`
- [Rails/RSpec conventions and repo rules](./docs/ai/rails-conventions.md) `must-read`
- [Code References](docs/ai/reference.md) `must-read`
- [Code Style](docs/ai/code-style.md) `must-read`
- [Testing and verification](./docs/ai/testing.md) `must-read`
- [Quality criteria checklist](./docs/ai/quality/criteria.md) `must-read`
- [Knowledge architecture and domain logging](./docs/ai/knowledge_architecture.md) `context`
- [Decision journal workflow](./docs/ai/decision_journal.md) `context`
- [Quality gate and review cadence](./docs/ai/quality_gate.md) `must-read`
- [v2.9.2 custom fields permission upgrade](./docs/upgrading-to-2.9.2.md) (`lib/tasks/custom_fields_roles.rake`, `app/controllers/camaleon_cms/admin/settings/custom_fields_controller.rb`) `context`
- [v2.9.2 select_eval migration and user-context requirements](./docs/MIGRATION_SELECT_EVAL.md) (`app/models/camaleon_cms/custom_field_group.rb`, `app/models/current_request.rb`, `app/models/camaleon_record.rb`) `context`
- [Candidates to remove from legacy guidance](./docs/ai/deletion_candidates.md) `context`
