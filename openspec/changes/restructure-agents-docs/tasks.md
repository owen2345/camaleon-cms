## 1. Branch and removals

- [x] 1.1 Create branch `fix/restructure-agents-docs` from latest `master`
- [x] 1.2 Delete dead process files: `docs/ai/knowledge_architecture.md`, `docs/ai/decision_journal.md`, `docs/ai/deletion_candidates.md`, `docs/ai/quality_gate.md`, `docs/ai/mechanical_overrides.md`
- [x] 1.3 Delete scaffold directories: `docs/ai/knowledge/` (README only) and `docs/ai/decisions/` (README + TEMPLATE only)

## 2. Consolidations

- [x] 2.1 Merge `docs/ai/rails-conventions.md` into `docs/ai/reference.md` (layout selection, model/decorator conventions, association options, hook system, route conventions, `secrets.md` pointer), de-duplicating the decorator and hook content already present
- [x] 2.2 Fold the non-RuboCop content of `docs/ai/code-style.md` (controller `rescue_from` pattern, memoization/immutability idioms) into `docs/ai/reference.md`, then delete `docs/ai/code-style.md` and `docs/ai/rails-conventions.md`
- [x] 2.3 Move `docs/ai/quality/criteria.md` to `docs/ai/criteria.md`, keeping the checklist (code quality, testing, security, Rails conventions, Camaleon-specific) and dropping the severity-promotion and criteria-lifecycle meta-process sections; remove the empty `docs/ai/quality/` directory

## 3. Rewrite workflows.md

- [x] 3.1 Remove Phase 1 step 2 (context gathering from deleted `knowledge/`/`decisions/`) and the Phase 2C decision-journal lifecycle trigger
- [x] 3.2 Add a "Refactoring protocol" section carrying the two salvaged rules: Step-0 cleanup (separate dead-code-removal commit before structural refactors of files >300 LOC) and phased execution (≤5 files per phase, verification between phases)
- [x] 3.3 Fix stale references: point the security-fix rule readers at the correct phase (Phase 2A, not "Step 4") and update the Phase 4 self-audit pointer to `docs/ai/criteria.md`
- [x] 3.4 De-duplicate rules now stated authoritatively elsewhere, leaving one-line pointers where context helps (spec/dummy subshell → AGENTS.md; PoC templates → testing.md)

## 4. Rewrite AGENTS.md

- [x] 4.1 Replace §0 mandatory boot reads with inline invariants: stack acknowledgement, branch prefixes, `spec/dummy` subshell rule, key commands, spec-coverage rule, and security-fix-needs-repro-test rule (single authoritative statement with pointer to workflows.md Phase 2A detail)
- [x] 4.2 Keep §1 OpenSpec routing unchanged in substance (required by `agent-guidance-openspec-integration` spec); add a line directing lasting decisions to change `design.md` and durable knowledge to `openspec/specs/`
- [x] 4.3 Replace §5/§6/§7 with a single load-per-task routing table: testing → `docs/ai/testing.md`, code/patterns/gotchas → `docs/ai/reference.md`, workflow/commit/PR → `docs/ai/workflows.md`, secrets → `docs/ai/secrets.md`, pre-PR audit → `docs/ai/criteria.md`
- [x] 4.4 Remove all references to deleted files (`mechanical_overrides.md`, `quality_gate.md`, `knowledge_architecture.md`, `decision_journal.md`, `deletion_candidates.md`, `quality/criteria.md`, `code-style.md`, `rails-conventions.md`)
- [x] 4.5 Add `CLAUDE.md` import shim (single line `@AGENTS.md`) so Claude Code auto-loads the entry point; keep all `docs/ai/` references in AGENTS.md as plain backticked paths so nothing else is eagerly imported

## 5. Verification

- [x] 5.1 Grep the repo (excluding `.git/`, `openspec/changes/`) for references to the eight deleted paths and the removed section pointers ("Step 4", `docs/ai/quality/`, `docs/ai/knowledge/`, `docs/ai/decisions/`) — zero hits outside git history
- [x] 5.2 Verify every file path referenced in AGENTS.md and the five surviving docs exists, and each execution rule (spec/dummy, coverage, security repro, phased refactor) is stated normatively in exactly one file
- [x] 5.3 Confirm `agent-guidance-openspec-integration` spec requirements still hold against the rewritten AGENTS.md (OpenSpec routing present, AGENTS.md authoritative for execution guidance)
- [ ] 5.4 Commit as a single docs-only commit with `[skip ci]` per workflows.md Phase 3, and add the changelog entry after the PR is created per Phase 4
