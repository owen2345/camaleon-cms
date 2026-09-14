## Context

`CamaleonCms::Metas` is included by every engine model with options and metas (the taxonomy tree,
posts, custom fields, comments, users) and by `cama_subscriber`'s own model. Its `data_options` and
`data_metas` accessors are a queue the save callbacks drain into the record's `_default` options row
and its meta rows. PR #1299 made the drain consume the queue; this change fixes what its review found
around that drain.

## Goals / Non-Goals

**Goals:**

- One write per queued value, by a save that completes, on every model through one write path.
- A queued value survives a save that does not complete.

**Non-Goals:**

- Changing what `set_meta` caches on the writing instance (the caller's object, pinned by the
  "set_meta keeps the caller's value" requirement; `options` reads are the subject of #1302).
- Trusting the metas in memory beyond the creating save's own write: after it, a `metas.reset` or a
  row created around the association can leave them incomplete, so later writes query as before.

## Decisions

1. **Clear after writing, refill on rollback of the writing transaction.** The write nils both
   accessors and remembers what it took with the state of the current transaction
   (`connection.current_transaction.state`); an `after_rollback` refills the accessors, keeping
   values queued since, only when that state reads rolled back, which the outermost rollback
   propagates to released savepoints. Alternatives: clearing in `after_commit` re-writes the queue
   over a value set between two saves inside one transaction, the bug being fixed; a written-marker
   on the queued objects has the same rollback question. The transaction state is an internal API,
   guarded with `respond_to?`: a version without it leaves a rolled-back write consumed, as before.
2. **The post type fills its defaults after the shared write, not before it.** A `before_create`
   merge was tried first: it needed the pending options, and that read memoized the metas scope with
   no owner id, so the second create-time write of `_default` missed the row the first had created;
   it also let the pre-merged defaults override a `_default` meta. An `after_create` declared before
   `set_default_site_user_roles` writes only the defaults the creation left unset, at most one more
   UPDATE per post type creation.
3. **Metas before options.** A `_default` meta is the options row; writing it first lets the queued
   options merge into it through `writable_options`, which also caches the indifferent hash the
   readers expect. Both queues go through `set_metas` and `set_options`, so their container check and
   blank handling apply.
4. **Rebuild the metas scope before the create-time write.** The concern's `after_create` now runs
   before the metas autosave, which is where Rails rebuilds the association scope once the owner has
   an id; a `get_meta` before the save would otherwise leave the write looking for rows with a null
   owner. `previously_new_record?` (Rails 6.1+) selects the case.
5. **Refuse a malformed queued container in `before_save`.** The writers already raise
   `CamaleonCms::Metas::InvalidContainer`, but from `after_create`, after the INSERT; the same check
   before any statement leaves no row behind, on every model.
6. **Validate the `_default` meta for the decorator option.** The post-INSERT refusal inside
   `after_create` turns into `false` from `save`, and a joined transaction swallows the rollback; the
   existing validation reads that meta too, whichever key type names it.
7. **Read and look up a created record's metas in memory while its queues are written.** Every row
   the record has then is in the association target, so the per-key lookups and the options read go
   there. A rolled-back creation leaves those metas claiming rows that are gone, so the rollback
   builds them again (the record's own state is restored after the callback, so the write remembers
   that it created the record); an existing record drops its loaded metas and cached values instead.
8. **Remove the two hooks.** `save_metas_options_skip` had one overrider, the post type, and
   `fix_save_metas_options_no_changed` only forwarded; `docs/ai/ecosystem.md` records no consumer,
   and the removal is noted there and in the upgrade guide.

## Risks / Trade-offs

- [Rails changes `Transaction#state`] → the guard leaves a rolled-back write consumed; the specs for
  the refill fail on such a version and point at the guard.
- [A plugin passes options as a `_default` meta and expects them to replace `data_options`] → they
  merge now, with `data_options` winning per key; no surveyed plugin passes `data_metas` at all.
