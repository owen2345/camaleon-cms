# Read the options a record holds by either key type on the instance that wrote them

## Why

On the instance that wrote a record's options, `options` and `get_option` can disagree with a reloaded
record:

- `set_meta` keeps the caller's own hash. If the caller put an option under a String key in a plain Hash,
  `options[:key]` and `get_option` miss it on that instance. A reloaded record parses the stored options
  into an indifferent hash and finds it.
- A record's options can be nil or an empty string. An earlier `get_meta` read without a default caches
  nil for a record that has none, and `set_meta` can write nil or an empty string. `options` then returns
  that value, and `get_option` and the option writers raise instead of treating the record as having no
  options, as a reloaded record with no options row does.

## What Changes

- `options` returns a record's options so that a String key and its Symbol twin read the same option:
  - a hash with indifferent access, or request parameters a caller passed to `set_meta`, as it is;
  - a plain Hash a caller passed to `set_meta` as an indifferent copy, leaving the caller's hash
    unchanged;
  - nil or an empty string as empty options.
- `get_option` and the option writers (`set_option`, `set_options` and its alias `set_multiple_options`,
  `delete_option`) already read through `options`. On the writing instance they now find either key type,
  as a reloaded record does, and treat nil or empty options as none.
- Options stored as null read as empty options and accept writes after a reload too.
- Unchanged: what `set_meta` caches and what `get_meta` returns.

**Non-goals:**

- Changing how `get_meta` caches a missing meta's default. It is a separate defect: for every meta, not
  only options, the default the first reader asked for is what later reads on the same instance return.
  Fixing it changes what every `get_meta` caller gets back and needs its own review. This change covers
  the nil options it can leave behind.
- Stored options that are not a hash, such as a string or an array. They fail in the option API as before,
  on the writing instance and after a reload alike.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `meta-storage-integrity`: adds requirements that `options` and `get_option` read the options the writing
  instance holds by either key type, and that nil or empty options read and write as none.

## Impact

- **Code:** `app/models/concerns/camaleon_cms/metas.rb`: `options`, and the comment of the writers'
  private helper.
- **Tests:** `spec/models/meta_spec.rb`.
- **Docs:** `docs/ai/ecosystem.md` (the `camaleon-ecommerce` binding), a note for theme and plugin
  developers in `docs/upgrading-to-2.9.5.md`, and `CHANGELOG.md`.
- **Engine:** it reads `options[...]` directly in 30+ places, among them `PostType#manage_categories?`,
  `Site` and the custom field views. On the writing instance these now find either key type too.
- **Plugins and themes:**
  - After `set_meta` with a plain Hash, `options` on that instance returns an indifferent copy instead of
    the caller's hash; after nil or an empty string, it returns empty options. `get_meta` still returns
    the caller's value.
  - A write into the hash `options` returns, made without `set_meta`, no longer reaches a caller's plain
    Hash. No code in the engine or in the plugin, theme and host repositories checked does that.
  - `camaleon-ecommerce` passes request parameters to `set_meta('_default', …)` and reads them back with
    `get_option`; those reads are unchanged.
