# Return each caller's own default when a meta has no value

## Why

`get_meta` memoizes each meta a record reads. For a meta with no value, meaning no row or a stored empty
string, it memoized the default the first caller passed, and later reads on that instance got that default
instead of their own. A freshly loaded record returns each caller's own default, so a read's result depended
on what the instance read before it:

- `post.get_meta('gallery')` followed by `post.get_meta('gallery', [])` returned nil both times. A freshly
  loaded post returns `[]` for the second read.
- If a caller changed the returned default in place, later reads on that instance returned the changed
  object.
- After `set_meta(key, '')`, the writing instance returned `''` and a reloaded record the default.

Two neighbouring splits between the writing instance and a reloaded record were found reviewing the fix:

- A row stored as null read as nil whatever the default, while `options` read it as no options; the admin
  role form stores such a row, after which creating a post type on the site raised.
- `set_meta` memoized the caller's object while the row stored its coerced form, so `'false'` read as the
  String on the writer and as `false` after a reload, and a Symbol-keyed Hash as the caller's object
  against an indifferent hash.

## What Changes

- `get_meta` memoizes what the record stores for a key and applies each caller's default on every call:
  - Each read of a meta with no value (no row, or a stored null or empty string) returns the default
    passed to that call; `get_option` returns its default for a null option as for an empty string.
  - This holds whether the record's metas are eager-loaded or read from the database.
  - A missing meta still costs one database read per key per instance.
  - A key is looked up by its String form, as `set_meta` stores it, so a key that is neither a String nor a
    Symbol is found among eager-loaded metas too.
- A later read on the same instance no longer returns a default that a caller changed in place. Storing
  the change takes `set_meta`, which a reloaded record already required.
- `set_meta` memoizes what a reload reads for the value it stores, so the writing instance reads as a
  freshly loaded record for every input: an indifferent hash for a Hash or request parameters, the number
  or the boolean for a numeric or boolean String, the value a JSON string holds, a plain String for any
  other text, the default for nil or an empty string. The caller's object is left as passed and never
  handed back.
- `options` returns the indifferent hash `get_meta` memoizes or a new empty one; a row holding a JSON string,
  even one whose text is an object, reads as empty options.
- `PostType` leaves the metas in memory when it refuses a decorator-option write, so an unsaved post type
  keeps the metas built for its first save.
- `the_meta` and `the_option` return a meta or option stored as a number, a boolean or a hash as read
  instead of raising; a String still reads through the locale, and so does every item of an Array, as a
  String whatever it holds.
- Unchanged: what `set_meta` stores, and that a meta with a value is handed back as the one memoized
  object.

**Non-goals:**

- Copying the stored value a read returns.
- How `delete_meta`, `data_options` saves, `dup` and `reload` handle the memo: #1298, #1299 and #1301,
  merged before this change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `meta-storage-integrity`:
  - Adds a requirement that each read of a meta with no value returns its caller's default, reading the
    database once per key per instance.
  - Renames "set_meta keeps the caller's value on the writing instance" to "set_meta reads back on the
    writing instance as a reloaded record does" and rewrites it: the written value reads back in the form
    a freshly loaded record reads, the caller's object left as passed.

## Impact

- **Code:** `get_meta`, `set_meta`, `get_option`, `options` and the stored-value parsing in
  `app/models/concerns/camaleon_cms/metas.rb`; `PostType`'s decorator-option refusal and parsing.
- **Tests:** `spec/models/meta_default_spec.rb` and `spec/models/meta_written_form_spec.rb`, new; the
  identity examples of `spec/models/meta_spec.rb` now read the stored form; a shared metas-query counter
  in `spec/support/sql_queries.rb`.
- **Engine:** about 50 `get_meta` calls in `app/` and `lib/`, and every `options` and `get_option` read.
  The option writers already store their changes through `set_meta`.
- **Plugins, themes and hosts:** about 50 calls in the repositories `docs/ai/ecosystem.md` surveys.
  - None changes a returned default in place and reads it back without `set_meta`, and none compares a
    read to the object it passed or reads its Symbol keys back on the writing instance (design.md, "Risks /
    Trade-offs").
  - `camaleon-ecommerce`'s deprecated, uncalled `LegacyOrder#payment_method` and `#payment` raise on an
    order without a `payment` meta whatever was read before; recorded as withdrawn behaviour in
    `docs/ai/ecosystem.md`.
- **`fix-same-instance-option-reads` (#1302):** merged before this change. Its requirement "An options row
  that is not an object reads as empty" gains a scenario for a row holding a JSON string whose text is an
  object; a no-default read leaves nil memoized, which `options` reads as no options.
