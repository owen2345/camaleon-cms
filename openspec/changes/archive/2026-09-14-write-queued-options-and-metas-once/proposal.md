# Write queued options and metas once

## Why

A record's `data_options` and `data_metas` are written to its options and metas by the save
callbacks, but they stayed assigned, so every later save of the same instance wrote them again over
any option or meta set since. A post type opted out of the shared write to merge its default options
first and wrote them itself, after the metas autosave: its `data_metas` were skipped at creation, a
meta built before the first save kept its old value in the loaded metas, and the defaults were
written over an option set on the unsaved record. Around the write, a `_default` meta in
`data_metas` replaced the options written before it, a malformed container failed after the INSERT
with a bare error, a refused decorator option queued as that meta kept the row inside an enclosing
transaction, and the queues were cleared before the save's outcome was known, so a rolled-back save
consumed them.

## What Changes

- `data_options` and `data_metas` are written once, by the first save that completes, and read
  `nil` afterwards; a save rolled back after writing them queues them again for the next save.
- The metas are written before the options, through `set_metas` and `set_options`, so a `_default`
  meta merges with the queued options instead of replacing them.
- A post type takes the shared write path; its defaults fill in afterwards under whatever the
  creation set. **BREAKING**: `CamaleonCms::Metas#save_metas_options_skip` and
  `#fix_save_metas_options_no_changed` are removed; no surveyed plugin or theme uses either.
- A queued container that is not a set of fields is refused before the row is written; a decorator
  option queued as the `_default` meta is validated like one in `data_options`.
- A write on a record whose metas are loaded takes the row from them, as the read does, and a
  record being created reads and looks its metas up in memory while its queues are written; a
  rolled-back creation builds those metas again for the next save.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `meta-storage-integrity`: the write-once requirement gains the rollback, ordering and post type
  defaults rules; the container refusal covers the queued values before the row is written.
- `post-decorator-class-integrity`: the save-time validation covers the `_default` meta queued in
  `data_metas`.

## Impact

- Code: `app/models/concerns/camaleon_cms/metas.rb`, `app/models/camaleon_cms/post_type.rb`.
- Specs: `spec/models/meta_data_options_spec.rb`, `spec/models/post_type_spec.rb`,
  `spec/models/meta_duplicate_rows_spec.rb`, `spec/models/camaleon_cms/post_type_decorator_class_spec.rb`.
- Docs: `CHANGELOG.md`, `docs/upgrading-to-2.9.5.md`, `docs/ai/ecosystem.md`,
  `docs/security/permissions.md`.
- Plugins and themes: a handler reading the accessors from a saved record gets `nil`; an override of
  the removed hooks no longer takes effect. `docs/ai/ecosystem.md` lists no consumer of either.
