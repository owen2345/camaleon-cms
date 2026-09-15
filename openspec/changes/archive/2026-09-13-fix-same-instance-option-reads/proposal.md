# Read the options a record holds by either key type on the instance that wrote them

## Why

On the instance that wrote a record's options, `options` and `get_option` can disagree with a freshly loaded
record:

- `set_meta` keeps the caller's own hash. If the caller put an option under a String key in a plain Hash,
  `options[:key]` and `get_option` miss it on that instance. A freshly loaded record parses the stored options
  into an indifferent hash and finds it.
- A JSON string passed to `set_meta`, a form `PostType#set_meta` names, read as no options on that
  instance while a freshly loaded record parsed it, so the next option write on that instance replaced
  the row and lost the options the string held.
- A record's options can be nil or an empty string: `set_meta` can write either, and `get_meta` reads a
  stored null as nil. The merged options-row rule (#1297) already reads both as no options; 2.9.4
  returned the value, and `get_option` and the option writers raised on it. This change pins that reading
  on the writing instance and on a freshly loaded record.

- For a record with no options row, `options` returned the empty hash it asked `get_meta` for as a
  default, which `get_meta` memoized, so a change made to that hash without an option writer was read
  back and stored by the next write, where the same change after a plain Hash or nil was dropped.

## What Changes

- `options` returns a record's options so that a String key and its Symbol twin read the same option:
  - a hash with indifferent access as it is;
  - request parameters a caller passed to `set_meta` as an indifferent copy, nested parameters included,
    leaving the parameters unpermitted;
  - a JSON string a caller passed to `set_meta` as an indifferent copy of the object it holds;
  - a plain Hash a caller passed to `set_meta` as an indifferent copy that shares nothing with the
    caller's hash, nested hashes included, and carries no Hash default;
  - nil, an empty string or a missing options row as a new empty hash on each read, so a change made to
    it without an option writer is neither read back nor stored.
- `get_option` and the option writers (`set_option`, `set_options` and its alias `set_multiple_options`,
  `delete_option`) already read through `options`. On the writing instance they now find either key type,
  as a freshly loaded record does, and treat nil or empty options as none. The writers update the hash
  `options` returns in place, so an option written after request parameters is stored beside them; their
  private conversion helper, which raised on request parameters, is gone.
- Options stored as null read as empty options and accept writes on a freshly loaded record too, as the
  merged options-row rule has had it.
- Unchanged: what `set_meta` caches and what `get_meta` returns.

**Non-goals:**

- Changing how `get_meta` caches a missing meta's default. It is a separate defect: for every meta, not
  only options, the default the first reader asked for is what later reads on the same instance return.
  Fixing it changes what every `get_meta` caller gets back and needs its own review. This change covers
  the nil options it can leave behind.
- Caching in `set_meta` what a reload reads, which would make every meta read on the writing instance
  agree with a reload, options included: it changes the requirement that `get_meta` returns the object
  the caller passed, a decision for its own change (design.md).
- Stored options that are not a JSON object, such as a string or an array: they read as empty options
  and take a write, on the writing instance and on a freshly loaded record alike, as the options-row
  requirement has had it since #1297.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `meta-storage-integrity`: extends `set_meta keeps the caller's value on the writing instance` so that
  `options` and `get_option` read the options the writing instance holds by either key type, `An options
  row that is not an object reads as empty` so that nil or empty options read and write as none on the
  writing instance too, and `Options and metas given to a save are written once` with a post type created
  with only a `_default` meta, as a Hash or as request parameters.

## Impact

- **Code:** `app/models/concerns/camaleon_cms/metas.rb`: `options`, and the option writers, which lose
  their private conversion helper.
- **Tests:** `spec/models/meta_spec.rb`.
- **Docs:** `docs/ai/ecosystem.md` (the `camaleon-ecommerce` binding), a note for theme and plugin
  developers in `docs/upgrading-to-2.9.5.md`, and `CHANGELOG.md`.
- **Engine:** it reads `options[...]` directly in 30+ places, among them `PostType#manage_categories?`,
  `Site` and the custom field views. On the writing instance these now find either key type too. A post
  type created with a `_default` meta in `data_metas` and no `data_options` fills its defaults in under
  the options that meta holds, whichever key type names them and whether it is a Hash or request
  parameters; the merged code wrote the default over a String-keyed option and raised on parameters.
- **Plugins and themes:**
  - After `set_meta` with a plain Hash, `options` on that instance returns an indifferent copy instead of
    the caller's hash; after nil or an empty string, it returns empty options. `get_meta` still returns
    the caller's value until the first option write on that object, which stores and returns its own
    indifferent hash instead of writing into the caller's, as 2.9.4 did.
  - A write into the hash `options` returns, or into a hash nested in it, made without `set_meta`, no
    longer reaches a caller's plain Hash. No code in the engine or in the plugin, theme and host repositories checked does that.
  - `camaleon-ecommerce` passes request parameters to `set_meta('_default', …)` and reads them back with
    `get_option`. On the merged code those reads found no options on the writing instance, since the
    options-row rule read anything but a Hash as an empty row; they read the options again, and a writer
    called after them stores its option beside them, as 2.9.4 did.
