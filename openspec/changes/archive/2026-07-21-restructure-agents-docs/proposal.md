## Why

The AGENTS.md documentation tree carries five process files (plus two scaffold directories) for knowledge capture, decision logging, quality gating, and deletion tracking that have accumulated zero entries since their introduction and are now superseded by OpenSpec (`openspec/specs/` for durable domain knowledge, archived change `design.md` files for decision records). The surviving guidance is fragmented across 16 files totaling ~870 lines, with a mandatory "read first" boot sequence of 418 lines that defeats the progressive disclosure AGENTS.md advertises, key rules repeated in up to four places, stale cross-references ("workflows.md Step 4" does not exist), and directives contradicting each other (surgical-changes rule vs. senior-dev-override rule).

## What Changes

- **Remove dead process systems** (never used, superseded by OpenSpec):
  - `docs/ai/knowledge_architecture.md` and `docs/ai/knowledge/` (only a README, zero knowledge entries)
  - `docs/ai/decision_journal.md` and `docs/ai/decisions/` (only README + TEMPLATE, zero decision records)
  - `docs/ai/deletion_candidates.md` (empty tracking table)
  - `docs/ai/quality_gate.md` (references the dead systems and another project's milestones; its one useful directive moves to `workflows.md`)
  - `docs/ai/mechanical_overrides.md` (JavaScript-oriented template content, duplicate rule numbering, contradicts AGENTS.md surgical-changes principle; its two distinctive rules — Step-0 cleanup and phased refactoring — move to `workflows.md`)
- **Consolidate overlapping reference files**: merge `docs/ai/rails-conventions.md` and the non-RuboCop content of `docs/ai/code-style.md` into `docs/ai/reference.md`; delete the merged sources.
- **Flatten single-file directory**: move `docs/ai/quality/criteria.md` to `docs/ai/criteria.md`, dropping its unused meta-process sections (severity promotion, criteria lifecycle).
- **Rewrite AGENTS.md for progressive disclosure**: no mandatory secondary reading; always-needed invariants (branch prefixes, `spec/dummy` subshell rule, key commands, spec-coverage rule, OpenSpec routing) live inline; everything else loads per task via a single routing table.
- **De-duplicate and repair `workflows.md`**: remove references to deleted systems (Phase 1 context gathering, Phase 2C decision-journal trigger), absorb the salvaged rules above, and fix stale "Step 4" pointers.
- **Add a `CLAUDE.md` import shim** (single line: `@AGENTS.md`) so Claude Code auto-loads the entry point at session start; Claude Code reads `CLAUDE.md`, not `AGENTS.md`, and plain backticked paths in AGENTS.md are not imported, preserving lazy loading of the per-task docs.
- **Non-goals**: no changes to `docs/ai/testing.md` content, `docs/ai/secrets.md`, `docs/ai/plans/` (release roadmaps remain live), `openspec/config.yaml`, or any application code.

## Capabilities

### New Capabilities

- `agent-guidance-progressive-disclosure`: AGENTS.md is a self-sufficient entry point whose linked documents load per task type, contain no references to nonexistent files or sections, and state each execution rule in exactly one authoritative location.

### Modified Capabilities

<!-- none: agent-guidance-openspec-integration requirements are preserved unchanged;
     AGENTS.md keeps OpenSpec routing and remains the authoritative execution guide -->

## Impact

- **Files deleted** (8): `docs/ai/knowledge_architecture.md`, `docs/ai/decision_journal.md`, `docs/ai/deletion_candidates.md`, `docs/ai/quality_gate.md`, `docs/ai/mechanical_overrides.md`, `docs/ai/code-style.md`, `docs/ai/rails-conventions.md`, `docs/ai/quality/criteria.md` (with directories `docs/ai/knowledge/`, `docs/ai/decisions/`, `docs/ai/quality/`)
- **Files rewritten/edited**: `AGENTS.md`, `docs/ai/workflows.md`, `docs/ai/reference.md`; new `docs/ai/criteria.md` and `CLAUDE.md` (import shim)
- **Documentation tree**: 16 files / ~870 lines → 6 files / ~500 lines; mandatory boot reading drops from 418 lines to AGENTS.md alone
- **Constraint honored**: `openspec/specs/agent-guidance-openspec-integration/spec.md` requires AGENTS.md to route agents to OpenSpec and remain authoritative for execution guidance — both preserved
- **No code, CI, or dependency changes**; docs-only commit (`[skip ci]` per workflows.md Phase 3)
