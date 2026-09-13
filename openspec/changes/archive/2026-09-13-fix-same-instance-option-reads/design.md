## Context

See proposal.md, "Why". The approach is shaped by these constraints:

- **Per-instance meta cache.**
  - `get_meta` caches each meta a record reads, including the default it returns for a missing meta.
  - `set_meta` caches the value its caller passed.
  - So on the writing instance a record's options can be an indifferent hash (parsed from storage, the
    `options` default, or kept by the option writers), a caller's plain Hash or request parameters, nil,
    or an empty string.
- **One read path.** `options`, aliased `cama_options`, returns `get_meta` for the options meta.
  `get_option` reads through `cama_options` and converts only the key, to a Symbol. The option writers
  read through it too, then convert what they got to an indifferent hash (`meta-storage-integrity`).
- **Public API.** Plugins and themes call `set_meta`, `get_meta`, `options`, `get_option` and the option
  writers directly (`docs/ai/ecosystem.md`):
  - `camaleon-ecommerce`'s coupon, tax rate, shipping method and payment method controllers pass
    `params[:options]` to `set_meta('_default', …)`, and its `Coupon` reads those options with
    `get_option`.
  - The engine reads `options[...]` directly in 30+ places (`PostType#manage_categories?`, `Site`, the
    custom field views). `_render.html.erb` falls back from `get_option` to `options[:field_key]` to
    `options['field_key']`.

## Goals / Non-Goals

**Goals:**

- One conversion, in `options`, which `get_option` and the option writers already read through, so all
  three agree with each other and with a reloaded record.
- Options that are already an indifferent hash come back as the same object: reads copy nothing, and the
  writers keep updating them in place.

**Non-Goals:**

- Any change to the per-instance meta cache, to what `set_meta` caches, or to what `get_meta` returns.

## Decisions

**Convert in `options`.** `get_option` and the writers read through `cama_options`, so a conversion there
reaches every option read and write without changing either of them.
- Rejected, a private helper for `get_option` and the writers only: the engine's own `options[...]` reads
  would keep missing a String key on the writing instance.
- Rejected, caching the converted options, in `set_meta` or on the first `options` read: `get_meta` would
  then return the copy instead of the caller's value. `meta-storage-integrity` keeps that value: its
  equality, Symbol keys, keyword splats and identity.

**Convert each value by what reading it needs.**
- An indifferent hash is returned as it is.
- Request parameters are returned as they are. They already read by either key type, and a copy would
  change the nested values a read returns.
- A plain Hash, or another Hash subclass, becomes an indifferent copy, not cached, so the caller's hash
  stays as passed. The first option write caches its copy through `set_meta`.
- Nil or an empty string becomes a new empty indifferent hash, not cached. A reloaded record already
  reads a stored empty string as no options.
- Any other value is returned as it is, so it fails in the option API as before.

**The writers keep their conversion.** After `options`, it only meets the values `options` returns as
they are: request parameters, and values that are not a hash. It fails on them as before.
- Rejected, the writers updating whatever `options` returns: a write would change a stored string in
  place with `String#[]=` instead of failing.

**`get_meta`'s default cache is left for its own change.** For every meta, the default the first reader
asked for is what later reads on the instance return. Fixing it changes what the `get_meta` callers get
back: about 100 in the engine and in the plugin, theme and host repositories checked, and more elsewhere.
That needs its own review. The callers found that change a returned default in place pass it to
`set_meta` afterwards, so they would keep working. Meanwhile `options` treating nil as no options covers
what the defect does to options.

## Risks / Trade-offs

- [After `set_meta` with a plain Hash, nil or an empty string, `options` on that instance no longer
  returns the caller's value] → `get_meta` still does. A write into the hash `options` returns, made
  without `set_meta`, no longer reaches a caller's plain Hash. No code in the engine or in the plugin,
  theme and host repositories checked does that.
- [A caller's plain Hash is copied on each `options` read until an option is written] → Only options
  passed to `set_meta` as a plain Hash take that path.
- [Options stored as null now read as empty options and accept writes, where `options` returned nil and
  `get_option` and the writers raised] → A record with no options row already reads and writes that way.
- [The writers still fail on request parameters a caller passed to `set_meta`, which a reloaded record
  accepts] → No consumer found writes options after passing parameters. `camaleon-ecommerce` redirects
  right after its `set_meta`.
