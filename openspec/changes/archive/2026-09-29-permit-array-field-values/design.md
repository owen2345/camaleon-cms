# Design

## Context

See proposal.md, "Why". `set_field_values` already iterates `values` as a list when it is not a hash,
so only the permit stands between the checkboxes form and the store.

## Goals / Non-Goals

**Goals:**

- A list of scalars under `values` passes the permit, on every Rails version in the support range.

**Non-Goals:**

- Lists of non-scalars. The field-attrs partial names its inputs `values[][attr]`, which the admin
  JavaScript renames to `values[<index>][attr]`; an un-renamed submission stays dropped as today.
- The wipe a permitted slug with no usable `values` causes (`set_field_values` clears the record's
  values first). Unchanged here.
- Renaming the checkboxes inputs. Themes and plugins override field partials, and released forms
  would keep submitting the list.

## Decisions

**D1. Two filters for the one key: `{ values: {} }, { values: [] }`.** A Hash literal cannot hold the
key twice, so they are separate filters in the field's permit list. Strong parameters runs each Hash
filter on its own and assigns the key only when the value has the filter's shape, so the filter that
does not match leaves the other's result in place. Checked in the `actionpack` source of 6.1.7.10,
7.1.5.2, 7.2.2.2, 8.0.3 and 8.1.0: through 7.2 `hash_filter` branches on `EMPTY_ARRAY` and
`EMPTY_HASH` and assigns inside each branch; from 8.0 it assigns `permit_value`'s result
`unless result.nil?`, and `permit_array_of_scalars` and `permit_hash` return nil on the other shape.
The request spec runs on CI's whole Rails matrix.

- *Alternative: re-key a list by index before the permit* (what `camaleon-post-clone` PR #3 does).
  Rejected: it rewrites the request's params to fit the filter, where the filter can name the shape.
- *Alternative: `values: [[...]]` or `expect`.* Rails 8 only.

**D2. No model change.** The permitted payload's `to_h` carries the list as an Array, which
`set_field_values` writes one row per element, `term_order` following the list's order.

## Risks / Trade-offs

- [A Rails release changes how two filters for one key combine] → the request spec fails on that
  matrix entry.
