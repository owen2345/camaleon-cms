## Context

`CamaleonRecord` memoizes per instance, in one hash keyed by class, id and key, through
`cama_fetch_cache`/`cama_set_cache`: every `get_meta` and `get_option` read, and a few derived values
(a category's post type, a post's parents and children, a decorator's rendered fields, a plugin's
product variations). PR #1301 started by dropping that hash on `dup` and `reload`; the max-effort
review of that change found the sibling state the two hooks left behind and the contract they
under-described. This change records those decisions.

## Goals / Non-Goals

**Goals:**

- A copy and a reloaded record answer from their own state only.
- What a record reads back matches what was written, on the writer and after any load.

**Non-Goals:**

- Dropping the memo on an association-level refresh (`metas.reload`, `metas.reset`): the memo also
  holds values that are not metas, and no engine or plugin path refreshes the association and reads
  on the same instance; the requirement says so instead of promising it.
- Changing the memo's key: it embeds the id, so what a new record memoizes before its first save is
  not read after it; the caller's-value requirement is scoped to that boundary rather than the key
  changed, since the post-save read is the stored row and nothing reads across the boundary.
- `clone`, which shares everything as Active Record documents.

## Decisions

1. **Reset after `super`, in the Rails signature.** `reload(options = nil)` drops the memo in
   `super.tap`, so a reload that raises (a row deleted elsewhere, a lock that times out) leaves the
   record and its memo as they were, the ordering of Active Record's dirty-tracking reset; the
   positional `options` forwards `lock!`'s `reload(lock: true)` as Active Record's own overrides do,
   without a rest array. A spec pins the forwarding with a message expectation on the row lookup,
   since SQLite emits no lock clause.
2. **One named reset.** `cama_clear_cache` sits beside the other cache helpers and is what `dup`,
   `reload` and the rollback repair call; a plugin that memoizes through `cama_fetch_cache` has a
   supported reset.
3. **A copy resets the Metas concern's own state in the concern.** `Metas#initialize_dup` drops the
   record of the last queued write and gives the copy `deep_dup`s of `data_options`/`data_metas`,
   before `CamaleonRecord#initialize_dup` drops the memo; the alternative, resetting the concern's
   variables from the base class, would reach across the boundary the memo helper was added to keep.
4. **The ability and the user role go with the reload.** Both are request memos built from stored
   inputs (the role row and its metas); `reload` rebuilds them and `reset_ability`, whose only purpose
   was that invalidation in specs, is removed. `current_user` and `current_site` stay: they come from
   the request, not the record. (`PostDefault`'s `cattr_accessor :current_user` shadows the record
   memo on posts, so a post's `can?` answers false; out of scope, noted for a follow-up.)
5. **Languages read through the meta memo.** `Site#get_languages` maps the meta read each time, so
   it follows every reset and write the memo does; the map is negligible next to the hash lookup.
6. **Booleans stored as JSON literals.** The stored form of a value is computed in one place
   (`Metas#fix_meta_value`; the `CustomFieldsRead` copy that every model resolved first is dropped)
   and stores `true`/`false` where the text column would cast to `t`/`f`; reads parse them back.
   Rows earlier releases stored as `t`/`f` keep reading as Strings: rewriting them is an operator
   decision, documented in the upgrade guide. The hashes in a parsed array are made indifferent by
   the same helper that already made a parsed hash indifferent.

## Risks / Trade-offs

- A plugin comparing a boolean meta to `'t'`/`'f'` reads a boolean now; no surveyed plugin does.
- `reload` costs the next read of each memoized key one query, as a fresh find always did.

## Migration

Replace `reset_ability` with `reload`; see the upgrade guide for boolean rows stored as `t`/`f`.
