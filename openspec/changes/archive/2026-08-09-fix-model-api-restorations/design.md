# Design — fix-model-api-restorations

## Context

See `proposal.md` — Why. Everything here is grounded in the 2026-08-05 ecosystem sweep
(`ecosystem-plugin-bindings` capability, `docs/ai/ecosystem.md`): zero consumers exist for every
surface in this PR, so each decision is made on core's own merits, and the removals being
restored are insurance against unpublished external code, not observed breakage.

## Goals / Non-Goals

**Goals**

- Restore the three cheap, loud-when-missing surfaces (M5 alias, M6 method, M10 ordering) at
  2.9.2 parity on today's internals.
- Make the documentation tell the truth: `ActiveRecordExtras` is gone on purpose (M4), and slug
  uniqueness is site-wide (M11).

**Non-Goals**

- No `ActiveRecordExtras` code restore — zero consumers, never shipped in a release; the
  changelog note carries the migration recipe (`find_or_initialize_by` + `assign_attributes`).
- No `assign_tags`/`unassign_tags` restore — they were already broken at 2.9.2 (called a method
  that never existed); restoring them would create API that never worked.
- No Site ordering scope — the audited `term_group DESC` half is vacuous (`term_group` is never
  written for sites); the commented remnant is deleted, not revived.
- No change to `PostUniqValidator` behavior — M11 corrects the *claim* and pins the behavior;
  narrowing the scope to per-post-type would be a product decision with migration implications,
  out of audit scope.

## Decisions

1. **M5 = singleton alias** (`class << self; alias_method :find_by_key, :by_key; end`) directly
   under `by_key`. Spec calls carry the `Rails/DynamicFindBy` cop pin, the same pattern #1223
   used for the restored user finders. Rejected: defining a separate method (drifts), removing
   the `by_key` name again (breaks #1168-era callers).
2. **M6 = 2.9.2 body on the current counter API, plus `categories.reset` first.** Same signature
   and semantics (single id or array, `rescue_extra_data`, relationships destroyed,
   `update_counts('categories')` — the successor of 2.9.2's `update_counters`). The reset is a
   deliberate addition: `check_default_category` loads the `categories` association on every
   save of a category-managing post, and a loaded association makes `rescue_extra_data` and
   `update_counts` pluck the stale in-memory list — the refresh then never targets the removed
   category, and `TermRelationship`'s `before_destroy` counter callback recounts while the row
   still exists, so nothing else corrects it (verbatim 2.9.2 had the same latent quirk). Without
   the reset the restored method would violate its own counter contract in the default flow.
   `assign_category` is left untouched — its counters are corrected by the relationship's
   `after_create` callback, and touching it is out of this PR's scope.
3. **M10 = order-only default scopes.** 2.9.2's scopes also carried `where(taxonomy: …)`, which
   STI now supplies; only the ordering half is missing. All five render paths use
   `reorder(:term_order)` (#1194), which replaces the default order — verified by grep and by the
   existing menu specs staying green.
4. **Repro-first where the failure is loud** (M5/M6 raise `NoMethodError` red). For M10 a
   behavioral shuffle test would be vacuously green — SQLite returns insertion order for
   unordered selects — so the spec asserts the generated SQL carries the ascending-id ORDER BY
   (red on master, where the relation has no order), which is the actual contract external
   iterators depend on. For M11 the spec pins existing behavior (the finding is a documentation
   defect), so red-first does not apply; the cross-post-type example is the coverage that was
   missing.

## Risks / Trade-offs

- [Default scopes are global: any query on NavMenu/NavMenuItem gains ORDER BY id] → exactly the
  2.9.2 shape; render paths `reorder`; `count`/`update_columns` sites are order-insensitive; the
  full suite guards the rest.
- [`find_by_key` name triggers the `Rails/DynamicFindBy` cop at call sites] → callers pin it,
  as #1223 established; core itself keeps calling `by_key`.

## Migration Plan

Code-only, additive; no data changes. Deploy normally; rollback = revert the commits. The M4
changelog note is the migration guidance for external `update_or_create` callers.
