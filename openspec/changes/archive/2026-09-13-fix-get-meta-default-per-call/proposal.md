# Return each caller's own default when a meta has no value

## Why

`get_meta` memoizes each meta a record reads. For a meta with no value, meaning no row or a stored empty
string, it memoizes the default the first caller passed, and later reads on that instance get that default
instead of their own. A freshly loaded record returns each caller's own default, so a read's result depends
on what the instance read before it:

- `post.get_meta('gallery')` followed by `post.get_meta('gallery', [])` returns nil both times. A freshly
  loaded post returns `[]` for the second read.
- If a caller changes the returned default in place, later reads on that instance return the changed
  object.
- After `set_meta(key, '')`, the writing instance returns `''` and a reloaded record returns the default.

## What Changes

- `get_meta` memoizes what the record stores for a key and applies each caller's default on every call:
  - Each read of a meta with no value returns the default passed to that call.
  - This holds whether the record's metas are eager-loaded or read from the database.
  - A missing meta still costs one database read per instance.
- A later read on the same instance no longer returns a default that a caller changed in place. Storing
  the change takes `set_meta`, which a reloaded record already required.
- A meta written with `set_meta` as an empty string reads as the caller's default on the writing instance,
  as it does after a reload. Every other value written with `set_meta` is still returned as the caller's
  own object.
- Unchanged: what `set_meta` stores and memoizes, and what a read returns for a stored value, including nil
  for a meta stored as null.

**Non-goals:**

- Making a meta stored as null read as the default. It reads as nil on the writing instance and after a
  reload alike.
- How `options` reads nil options or a plain Hash. That is the `fix-same-instance-option-reads` change.
- How `delete_meta`, `data_options` saves, `dup` and `reload` handle the memo. Those are the open PRs
  #1298, #1299 and #1301.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `meta-storage-integrity`:
  - Adds a requirement that each read of a meta with no value returns its caller's default, reading the
    database once per instance.
  - Changes "set_meta keeps the caller's value on the writing instance" so that an empty string reads as
    the caller's default.

## Impact

- **Code:** `get_meta` in `app/models/concerns/camaleon_cms/metas.rb`.
- **Tests:** a new `spec/models/meta_default_spec.rb`.
- **Engine:** about 50 `get_meta` calls in `app/` and `lib/`, and every `options` and `get_option` read.
  `options` on a record with no options row returns a new empty hash on each call. The option writers
  already store their changes through `set_meta`.
- **Plugins, themes and hosts:** about 50 calls in the repositories `docs/ai/ecosystem.md` surveys.
  - None changes a returned default in place and reads it back without `set_meta` (design.md, "Risks /
    Trade-offs").
  - A read that fell back to an earlier caller's default now gets its own, as on a freshly loaded record.
- **`fix-same-instance-option-reads`:** the two changes touch separate methods. Once both land:
  - `options` no longer receives `''`, or the nil that a `get_meta` read without a default left memoized.
    A nil written with `set_meta`, or options stored as null, still reach it.
  - That change's requirement "Options that are nil or empty read and write as none" names a no-default
    read as one source of nil options. If that change is archived first, this change trims the clause.
