# Camaleon CMS: Agent Entry Point

## 0. Boot Sequence (MANDATORY)
1. **Read these first:** `docs/ai/workflows.md`, `docs/ai/testing.md`, `docs/ai/mechanical_overrides.md`
2. **Acknowledge stack:** Ruby `3.4.9`, Rails `8.1.3`
3. **Create branch:** Prefix with `feature/`, `fix/`, or `security/`

## 1. Agent Behaviour

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

## 2. Key Commands

- **Test:** `bin/rspec` or `bin/rspec spec/path:line`
- **Lint:** `bin/rubocop -A`
- **Security:** `bin/brakeman --no-pager`
- **Verify load:** `bin/rails zeitwerk:check`

## 3. Quick Reference

| Path | Purpose |
|------|---------|
| `spec/dummy/` | Test Rails app |
| `app/apps/plugins/` | Plugins |
| `app/apps/themes/` | Themes |
| `config/routes/` | Split routes |

**Namespaces:** `CamaleonCms::*`, shortcuts: `Cama::Site`, `Cama::Post`

## 4. Patterns (lazy-load `docs/ai/reference.md`)

- Decorators: `object.the_title`, `object.the_url`, `object.decorate`
- Hooks: `hooks_run('hook_name')`

## 5. Gotchas (lazy-load `docs/ai/reference.md`)

- Uses **Dart Sass** via `dartsass-sprockets`
- Test DB: SQLite in `spec/dummy/db/schema.rb`
- Migrations: runs from both `db/migrate/` AND `spec/dummy/db/migrate/`

## 6. Required Context Files

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