## Context

See proposal.md, "Why". The approach is shaped by these constraints:

- **The memo.**
  - `get_meta` reads through `CamaleonRecord#cama_fetch_cache`. That keeps whatever its block returns for
    the key until `set_meta` replaces the entry, `delete_meta` removes it, or the instance drops its
    memoized values (`reload`, `dup`, a rolled-back write, `cama_clear_cache`).
  - `get_meta`'s block ended in `res == '' ? default : res`, so for a meta with no value the memo kept the
    first caller's default object.
  - `set_meta` replaced the entry with the caller's value, untouched, while the row stored
    `fix_meta_value`'s form: a String coerced with `to_var`, a container as JSON.
- **What reads as no value.** No row, a row stored as null, or an empty string. A null row parsed to nil
  and was returned as nil whatever the default, on the writing instance and after a reload, while
  `options` read the same row as no options; the admin role form stores such a row for a role's post-type
  permissions when only manager boxes are checked, and the post type creation that seeds that meta with a
  Hash default then raised.
- **Measured on the merge base**, with #1302 merged:
  - Three reads of a missing meta on one instance issue one metas query.
  - `get_meta('gallery')` followed by `get_meta('gallery', [])` returns nil twice, whether the metas are
    eager-loaded or not.
  - After a caller appends to a returned default, a later read returns the changed array.
  - A stored `''` row read without a default and then with one returns nil twice.
  - `set_meta('flag', 'false')` reads as the String on the writing instance and as `false` after a reload;
    `'2024'` as the String and as `2024`.
  - `options` on a record with no options row returns a new empty hash on each read.
- **Public API.** Plugins, themes and hosts call `get_meta`, `set_meta`, `options` and `get_option`
  directly (`docs/ai/ecosystem.md`). Some wrap `get_meta` in readers of their own: `scores` and
  `downloads` in `camaleon_website`'s store plugin, and `payment_data` and `e_settings` in
  `camaleon-ecommerce`.
- **Earlier decisions reopened.** #1292 made `set_meta` memoize the caller's object after a first
  iteration that memoized an indifferent copy, citing comparisons with the caller's hash, keyword splats,
  Symbol keys and identity; #1302 recorded that memoizing what a reload reads would close every
  writer/reload divergence at once and left reopening that requirement to its own change. The surveys of
  both found the engine's own examples to be the only reader of that identity.

## Goals / Non-Goals

**Goals:**

- A read of a meta with no value returns the default passed to that call, never one an earlier read passed
  or a caller changed in place.
- A read on the writing instance returns what a freshly loaded record reads, for every value `set_meta`
  stores.
- Keep the query profile: one lookup per key per instance, and eager-loaded metas still read in memory.

**Non-Goals:**

- Changing `cama_fetch_cache`, or the other memoized reads that use it: `render_fields`, `post_type`,
  `parents_`, `full_children_`, and `camaleon-ecommerce`'s `_get_variation_`.
- Copying or freezing the default a caller passes, or the stored value the memo holds: a meta with a value
  is handed back as the one memoized object, so a change made to it in place shows in later reads on the
  instance until a write or a reload.

## Decisions

**Memoize the stored lookup and apply the default outside the memo.** The memoized block returns the parsed
stored value, or nil when the key has no row. `get_meta` returns the caller's default when the memoized
value has no value, and the memoized value otherwise.
- The key is looked up by its String form, as `set_meta` and `delete_meta` name the row: a key that is
  neither a String nor a Symbol was found by the database lookup, which casts it, and missed among
  eager-loaded metas.
- nil, not `''`, for a key with no row: a direct reader of the memo (`cama_get_cache`) gets nothing it could
  change or take for a value, where the concern's `''` literal is frozen and reads as an empty text.
- One private predicate, `meta_value_absent?`, names "no value" for `get_meta` and `get_option`: nil or an
  empty string. No row, a null row, a stored `''`, `set_meta(key, nil)` and `set_meta(key, '')` all take
  that branch, and `options` already read them as no options.
- Rejected, a dedicated "missing" marker object: a `''` or nil from storage or from `set_meta` would still
  need the predicate, and a direct reader of the memo (`cama_get_cache`) would receive an internal object.
- A record's first save drops what it memoized before it (`CamaleonRecord`, after create): every memo key
  holds the record's id, so a value memoized with none is read by no key once the INSERT assigns one, and
  the memo of a meta written before the save was kept for the instance's life beside the one read after
  it. No read changes; the other memoized reads keep their keys.
- Rejected, not memoizing misses: every repeated read of an absent key would query again. Absent keys are
  common: `thumb`, `summary`, `has_comments`, and plugin settings before their first save.
- Rejected, memoizing per default: defaults are usually fresh literals, so the memo would never hit.

**`set_meta` memoizes what a reload reads.** One private helper, `stored_form_of`, gives the form a read
returns for the text a row holds or for the value `fix_meta_value` produced: JSON parsed and read by
either key type at any depth, a plain String copy of the text when it holds no JSON, nil for null; a
legacy `'t'`/`'f'` row reads as the boolean before it. `get_meta` applies it to the row it reads and `set_meta` to the value it
stores, so the writing instance and a freshly loaded record agree for every input, and the caller's
object is left as passed and never handed back.
- Rejected, keeping the caller's object with `''` and nil as the exceptions: every coerced String
  (`'false'`, `'2024'`, `'null'`, `'[]'`) and every Symbol-keyed Hash kept the split, one exception per
  report.
- Rejected, dropping the memo entry in `set_meta` so the next read re-reads the row: an unsaved record's
  built meta is not found by the query the read runs.
- Rejected, returning the text itself when it holds no JSON: `fix_meta_value` passes a caller's plain
  String through unchanged, so the memo was the caller's object and a change made to it after the write
  was read.
- Rejected, a `dup` of the text: it keeps an html_safe String html_safe, which renders unescaped on the
  writing instance where a freshly loaded record reads a plain String. `String.new` copies the text as the
  column casts it, transcoded to UTF-8, which the database stores text in, so a String in another encoding
  reads as a reload reads it.
- Text that cannot open a JSON text is copied without a parse. No supported json release parses a text
  opening, after its whitespace, with anything but `[`, `{`, `"`, `/`, `-`, a digit, `t`, `f` or `n`, so the
  common text of URLs, names and markup no longer raises and rescues a parse failure on every write and
  every read. The skip mirrors the json gem's grammar, so a spec holds it to the parser installed, for text
  opening with any ASCII character or a Unicode space after any whitespace: a release that accepts another
  opening fails it rather than reading such rows as text.
- A value whose text is `'t'` or `'f'`, a String or a Symbol, is stored as its JSON string. The bare letter
  is how the text column cast a boolean before booleans were stored as their JSON literal, and a row holding
  it reads as that boolean, so the letter written alone read back as a boolean on the writing instance and,
  loaded again, had its row rewritten as the literal. The check reads the value's text, as the column
  stores it, not its class: a Symbol is stored as its text too. Rows an earlier release stored keep reading
  as booleans.
- A value of another class is stored as the text the column casts it to, and reads back as that text
  does: a `BigDecimal` as a Float, rounded where it holds more digits than a Float, and a `Time` or a
  `Date` as its text. The writing instance kept the caller's object until a reload; it now reads what the
  reload reads, as for every other value.
- `options` returns the indifferent hash `get_meta` memoizes, or a new empty one, and converts nothing: no
  read returns request parameters, a plain Hash or a JSON string any more, since `set_meta` memoizes them
  parsed, so the branches that converted them are gone. A row holding a JSON string, even one whose text
  is an object, reads as empty options, as the options-row requirement has every value that is not an
  object; no writer stores options encoded twice. `PostType`'s decorator-option checks parse through the
  same parser, `parse_stored_text`, and read the one option by its String key, without reading every hash
  in the options by either key type as a read of them all does.

**`set_meta` returns the value passed**, as 2.9.4 did, not the form it memoizes: a caller that tests the
result gets its own `'false'` or `'null'` back, not `false` or nil. The option writers return the hash
`options` returns after the write, as 2.9.4's did: returning what `set_meta` returns handed back, on a
record's first options write, the fresh hash they had filled rather than the one memoized from it, so a
caller holding it missed every later write.

**A Hash or an Array the instance handed out stays the one it reads.** When the value written is the very
object memoized for the key, the one `get_meta` or `options` returned, it takes the stored form in place and
stays memoized. The option writers write a copy of that hash, which takes the stored form in place once the
copy is stored, so a hash `options` returned keeps reading every later write on the instance, as in 2.9.4,
and a hash read, written back, and written back again after another write stores that write too. Any other
value is memoized as a fresh stored form, and the caller's own object is left as passed.
- Rejected, taking the stored form in place for every Hash memo whatever was written: a hash read before
  a write of another object would change under its reader, where 2.9.4 left it as read, so code comparing
  the value before and after a write would see no change.
- It takes the stored form value by value: a value it already holds in its stored form stays, so a hash or
  a list nested in it keeps reading the record across writes of other values, and a hash keeps its
  default, as 2.9.4's option writers, which changed only the option they wrote, left them.
- Rejected, `replace` with the stored form: every write swapped out every nested value, detaching a nested
  hash a caller held across the write of another option, and dropped the hash's default.
- Every option write compares each value it does not write with its stored form, a walk as long as the
  options, beside the parse of the whole row. A value changed in place without a writer is stored with the
  next write and must then read as a reload reads it: a Symbol as its text, a hash put in a list as an
  indifferent one. Rejected, keeping the values a write leaves out as they are, since the writer knows the
  keys it sets: cheaper for large options, but such a change would keep a form no reload reads. At the
  dozen options a post type holds, the walk and the parse add about 0.03 to 0.06 ms to a write.
- A String memo is left out: it may carry the translations `String#translate` memoized on it, which a
  change in place would leave stale.
- A frozen one cannot take the stored form in place: it is stored, and the stored form is memoized apart
  from it, where the change in place raised `FrozenError` after the row was written.
- When the write of that object raises, refused or failed, it takes the form the key's row reads as again,
  in place, and stays memoized: the caller changed the memo itself before writing it, so without the
  re-read the instance read a change nothing stored, and a post type whose refused decorator option
  stayed in its options refused every later option write. A direct write-back is the only way the memo
  holds a change before its write: the option writers write a copy. Where the row cannot be read either,
  the memo is dropped for the next read. Where it is gone, deleted by another instance, or holds a value of
  another kind, the object is emptied: it cannot take that form, and it would otherwise hold the change the
  write was to store.
- A direct write rolled back with its transaction is dropped at the instance's next read, write or save. A
  meta written or deleted outside a save of the record takes no part of the record in the transaction, so no
  rollback callback of it runs, while its memo and its metas in memory, whose values a rollback leaves as
  written, keep the write, and a meta it created, new again, was stored by the next save. Each such write
  keeps its key under the state of its transaction, and once that state is rolled back the metas in memory
  are dropped, keeping the ones built for other keys, and each key reads its row again, in place of a hash
  or a list handed out. Rejected, enlisting the record in the transaction: its rollback callbacks run only
  for a record its transaction saved.
- A row whose update fails takes back the value it stores. ActiveRecord leaves the value a failed save
  assigned on the record, and the eager-loaded metas the re-read and every later read take the row from
  would read that value as stored.

**Return the caller's own default.** It is not copied or memoized. The option writers keep working because
they pass the options they change to `set_meta`, which memoizes the stored form of that object.

**`the_meta` and `the_option` translate only what the locale applies to.** A String reads through the
locale as before, and so does an Array, item by item: `Array#translate` reads every item as a String, so a
number or a boolean in an Array reads as a String. A number, a boolean or a hash stored on its own is
returned as read, where the helpers raised on a loaded record and, with the writing instance reading the
stored form, on it too.
- Rejected, returning the items of an Array that are not Strings as read: `the_meta` already read them as
  Strings on a loaded record, which themes may rely on, and an Array never raised.

**An option write that raises leaves the options as stored.** The option writers set or delete whole options
on a copy of the options the instance holds and write it; once `set_meta` has stored it, the options handed
out take the stored form in place and stay memoized. The copy shares the values it does not replace, which
no writer changes in place, rather than copying every value the options hold on every write. A write that raises, whether `PostType` refuses it or storing it
fails, never changed them, so the instance keeps reading what is stored without querying for it again, and
nothing that reads the options while the write is checked sees it.
`PostType#reject_unknown_decorator_class!` therefore neither drops the options memo nor resets the
association: a refused write changes no row, and the reset discarded the metas an unsaved post type had
built for its first save while their memos kept answering.
- The value stored before the write, which a refusal compares with, is read from the database, from the
  row a write updates, even when the metas are loaded: loaded metas may be older than the row, and a
  refused value they still hold would pass as unchanged and be stored over a correction. The lookup runs
  only for a value that names no post decorator.
- Rejected, reading it from loaded metas to spare that query: the check decides what may be loaded as
  code, and the query is made only on the way to a refusal or to an unchanged legacy value.
- Rejected, changing the options in place and putting them back when the write raises: the options showed
  the write while it was checked, and the snapshot kept for the raise path cost a copy on every write.
- Rejected, memoizing the stored form of the copy in place of the options: the hash `options` returned
  would stop being the one the writers update, which a hash held across writes reads.

**`set_meta` hands the form it will store to a model check.** It computes the stored form once, before
writing, and passes it with the key to a private `check_meta_write` hook, where `PostType` holds the
decorator option to the allowlist. The post type no longer overrides `set_meta` to compute the same form a
second time for every options write.
- Rejected, reading the option from the value passed instead of its stored form: the key form written last
  in a Hash, a JSON string and request parameters would each need their own reading, which the stored form
  already settles.

## Risks / Trade-offs

- [A caller changes a returned default in place and expects a later read on the same instance to see it
  without `set_meta`] → The review of the engine and the surveyed repositories found none.
  - These callers change a default in place, keep it in a variable and pass that variable to `set_meta`:
    - `SiteDefaultSettings`, seeding the roles' `_post_type_<site>` metas;
    - the Rake backfills in `lib/tasks/custom_fields_roles.rake`;
    - `camaleon_website`'s store plugin (`scores`, `downloads`) and notification plugin (`sites`);
    - `camaleon-ecommerce`'s shipping prices (`@prices`).
  - The attack plugin changes `attack_config` only when it is stored.
  - The front_cache settings action changes `{ paths: [] }` for its own view only.
  - No reviewed code writes into the hash `options` returns except through an option writer.
- [A caller relied on an earlier read's default] → `camaleon-ecommerce`'s deprecated `LegacyOrder`:
  `#payment_method` and `#payment` read `get_meta("payment")` with no default.
  - On an order without a `payment` meta they raised, unless `shipping_method` had already memoized `{}`;
    they now raise either way, and `shipping_method` no longer raises after them.
  - Nothing in the plugin calls them: its only reference to the class is the 2016 order-data migration,
    which reads columns and `metas`.
- [A caller compares a read on the writing instance to the object it passed, or reads its Symbol keys] →
  None found in the engine, beyond its own examples, or in the surveyed repositories (the #1292 and #1302
  surveys); every hash read from `get_meta` and changed is passed to `set_meta` again.
- [A caller reads a numeric or boolean String back on the writing instance as the String] → It reads the
  number or the boolean now, as it already did once the record was loaded again, and `the_meta` returns
  it as read.
  - `camaleon-ecommerce`'s order-shipped email would be the surveyed case: `OrderDecorator#the_url_tracking`
    passes the consignment number written in the same request to `String#gsub` behind `rescue ''`, so an
    all-digit number would leave the email's tracking URL empty. The plugin's `Order` inherits
    `ActiveRecord::Base`, which lacks the memo helpers `CamaleonCms::Metas` calls (only `CamaleonRecord` has
    had them since 2.7.0), so `shipped!` already raises `NoMethodError` before the email, with or without
    this change; `.to_s` on that read is the fix once its models inherit `CamaleonRecord`
    (`docs/ai/ecosystem.md`).
- [Plugins outside the survey] → Breakage needs a read on the writing instance that depended on an earlier
  read's default, or on the caller's object coming back. The 2.9.5 upgrade guide describes both patterns
  for theme and plugin developers.
