## Context

See proposal.md, "Why". The approach is shaped by these constraints:

- **Per-instance meta cache.**
  - `get_meta` caches each meta a record reads, including the default it returns for a missing meta.
  - `set_meta` caches the value its caller passed.
  - So on the writing instance a record's options can be an indifferent hash (parsed from storage or
    kept by the option writers), a caller's plain Hash, request parameters or JSON string, nil, or an
    empty string.
- **One read path.** `options`, aliased `cama_options`, returns `get_meta` for the options meta.
  `get_option` reads through `cama_options` and converts only the key, to a Symbol. The option writers
  read through it too and update what they get in place (`meta-storage-integrity`).
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
  three agree with each other and with a freshly loaded record.
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
- Request parameters become an indifferent copy through `to_unsafe_h`, nested parameters included, so the
  writing instance reads the shape a reload parses: `to_h` works, `==` compares with a loaded record's
  options, and a nested option is a hash. `to_unsafe_h` leaves the caller's parameters unpermitted, where
  `PluginRoutes.fixActionParameter` would permit them in place. The copy is not cached, as a plain Hash's.
  - Rejected, returning them as they are: request parameters are neither a Hash nor Enumerable, `to_h`
    raises on unpermitted parameters, a nested read returns parameters where a reload returns a hash, and
    the writers cannot convert them.
- A JSON string is parsed as `get_meta` parses the row it stored, a repeated key tolerated the same way,
  and the object it holds is copied as a plain Hash is; a string that holds no JSON object reads as no
  options. `PostType#set_meta` names the string as one form the options row arrives in, and the merged
  code read it as no options on the writing instance while a reload parsed it, so the next option write
  replaced the row.
- A plain Hash, or another Hash subclass, becomes an indifferent copy, not cached, so the caller's hash
  stays as passed. The first option write caches its copy through `set_meta`. The copy is built with
  `HashWithIndifferentAccess.new.update`, which leaves a Hash default or default proc behind, where
  `with_indifferent_access` copies both: a missing option reads nil, as after a reload, and a default
  proc that stores what it returns cannot add keys the next write would store.
- Nil, an empty string or a missing options row becomes a new empty indifferent hash on each read, not
  cached, until the first option write caches the writer's hash through `set_meta`. `options` asks
  `get_meta` for no default, so a record with no options row reads the same fresh hash whether or not
  `get_meta` was asked for the options first. A freshly loaded record already reads a stored empty string
  as no options.
  - Rejected, passing an empty indifferent hash as the `get_meta` default: `get_meta` memoized it and
    `options` returned it by identity, so a change made to it without an option writer was read back and
    stored by the next write, where a record holding a plain Hash or nil dropped the same change.
- Any other value, a stored row that is not a JSON object included, reads as empty options, as the
  options-row requirement has had it since #1297.

**The writers update what `options` returns.** It is an indifferent hash for every value, so `set_option`,
`set_options` and `delete_option` update it in place and store it with `set_meta`, which caches it. The
private helper that converted it again is gone: after request parameters it raised `NoMethodError`, where
2.9.4 wrote into the parameters through `Parameters#[]=` and the merged options-row rule (#1297) read
them as no options and replaced the row with the written key.
- Rejected, keeping the helper as a guard against writing into a value `options` returns as it is: no
  such value is left, `options` returns nothing but an indifferent hash.

**`get_meta`'s default cache is left for its own change.** For every meta, the default the first reader
asked for is what later reads on the instance return. Fixing it changes what the `get_meta` callers get
back: about 100 in the engine and in the plugin, theme and host repositories checked, and more elsewhere.
That needs its own review. The callers found that change a returned default in place pass it to
`set_meta` afterwards, so they would keep working. Meanwhile `options` asks for no default and treats nil
as no options, so the defect does not reach option reads.

## Risks / Trade-offs

- [After `set_meta` with a plain Hash, a JSON string, nil or an empty string, `options` on that instance no
  longer returns the caller's value] → `get_meta` still does. A write into the hash `options` returns, made
  without `set_meta`, no longer reaches a caller's plain Hash. No code in the engine or in the plugin,
  theme and host repositories checked does that.
- [A caller's plain Hash is copied on each `options` read until an option is written] → Only options
  passed to `set_meta` as a plain Hash take that path.
- [Options stored as null now read as empty options and accept writes, where `options` returned nil and
  `get_option` and the writers raised] → A record with no options row already reads and writes that way.
- [Request parameters are copied on each `options` read until an option is written] → `camaleon-ecommerce`
  redirects right after its `set_meta`; the engine's own records read parsed options.
