## Context

See proposal.md, "Why". The approach is shaped by these constraints:

- **The memo.**
  - `get_meta` reads through `CamaleonRecord#cama_fetch_cache`. That keeps whatever its block returns for
    the key until `set_meta` replaces the entry or `delete_meta` removes it.
  - `get_meta`'s block ends in `res == '' ? default : res`, so for a meta with no value the memo keeps the
    first caller's default object.
  - `set_meta` replaces the entry with the caller's value, untouched (`meta-storage-integrity`).
- **What reads as no value.**
  - No row, or a stored empty string. The string fails to parse as JSON and is compared as it is.
  - A row stored as null is not "no value": it parses to nil and is returned as nil, whatever the default.
    The writing instance returns nil too, because `set_meta(key, nil)` memoizes nil.
- **Measured on master.**
  - Three reads of a missing meta on one instance issue one metas query.
  - `get_meta('gallery')` followed by `get_meta('gallery', [])` returns nil twice, whether the metas are
    eager-loaded or not.
  - After a caller appends to a returned default, a later read returns the changed array.
  - A stored `''` row read without a default and then with one returns nil twice.
  - After a read without a default, `options` returns nil.
- **Public API.** Plugins, themes and hosts call `get_meta`, `options` and `get_option` directly
  (`docs/ai/ecosystem.md`). Some wrap `get_meta` in readers of their own: `scores` and `downloads` in
  `camaleon_website`'s store plugin, and `payment_data` and `e_settings` in `camaleon-ecommerce`.
- **Other open work on the same file.** None of it changes `get_meta`:
  - `fix-same-instance-option-reads` changes `options`;
  - #1298 changes `delete_meta`;
  - #1299 changes `save_metas_options`;
  - #1301 changes `CamaleonRecord#dup` and `#reload`.

## Goals / Non-Goals

**Goals:**

- A read's result depends only on what the record holds for the key and on the default passed to that
  call, never on earlier reads.
- Keep the query profile: one lookup per key per instance, and eager-loaded metas still read in memory.

**Non-Goals:**

- Changing `cama_fetch_cache`, or the other memoized reads that use it: `render_fields`, `post_type`,
  `parents_`, `full_children_`, and `camaleon-ecommerce`'s `_get_variation_`.
- Copying or freezing the default a caller passes.

## Decisions

**Memoize the stored lookup and apply the default outside the memo.** The memoized block returns the parsed
stored value, or `''` when the key has no row. `get_meta` returns the caller's default when the memoized
value is `''`, and the memoized value otherwise.
- `''` already stands for "no value" in the read. No row, a stored `''` and `set_meta(key, '')` all take
  that one branch, with no new marker.
- Rejected, a dedicated "missing" marker object:
  - A `''` from storage or from `set_meta` would still need its own check.
  - A direct reader of the memo (`cama_get_cache`) would receive an internal object. No such reader exists
    in the engine or the surveyed repositories.
- Rejected, not memoizing misses: every repeated read of an absent key would query again. Absent keys are
  common: `thumb`, `summary`, `has_comments`, and plugin settings before their first save.
- Rejected, memoizing per default: defaults are usually fresh literals, so the memo would never hit.

**`set_meta(key, '')` reads as the default on the writing instance.**
- The alternative returns `''` there. That follows the literal "caller's value" wording, but keeps the
  split between the writing instance and a reloaded record that this change removes.
- Some reads handle their default but break on `''`: `(get_meta('screenshots') || []).map` and
  `(get_meta('front_cache_elements') || {})[...]`.
- Callers that pass `''` as the default are unaffected. Examples: `the_meta`, and the `summary` and `thumb`
  fields of the post form.
- A read without a default after `set_meta(key, '')` now returns nil on that instance. The reads of such
  metas in the engine and the surveyed repositories render the result or call `to_s`, `present?`, `blank?`
  or `||` on it.

**Return the caller's own default.** It is not copied or memoized. The option writers keep working because
they pass the options they change to `set_meta`, which memoizes that object.

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
- [A caller relied on an earlier read's default] → `camaleon-ecommerce`'s `LegacyOrder#payment_method`
  reads `get_meta("payment")[:payment_id]`.
  - On an order without a `payment` meta it raised, unless `shipping_method` had already memoized `{}`.
  - It now raises on that instance just as on a freshly loaded order.
- [Plugins outside the survey] → Breakage needs three things together: a missing meta, an in-place change
  to its default, and a later read on the same instance without `set_meta`. The 2.9.5 upgrade guide
  describes the pattern for theme and plugin developers.
- [`options` on a record with no options row returns a new hash on every call, where the first empty hash
  used to be memoized] → The option writers store their changes through `set_meta`, and no reviewed caller
  writes into that hash directly.
