# Design — fix-scope-drift-and-cascade

## Context

See `proposal.md` — Why. All findings orbit `common_relationships.rb`, whose `included` block
derives the `object_class` scope once per including class (`TermTaxonomy` and `PostDefault`
re-include it per subclass via `inherited`, so every widget class gets its own name).
Load-bearing facts verified in code and by live execution:

- The 2.8.x–2.9.2 widget custom-fields breakage was a write/read mismatch: the assign
  controller's allowed-slugs lookup and the group caption said `'Widget::Main'` (both eras)
  while the association scope said `'Main'` (2.9.2) — submitted values were silently discarded
  because the allowed-slugs set came back empty. The unreleased rename aligned the concern to
  the literals; the maintainer-directed revert aligns the literals to the concern.
- The custom-fields settings form cannot place groups on widgets (that optgroup is commented
  out), and `owned_placement_ids` has no widget arm — so the assign controller and the caption
  are the only widget-scope literals in the engine.
- Group placement scopes disambiguate models by string, not id space (`'Post'` vs
  `'PostType_Post'`): the audit's feared id collision between a post and its type's groups
  cannot happen.
- Teardown on owner destroy is owned by `CustomFieldsRead#_destroy_custom_field_groups`
  (identical at 2.9.2 and master), which runs before any association dependent and destroys
  groups **with callbacks**. Live-verified: with the `delete_all` present, a destroyed post's
  group, fields, option metas, and values were all correctly gone — the hook, not the
  `delete_all`, did that. The only includer without the hook is `PostComment`.
- `CustomFieldGroup#destroy` is the complete teardown (`fields` → their option metas and
  values; the group's own metas). The concern's `custom_fields` association matches group rows
  too (same table, same scope), typed as `CustomField` — which has no `fields` association, so
  any `dependent:` through it would skip group teardown.

## Goals / Non-Goals

**Goals**

- One scope-naming contract — demodulized, 2.9.2's — with zero migration surface: every row a
  released install ever wrote keeps working (M9, M8 resolved by eliminating the rename).
- Widget custom fields keep working (the rename's one real fix, preserved by aligning the
  literals), pinned end to end.
- Owner destroy neither raw-deletes definitions nor orphans their children (N4, corrected).
- The `Widget::Assigned` rollback hazard is documented (M7).

**Non-Goals**

- No revert of the `post_class` STI discriminator compaction (M7's mechanism): it is guarded by
  #1194's dual-read and #1224's STI fallback, pinned by the `legacy-widget-assignment-compatibility`
  capability, and reverting it is a separate decision with H8-adjacent blast radius.
- No repair task and no compatibility read for rows master-tracking installs wrote under the
  short-lived prefixed scopes — deliberately abandoned, never released.
- No `:destroy` cascade on the concern's definition associations (unsafe through the
  `CustomField`-typed overlap; the hook owns teardown).

## Decisions

1. **Revert the naming, align the literals** (maintainer decision, 2026-08-09): the concern
   returns to `name.demodulize`; the assign controller's `cama_permitted_field_options` call and
   `get_caption`'s widget case move from `'Widget::Main'` to `'Main'`. Rejected: the audit
   plan's origin-test seam plus repair task — both exist only to compensate for an unreleased
   rename; reverting it deletes the problem instead of managing it.
2. **The joint gets an end-to-end pin**: a request spec drives the assigned-widget save through
   the real controller and asserts the value reads back. It is deliberately era-portable —
   green whenever literal and scope agree, red on any future one-sided rename.
3. **N4 = drop both `dependent: :delete_all`** (cop-pinned `Rails/HasManyOrHasOneDependent`,
   the cop that motivated adding them): inert for hook-carrying models, orphan-producing for
   hook-less ones. The lifecycle capability pins the hook's complete teardown (posts, post
   types) and the hook-less leave-definitions behavior (comments), so the next cop sweep cannot
   reintroduce the cascade without tripping specs.
4. **Repro-first where a defect reproduces**: the demodulize spec's host-model and widget cases
   were proven red against the prefixed concern earlier in this session (both directions); the
   hook-less lifecycle example was proven red against the `delete_all` concern (group row
   deleted). The teardown pins and the round-trip spec are green-by-design guards, stated as
   such.

## Risks / Trade-offs

- [Master-tracking installs wrote prefixed rows since the rename] → deliberately abandoned;
  master is unreleased, the changelog states the resolution, and re-keying back is a one-line
  SQL update an affected tracker could run themselves.
- [A future contributor "fixes" the caption or assign literal back to the class-derived name] →
  the round-trip spec and the caption-escaping spec both go red on any one-sided change.
- [Orphan group rows linger when a hook-less owner is destroyed] → 2.9.2 behavior, restored
  deliberately; the alternative (raw delete) orphans worse (children without parents).

## Migration Plan

Code-only; no data changes, no rake task. Deploy normally; rollback = revert the commits. The
M7 changelog note carries the only operator-facing caveat (rollback hides master-written widget
assignments).
