## Context

See `proposal.md`, "Why". `set_field_values` keeps the stored pairs of slug and value before it
deletes the rows. It called `unfiltered_value!` on a new row that matched a pair, so the markup gate
skipped it. `ContentShortcodeGate#cama_shortcode_attr_gated?` checks `new_record?`, which is true
for each new row, and it did not read that flag.

## Decisions

**D1. A flag for an already stored value, `previously_stored!`.** `set_field_values` sets it in place
of `unfiltered_value!`. The markup gate and the shortcode gate read it.

- `unfiltered_value!` is the opt-out of trusted server code. `Post#unfiltered_content!` does not
  skip the shortcode gate, so `unfiltered_value!` does not skip it either.
- The flag has a reader and a bang enabler, and no writer, so mass assignment cannot set it.
- The flag is only for the value that it marks. `unfiltered_value!` stays on the row for its life.
  This flag is false again when the value of the row changes, and a copy (`dup`) does not get it.
  Both gates then check a changed value, also on a row that `set_field_values` left in the loaded
  association.

**D2. The concern asks the model with `cama_gate_unchanged?(attr)`.** The default is false.
`CustomFieldsRelationship` returns the flag for `value`. Post content and a taxonomy description
keep the check of `new_record?` and the change of the attribute.

**D3. The match ignores the group number, as the markup gate does.** An editor can copy a stored
value into a new group of the same field. It is the same text on the same page.

Alternatives:

- The shortcode gate reads `unfiltered_value`. The opt-out of server code then skips the gate too.
  Rejected.
- `set_field_values` updates an unchanged row in place. It changes the row ids, the order, the
  delete of removed values and the callbacks that plugins can read. Rejected.
- Keep the check, and document it. An editor stays locked out of such a post. Rejected.

The maintainer chose D1 in a PR of its own on 2026-11-18.

## Risks / Trade-offs

- [A shortcode value that a trusted author stored stays on a later save of an editor.] → The
  editor did not write it, and the page shows the same text as before.

## Migration Plan

No data migration. Stored values do not change.
