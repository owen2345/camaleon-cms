# Camaleon CMS: Agent Entry Point

This file is self-sufficient: every rule below applies to every task. Load the documents in §5 only when the task needs them — no other reading is required before starting work.

## 1. Ground Rules (always apply)

- **Stack:** Ruby (infer from `.tool-versions`), Rails (infer from `Gemfile` and `Gemfile.lock`).
- **Branch first:** create a branch prefixed with `feature/`, `fix/`, or `security/` before writing code (full protocol: `docs/ai/workflows.md` Phase 1).
- **Gem quirk:** this project is a gem — Rails commands like `rails routes` or `bin/rails zeitwerk:check` MUST be run from the `spec/dummy` folder. Always use subshells or `&&` to ensure you return to the project root, e.g. `(cd spec/dummy && bin/rails ...)`.
- **Spec coverage:** ALL code changes must be covered by specs, except pure behavior-preserving refactors, documentation-only changes, and config changes with no code path modifications. If writing tests is infeasible, state why explicitly.
- **Security fixes:** vulnerability fixes MUST include a test that reproduces the vulnerability (unless reproducing is infeasible). Integration/feature specs are preferred over controller specs. Triage protocol: `docs/ai/workflows.md` Phase 2A; spec templates: `docs/ai/testing.md`.

## 2. OpenSpec Workflow

Use OpenSpec when the user requests it or when planned work has non-trivial behavior, contract, or cross-cutting concerns. Work directly for trivial, narrowly scoped, and documentation-only changes.

Before creating a change, run `openspec list --json` and continue a relevant active change rather than creating a duplicate. Use the installed `/opsx:*` prompts or matching OpenSpec skills to:

- Explore uncertain problems with `/opsx:explore`.
- Create or continue planning artifacts with `/opsx:propose`, `/opsx:new`, or `/opsx:continue`.
- Implement planned tasks with `/opsx:apply`.
- Confirm implementation matches the artifacts with `/opsx:verify`.
- Preserve completed decisions with `/opsx:archive`.

Record lasting decisions in the active change's `design.md`, and durable domain behavior as requirements in `openspec/specs/` — not in parallel journals under `docs/`.

## 3. Agent Behaviour

### Think Before Coding
- Don't assume. State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them—don't pick silently.

### Simplicity First
- Minimum code that solves the problem. Nothing speculative.
- No features beyond what was asked.

### Surgical Changes
- Touch only what you must. Clean up only your own mess.
- Don't refactor things that aren't broken. For refactors that are in scope, follow the Refactoring Protocol in `docs/ai/workflows.md` Phase 2C.

### Goal-Driven Execution
- "Fix the bug" → Write a test that reproduces it, then make it pass.
- Verify before reporting completion.

## 4. Key Commands

- **Test:** `bin/rspec` or `bin/rspec spec/path:line`
- **Lint:** `bin/rubocop -A` (auto-correct only what you touched)
- **Security:** `bin/brakeman --no-pager`
- **Verify load:** `(cd spec/dummy && bin/rails zeitwerk:check)`

All four must pass before pushing (CI parity).

## 5. Load Per Task

| When the task involves | Load |
|------|---------|
| Branching, vulnerability triage, refactoring protocol, commits, PRs, changelog | `docs/ai/workflows.md` |
| Writing or running tests; reproducing vulnerabilities | `docs/ai/testing.md` |
| Reading or writing app code: paths, namespacing, models, decorators, hooks, plugins, style idioms | `docs/ai/reference.md` |
| Env files, keys, credentials | `docs/ai/secrets.md` |
| Self-audit before opening a PR | `docs/ai/criteria.md` |

## 6. Quick Reference

| Path | Purpose |
|------|---------|
| `spec/dummy/` | Test Rails app |
| `app/apps/plugins/` | Plugins |
| `app/apps/themes/` | Themes |
| `config/routes/` | Split routes |

**Namespaces:** `CamaleonCms::*`, shortcuts: `Cama::Site`, `Cama::Post`
**Patterns:** decorators (`object.the_title`, `object.the_url`), hooks (`hooks_run('hook_name')`) — details in `docs/ai/reference.md`
