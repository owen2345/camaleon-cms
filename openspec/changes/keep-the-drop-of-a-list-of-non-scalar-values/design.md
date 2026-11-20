# Design

## Context

`cama_permitted_field_options` keeps `values` as a hash keyed by index or as a list of scalars
(`permit-array-field-values`, D1). A list that holds a hash matches neither filter, so the entry
keeps no values.

The `field_attrs` partial names its inputs `field_options[<slug>][values][][attr]` and
`field_options[<slug>][values][][value]`. Rack reads those names as a list of hashes,
`[{ 'attr' => 'a', 'value' => 'b' }]`. On 2026-11-20 the maintainer asked who can send that list to
an admin save.

## Goals / Non-Goals

**Goals:**

- The code and the requirement say that the drop is the design, and why.

**Non-Goals:**

- A new `values` shape in the permit.
- The stored values that an entry with no usable `values` removes. `set_field_values` deletes the
  values of the record before it writes. Unchanged here.

## Decisions

**D1. The permit keeps the drop of a list of non-scalars.** The maintainer decided this on
2026-11-20, because the survey found no sender:

- **A browser with the admin JavaScript.** `build_custom_field_group` adds the group index to each
  name. `cama_build_custom_field` then changes the first `[]` of the name to the index of the value.
  Both run in one synchronous call. So the browser sends `field_options[0][<slug>][values][0][attr]`,
  a hash keyed by index.
- **A browser without the admin JavaScript.** The partial `custom_fields/_render` names each input
  without a group index: `field_options[<slug>][values][][attr]`. The permit reads a group only under
  a key of digits, so it drops the full payload, for each kind of field. The save then writes nothing
  and removes nothing (requirement "A submission carrying no registered slug leaves stored values
  intact"). A new `values` shape does not help this form.
- **Plugins and themes.** Each surveyed consumer that renders `custom_fields/_render` loads the admin
  JavaScript. `camaleon-spree` renders the partial in the Spree admin, and its own manifest requires
  `camaleon_cms/admin/_custom_fields`. No surveyed field partial has the class
  `cama_skip_cf_rename_multiple`, which stops the rename of `[]`.
- **The other fields of Camaleon.** Of the 24 partials under `custom_fields/fields/`, only
  `_field_attrs` has a key after `values][]`.
- **Specs and clients.** No spec of Camaleon or of a surveyed repository posts the list, except the
  two examples that pin the drop. A client can send `values[0][attr]`, the shape that the comment of
  `set_field_values` gives.

The alternatives:

- *Alternative: keep a list of hashes with the keys `attr` and `value`.* Rejected: no sender needs
  it, and two keys are too few. The `my_slider` field of `cama-ecommerce-theme`,
  `camaleon-cms-efashion` and the `e_shop` theme of `camaleon_website` sends the keys `image`,
  `title` and `descr`. In two of those themes, the field also sends the key `product`.
- *Alternative: keep a list of hashes with any key.* Rejected: no sender needs it, and it makes the
  permit wider for each field.

**D2. A later third filter for `values` needs a check of each shape.** Strong parameters runs each
Hash filter alone, and a filter that gives a result replaces the result of the filter before it.
On Rails 8.1.4.1, `{ values: [:attr, :value] }` after the two filters of the permit gives these
results:

| `values` | Result |
|---|---|
| `{ '0' => 'text' }` | `{}`, where the two filters keep the hash |
| `['1', '2']` | `[]`, where the two filters keep the list |
| `[{ 'attr' => 'a', 'value' => 'b' }]` | The list, as sent |
| `{ '0' => { 'attr' => 'a', 'value' => 'b' } }` | The hash, as sent |

So that filter removes the values of each field that is not a `field_attrs` field. A change that adds
a shape must read the hash of hashes, the hash of scalars and the two lists on each supported Rails
version.

## Risks / Trade-offs

- [A plugin or a theme starts to send `values[][<key>]` to a save that uses the permit] → the save
  stores nothing for that field. The request spec and the scenario "A list of non-scalars is dropped"
  describe that result.
