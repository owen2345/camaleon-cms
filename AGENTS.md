# Camaleon CMS: Agent Entry Point

## 0. Boot Sequence (MANDATORY)
1. **Read these first:** `docs/ai/workflows.md`, `docs/ai/testing.md`, `docs/ai/mechanical_overrides.md`
2. **Acknowledge stack:** Ruby (infer from `.tool-versions`), Rails (infer from `Gemfile` and `Gemfile.lock`)
3. **Create branch:** Prefix with `feature/`, `fix/`, or `security/`

## 1. OpenSpec Workflow

Use OpenSpec when the user requests it or when planned work has non-trivial behavior, contract, or cross-cutting concerns. Work directly for trivial, narrowly scoped, and documentation-only changes.

Before creating a change, run `openspec list --json` and continue a relevant active change rather than creating a duplicate. Use the installed `/opsx:*` prompts or matching OpenSpec skills to:

- Explore uncertain problems with `/opsx:explore`.
- Create or continue planning artifacts with `/opsx:propose`, `/opsx:new`, or `/opsx:continue`.
- Implement planned tasks with `/opsx:apply`.
- Confirm implementation matches the artifacts with `/opsx:verify`.
- Preserve completed decisions with `/opsx:archive`.

## 2. Agent Behaviour

### Think Before Coding
- Don't assume. State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them—don't pick silently.

### Simplicity First
- Minimum code that solves the problem. Nothing speculative.
- No features beyond what was asked.

### Surgical Changes
- Touch only what you must. Clean up only your own mess.
- Don't refactor things that aren't broken.

### Goal-Driven Execution
- "Fix the bug" → Write a test that reproduces it, then make it pass.
- Verify before reporting completion.

## 3. Key Commands

> **Note:** Since this project is a gem, Rails commands like `rails routes` or `bin/rails zeitwerk:check` MUST be run from the `spec/dummy` folder. Always use subshells or `&&` to ensure you return to the project root (e.g., `(cd spec/dummy && bin/rails ...)`).

- **Test:** `bin/rspec` or `bin/rspec spec/path:line`
- **Lint:** `bin/rubocop -A`
- **Security:** `bin/brakeman --no-pager`
- **Verify load:** `(cd spec/dummy && bin/rails zeitwerk:check)`

**Security Fixes:** Vulnerability fixes MUST include tests that reproduce the vulnerability (unless infeasible). All code changes must be covered by specs. See `docs/ai/workflows.md` Step 4.

## 4. Quick Reference

| Path | Purpose |
|------|---------|
| `spec/dummy/` | Test Rails app |
| `app/apps/plugins/` | Plugins |
| `app/apps/themes/` | Themes |
| `config/routes/` | Split routes |

**Namespaces:** `CamaleonCms::*`, shortcuts: `Cama::Site`, `Cama::Post`

## 5. Patterns (lazy-load `docs/ai/reference.md`)

- Decorators: `object.the_title`, `object.the_url`, `object.decorate`
- Hooks: `hooks_run('hook_name')`

## 6. Gotchas (lazy-load `docs/ai/reference.md`)

- Uses **Dart Sass** via `dartsass-sprockets`
- Test DB: SQLite in `spec/dummy/db/schema.rb`
- Migrations: runs from both `db/migrate/` AND `spec/dummy/db/migrate/`

## 7. Required Context Files

Load per task:
- **Testing** → `docs/ai/testing.md`
- **Code** → `docs/ai/code-style.md`
- **Rails patterns** → `docs/ai/rails-conventions.md`
- **Security** → `docs/ai/secrets.md`
- **Before PR** → `docs/ai/quality/criteria.md`
- **Review** → `docs/ai/quality_gate.md`

Load when discovering patterns or making lasting decisions:
- **Domain knowledge** → `docs/ai/knowledge_architecture.md`
- **Decision logging** → `docs/ai/decision_journal.md`

When cleaning up docs tree:
- **Deletion tracker** → `docs/ai/deletion_candidates.md`
