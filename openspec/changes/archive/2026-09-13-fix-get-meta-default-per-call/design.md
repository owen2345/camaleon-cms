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
- Making `the_meta` tolerate a stored number or boolean: it translates the read, which only a String or an
  Array can do, on the writing instance now as after a reload.

## Decisions

**Memoize the stored lookup and apply the default outside the memo.** The memoized block returns the parsed
stored value, or `''` when the key has no row. `get_meta` returns the caller's default when the memoized
value has no value, and the memoized value otherwise.
- One private predicate, `meta_value_absent?`, names "no value" for `get_meta` and `get_option`: nil or an
  empty string. No row, a null row, a stored `''`, `set_meta(key, nil)` and `set_meta(key, '')` all take
  that branch, and `options` already read them as no options.
- Rejected, a dedicated "missing" marker object: a `''` or nil from storage or from `set_meta` would still
  need the predicate, and a direct reader of the memo (`cama_get_cache`) would receive an internal object.
- Rejected, not memoizing misses: every repeated read of an absent key would query again. Absent keys are
  common: `thumb`, `summary`, `has_comments`, and plugin settings before their first save.
- Rejected, memoizing per default: defaults are usually fresh literals, so the memo would never hit.

**`set_meta` memoizes what a reload reads.** One private helper, `stored_form_of`, gives the form a read
returns for the text a row holds or for the value `fix_meta_value` produced: JSON parsed and read by
either key type at any depth, a legacy `'t'`/`'f'` as the boolean, the text itself when it holds no JSON,
nil for null. `get_meta` applies it to the row it reads and `set_meta` to the value it stores, so the
writing instance and a freshly loaded record agree for every input, and the caller's object is left as
passed and never handed back.
- Rejected, keeping the caller's object with `''` and nil as the exceptions: every coerced String
  (`'false'`, `'2024'`, `'null'`, `'[]'`) and every Symbol-keyed Hash kept the split, one exception per
  report.
- Rejected, dropping the memo entry in `set_meta` so the next read re-reads the row: an unsaved record's
  built meta is not found by the query the read runs.
- `options` no longer converts request parameters, since no read returns them; a stored JSON string that
  holds an object still reads as an indifferent copy of it. `PostType`'s decorator-option checks parse
  through the same helper.

**Return the caller's own default.** It is not copied or memoized. The option writers keep working because
they pass the options they change to `set_meta`, which memoizes the stored form of that object.

**A refused decorator-option write leaves the metas in memory.** `PostType#reject_unknown_decorator_class!`
drops the options memo, which the writers changed before the write, and no longer resets the association:
a refused write changes no row, and the reset discarded the metas an unsaved post type had built for its
first save while their memos kept answering.

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
  number or the boolean now, as it already did once the record was loaded again; `the_meta` raises on
  either for such a value, as it did after a reload.
- [Plugins outside the survey] → Breakage needs a read on the writing instance that depended on an earlier
  read's default, or on the caller's object coming back. The 2.9.5 upgrade guide describes both patterns
  for theme and plugin developers.
