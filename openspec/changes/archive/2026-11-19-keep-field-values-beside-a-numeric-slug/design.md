# Design

## Context

See `proposal.md`, "Why". The payload has three levels:

| Level | Keys | Who chooses the keys |
|---|---|---|
| `field_options` | group indexes, digits only | the admin JavaScript |
| group | field slugs | the role that defines the fields |
| field entry | `id`, `group_number`, `values` | Camaleon |

Strong parameters reads a hash as nested attributes when two conditions hold. The hash holds a
numeric key with a hash value, and a filter of a nested level permits the hash. The hash that
`permit` is called on is never read that way. From Rails 7.0, a filter that names a numeric key
prevents this read (`specify_numeric_keys?`). Rails 6.1 has no such test.

The helper called `permit` on `field_options` with a nested filter for the groups and for the
entries. So Rails read a group, and an entry, as nested attributes when they held a numeric key with
a hash value.

A pure Ruby harness ran the current helper and each remedy on 23 payload shapes. It ran on
`actionpack` 7.1.6, 7.2.3.1 and 8.1.4.1, with `action_on_unpermitted_parameters` at `false` and at
`:raise`. A fourth run used 8.1.4.1 with `specify_numeric_keys?` set to answer `false`. That run
gives the read of Rails 6.1, whose `each_element` has no such test (source of 6.1.7.10).

## Goals / Non-Goals

**Goals:**

- A numeric slug, in the scope of the permit or outside it, does not remove the other fields of its
  group.
- The same result on each Rails version from 6.1 to 8.1.
- For each payload that an admin form sends, the helper gives the same result as before.

**Non-Goals:**

- The values that a save removes when an entry has no usable `values`. `set_field_values` deletes the
  stored values of the record before it writes. A follow-up decides that policy ("Stop malformed
  custom-field values wiping stored ones").
- The fields of the post itself and of its categories, which the post save does not store.
- `permitted_fields` and `permitted_field_options` of the custom field group form. Their entries have
  fixed keys, and a role needs the `custom_fields` permission to post them.

## Decisions

**D1. The helper permits each field entry on its own.** The maintainer chose this remedy on
2026-11-19. The helper reads `field_options` itself. A group is a value of a key of digits only that
is `ActionController::Parameters`. An entry is the value of an allowed slug in a group, when that
value is `ActionController::Parameters`.

The helper calls `permit` on each entry with the filter of its fixed keys. So Rails never gets a
level whose keys a user chooses, and it reads no group as nested attributes. The entries of a group
keep the order of the allowed slugs, and the result keeps indifferent access, as before.

The post-permit cleanup goes away: the `select!` lines, the `reject!` line and the
`field_ids.key?(slug)` test. The walk makes no group that is not a Hash, no entry of a slug that is
not allowed and no empty group. The id of each entry is still held to the fields of its slug.

- *Alternative A: `group.permit(group_filter)` for each group.* Smallest change. It also gives the
  goals. Rejected: Rails still reads an entry with a numeric key as nested attributes, so the entry
  loses its values. With `:raise`, a host also gets an error for `field_options[0][0][<slug>]`.
- *Alternative B: slice each group to the allowed slugs, then the one nested permit.* Rejected: on
  Rails 6.1 a registered numeric slug still removes the other fields of its group.

**D2. An entry keeps its values beside a numeric key.** `permit` on the entry itself drops a numeric
key with a hash value (`field_options[0][subtitle][0][id]`) as it drops each unknown key. The entry
keeps its `id`, group number and values. Before, Rails kept only the numeric key, and the save
removed the stored values of the record. Only a forged request sends such a key.

**D3. The helper reports no unpermitted parameter for a group or a slug that it drops (intended).**
The post editor posts the fields of the post itself and of its categories in each save, and the post
save drops them on purpose. Before, Rails reported such a slug, a top-level key that is not numeric
and a group that is a scalar. With `action_on_unpermitted_parameters = :raise`, each of them raised
`ActionController::UnpermittedParameters`, so a post save with such a field raised.

Now none of them is reported. An unknown key inside an entry is still reported, because `permit` runs on the entry.
With `:raise`, a numeric key inside an entry now raises too.

**D4. No spec runs on Rails 6.1.** CI starts at Rails 7.1, where a filter that names a numeric slug
already prevents the nested read. So the example for a registered numeric slug passes before and
after the change on CI. The harness run without `specify_numeric_keys?` shows the Rails 6.1 result:
the current helper gives `{"0"=>{"2020"=>{}}}`, and D1 gives each entry of the group.

## Risks / Trade-offs

- [A developer no longer sees a dropped slug as "Unpermitted parameter" in the development log] → The
  upgrade note names the scope of the permit. `cama_custom_field_allowed_slugs` gives the allowed
  slugs.
- [The cost of a large payload changes] → The cost does not rise. The measure used `actionpack`
  8.1.4.1 and 4096 groups. With 50 fields in each group, the permit took 19.0 s before and 17.1 s
  after. With one field in each group, it took 0.54 s before and 0.45 s after. The results were equal.
- [A Rails release changes `permit` for the keys of an entry] → The spec of the helper fails on that
  Rails version. It pins each shape of `values` and of the group number.
