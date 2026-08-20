## Context

AGENTS.md and its `docs/ai/` tree were added in one commit (`f5186a40`) as a general agent-guidance template. Since then the repo adopted OpenSpec: 14 living specs under `openspec/specs/` and archived changes with `design.md` decision records now serve the roles the template's knowledge/decision/quality-gate systems were meant to fill. Audit findings driving this design:

- `docs/ai/knowledge/` and `docs/ai/decisions/` contain only their own scaffolding (README/TEMPLATE); zero entries were ever written. `deletion_candidates.md` has an empty table.
- `quality_gate.md` references another project's milestones ("AIS flow", "TPP registration") and mandates "Last triggered" bookkeeping that `quality/criteria.md` has no fields for.
- `mechanical_overrides.md` uses JavaScript vocabulary ("dead props", "barrel entries"), numbers two rules "5", and its "senior dev override" contradicts AGENTS.md's "surgical changes" principle.
- Key rules repeat across files (the `spec/dummy` subshell rule 3×, security-fix-needs-repro-test 4×), and two files point at "workflows.md Step 4", which does not exist (workflows.md has Phases).
- AGENTS.md §0 mandates reading `workflows.md` + `testing.md` + `mechanical_overrides.md` (331 lines) before any task, defeating the lazy-load pattern its own §5/§6 use correctly.

Constraint: `openspec/specs/agent-guidance-openspec-integration/spec.md` requires AGENTS.md to route agents to OpenSpec workflows and to remain (with its linked docs) the authoritative source for execution guidance.

## Goals / Non-Goals

**Goals:**
- Delete the never-used process systems and their scaffold directories.
- Make AGENTS.md self-sufficient: an agent reading only AGENTS.md knows every always-applicable invariant and where to load task-specific detail.
- Each execution rule stated in exactly one authoritative file; other files may point to it but not restate it.
- No reference from any surviving doc to a deleted file or nonexistent section.

**Non-Goals:**
- No changes to `docs/ai/testing.md` content, `docs/ai/secrets.md`, or `docs/ai/plans/` (release roadmaps under `plans/releases/` still carry OPEN items; triaging completed refactor plans is a separate cleanup).
- No changes to `openspec/config.yaml` or the `agent-guidance-openspec-integration` spec — its requirements are satisfied by the new structure as-is.
- No application code, CI, or dependency changes.

## Decisions

**D1 — Delete rather than archive the dead process files.**
Git history preserves them (`f5186a40`); an `archive/` folder would recreate the clutter this change removes. Alternative considered: moving to `docs/ai/archive/` — rejected because the files have zero repo-specific content worth resurfacing.

**D2 — Salvage exactly three directives, into `workflows.md`.**
From `mechanical_overrides.md`: (a) Step-0 cleanup — remove dead code before structurally refactoring any file >300 LOC, as a separate commit; (b) phased execution — large refactors proceed in phases of ≤5 files with verification between phases. From `quality_gate.md`: (c) self-audit against the quality criteria before declaring a task complete (lands in Phase 4, which already points there). Everything else in those two files is duplicate, generic-harness advice, or foreign template content. Alternative: keeping `mechanical_overrides.md` trimmed — rejected; three surviving rules don't justify a boot-sequence file.

**D3 — Merge `rails-conventions.md` + non-RuboCop `code-style.md` content into `reference.md`.**
`reference.md` becomes the single "load when touching code" file: namespacing, aliases, paths, decorators, hooks, plugin compatibility notes, layout/association/route conventions, exception-handling and memoization idioms. `code-style.md`'s formatting rules (indentation, frozen literals, line length) are enforced by RuboCop and drop entirely — `bin/rubocop -A` is the authority. Alternative: three separate small files — rejected; they are always loaded together in practice and overlap (decorators appear in both `reference.md` and `rails-conventions.md`).

**D4 — Flatten `quality/criteria.md` → `criteria.md`; keep only the checklist.**
The severity-promotion and criteria-lifecycle meta-process never ran (no dates, no history) and depended on the deleted `quality_gate.md`. The checklist itself (RuboCop, specs, security checks, Rails/Camaleon conventions) is the useful core. A one-file `quality/` directory adds a path segment for nothing.

**D5 — AGENTS.md structure: inline invariants + one routing table.**
Inline (always applicable): boot facts (stack inference, branch prefixes), OpenSpec routing (§1, unchanged — spec requirement), behaviour principles, key commands with the `spec/dummy` subshell rule, spec-coverage and security-fix rules stated once with a pointer to detail, quick-reference paths/namespaces. One "load per task" table replaces §0's mandatory reads, §5/§6's partial lazy-loads, and §7's stale list: testing → `testing.md`, code/patterns → `reference.md`, workflow/PR/commit → `workflows.md`, secrets → `secrets.md`, pre-PR audit → `criteria.md`. Alternative: keeping a small mandatory boot set — rejected; every invariant that genuinely applies to all tasks fits in AGENTS.md itself.

**D6 — Fix cross-references during the rewrite, not after.**
`workflows.md` loses Phase 1 step 2 (checks of deleted `knowledge/`/`decisions/`) and the Phase 2C decision-journal trigger; "Step 4" pointers become correct phase references; `workflows.md`'s metadata-maintenance list keeps AGENTS.md/testing.md/README.md. `rails-conventions.md`'s pointer to `secrets.md` moves with the merged content into `reference.md`.

**D7 — CLAUDE.md is a one-line import shim, not a second guidance file.**
Claude Code loads `CLAUDE.md` (CLI, Agent SDK, and desktop alike) and does not read `AGENTS.md` natively, so `CLAUDE.md` contains exactly `@AGENTS.md`. The `@import` mechanism only follows `@`-prefixed paths outside code spans; AGENTS.md references its per-task documents as plain backticked paths, so only the entry point enters context at session start and the tree stays lazy-loaded. Consequence: AGENTS.md must never use `@`-prefixed paths for the `docs/ai/` files, or they would be eagerly imported into every session. Alternative considered: duplicating guidance in CLAUDE.md — rejected; two sources of truth is the failure mode this change removes.

## Risks / Trade-offs

- [Agents lose the "always read workflows.md first" nudge and might miss branch/commit protocol] → The branch-prefix rule and `[skip ci]` trigger are restated as one-liners in AGENTS.md inline invariants with the routing table pointing at `workflows.md` for the full protocol.
- [Deleting `decisions/`/`knowledge/` loses the intended institutional-memory mechanism] → OpenSpec already provides it with actual usage: durable behavior in `openspec/specs/`, decision records in archived changes' `design.md`. The deleted system had zero entries to migrate.
- [Merged `reference.md` grows (~150 lines) and mixes lookup tables with conventions] → Acceptable: it is lazy-loaded per task, and one medium file beats three overlapping small ones for discovery; section headers keep it scannable.
- [External links (blog posts, PRs) may reference deleted doc paths] → Only in git history/PR descriptions; no repo file outside the AGENTS tree references them (verified by grep), and `docs/ai/` is not part of any published site.

## Migration Plan

Single docs-only commit (`[skip ci]`): deletions, merges, and rewrites land atomically so no intermediate state has dangling references. Rollback is `git revert` of one commit.

## Open Questions

- None blocking. Follow-up candidate (out of scope): triage completed refactor plans under `docs/ai/plans/` (helper-ivar phases, phase-6g) once their release plans close.
