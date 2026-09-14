# Drop memoized state on dup and reload

## Why

A record memoizes its meta and option reads, and a few values derived from them, for the request. That
memo outlived the state it was read from: Active Record's `dup` copied it by reference, so two copies of
a post read each other's option writes under their common unsaved keys, and `reload` refreshed the
attributes and associations but not the memo, so a reloaded record kept answering with values written
before it. Around that, a copy also inherited the record of the original's last queued write and, when
that write's transaction rolled back, queued the original's values on itself; a site's languages were
memoized outside the memo and kept their first value; a record's ability and a user's role survived a
reload too; and once a reload read the stored form, a boolean meta came back as the text column's `t`
or `f`, a String every reader took as present, and the hashes in a stored array lost their Symbol keys.

## What Changes

- A copy made with `dup` starts without the original's memoized values, without the record of its last
  queued write, and with queues of its own.
- `reload` drops the memoized values once it has replaced the record's state, leaves them when it
  fails, and rebuilds the record's ability and a user's role. `cama_clear_cache` drops them on demand.
  **BREAKING**: `CamaleonRecord#reset_ability` is removed; `reload` replaces it.
- A site's languages read through the meta memo, so a write, a reload and a copy keep them current.
- A boolean is stored as its JSON literal and reads back as the boolean; the hashes in a stored array
  read by either key type. **BREAKING**: a boolean `set_meta` writes is stored as `true`/`false`; a row
  stored as `t`/`f` by an earlier release keeps reading as that String.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `meta-storage-integrity`: gains the memoized-values requirement and the boolean and nested-hash
  round trip; the caller's-value requirement is scoped to the record's first save; the write-once
  requirement covers a copy; "reloaded" means a record loaded again only where it does.
