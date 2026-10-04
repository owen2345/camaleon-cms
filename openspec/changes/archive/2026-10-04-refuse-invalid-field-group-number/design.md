# Design

## Context

See proposal.md, "Why". The value row is the last point before the database, and each write path
reaches it: `set_field_values`, `set_field_value` and a direct `custom_field_values.create!`.

## Goals / Non-Goals

**Goals:**

- No admin save answers a group number in the request with a 500.
- A refused group number writes nothing and removes nothing.
- The same rule holds on SQLite, PostgreSQL and MySQL.

**Non-Goals:**

- A repair of stored rows. A row with a negative or nil group number stays as it is.
- The readers (`get_field_values`, `get_fields_grouped`). They take the group number from theme code.
- The response of the draft save to a refused value row. It stays the `AdminController` rescue.

## Decisions

**D1. A validation on the value row.** The maintainer chose it on 2026-10-04 from four remedies.

- A refusal in the permit helper drops the slug entry. `set_field_values` deletes each stored value
  first, so the dropped slug loses its values when other entries stay. The plugins and themes that
  pass raw params to `set_field_values` skip the permit and keep the 500.
- A clamp is a silent transform, which `docs/security/permissions.md` does not allow.
- A `rescue_from ActiveModel::RangeError` in `AdminController` hides each range error in the admin
  and does not cover the `NoMethodError`.

The validation covers each caller, rolls the save back, and reaches the existing `RecordInvalid`
rescue, which shows the message.

**D2. The validation reads the value before the cast.** The integer cast makes `true` 1, `false` 0
and `'abc'` 0, so a check of the cast value accepts them. The numericality validator of Rails falls
back to the cast value for `false`. The check accepts the given value only when its text is ASCII
digits and the number is not above 2147483647. An Integer, and a String of digits, pass.

**D3. The bound is 2147483647 on each database.** SQLite stores an 8-byte integer, so the save of
2147483648 does not raise there. A value stored on SQLite must also be valid on PostgreSQL and MySQL.

**D4. A new row is always checked. A stored row is checked when the number changes.** A change check
alone skips a value that casts to the default (`'0abc'` casts to 0). A stored row that holds a
negative number stays valid, so `update_field_value` can still change its value.

**D5. Nil passes, and `set_field_values` maps an absent or empty number to 0.** `camaleon_export_import`
passes the number of an exported row, which can be nil. A form can express "no number" only as an
empty text, and the core forms always send a number.

**D6. `set_field_values` no longer clamps a negative number to 0.** The clamp was a transform. The
row refuses the number, as the remedy rule asks.

**D7. The row refuses a text that the integer cast cannot read.** The maintainer chose it on
2026-10-04. The integer type of Rails raises its own error for a text with a broken encoding, or in
an encoding that is not ASCII-compatible (UTF-16, UTF-7), before the validation runs.

The group number has its own integer type, `GroupNumberType`. The maintainer chose the type on
2026-10-04. The type reads such a text as no number, and the row keeps the text. The validation
reads the text and refuses it. The type covers each write to the attribute (`group_number=`, `[]=`,
`write_attribute`) and each lookup. No request can send such a text, because Rails answers it with
a 400. Only Ruby code can pass it.

A lookup with such a text finds no row, as a lookup with a text that is not a number does in Rails.
`set_field_value` and `find_or_create_by!` look the number up first. They reach the row after the
lookup, and the row gives the refusal. The type replaced three guards: a writer and a
`write_attribute` override that gave the cast a Symbol, and a check before the lookup of
`set_field_value`. With those guards, `find_or_create_by!` raised the error of Rails.

A save that skips the validation (`update_attribute`, `save(validate: false)`) stored no number for
such a text. The maintainer chose a guard on 2026-10-04. A `before_save` callback raises the
refusal: `save` returns false, and `save!` raises the refusal. `update_column`, `update_all` and
`insert_all` skip the validation and the callbacks. They store no group number for such a text.

The maintainer chose to leave those three writes on 2026-10-04. Before, Rails raised its own error
there. The type only maps a value, so it cannot keep the stored number. A refusal is possible for
`update_column` only: `update_all` and `insert_all` cast the value first, with the cast that the row
uses. Rails gives those writes no check for other values: `'abc'` becomes NULL or 0.

**D8. A copy of a row keeps the given group number.** A copy (`dup`) takes the cast value of each
attribute. The cast hides a group number that the row refuses: `'abc'` becomes 0, `true` becomes 1,
and the text of D7 becomes nil. The copy was valid, and its save stored that number.
`initialize_dup` gives the copy the group number as the caller gave it to the original row.

**D9. The writers open a savepoint.** The maintainer chose it on 2026-10-04. `set_field_value` and
`set_field_values` delete stored values before they create the rows. Their transaction joined a
transaction of the caller, so a caller that rescued the refusal there and committed kept the delete.
The writers call `transaction(requires_new: true)`. The savepoint covers each refusal of a row, the
refusal of the value gate included.

**D10. The writers reset the association after an error.** The maintainer chose it on 2026-10-04.
The rollback restores the database. The record still holds the rows of the call in its
`custom_field_values` association. After a refused `set_field_values`, the record read those rows,
and its next save failed. After a refused list of `set_field_value`, the next save of the record
stored the rows before the refused value. Each writer resets the association when its transaction
raises an error of any class, so the record reads the stored values again.

The reset also covers a refusal of the value gate. The other remedy was a note that tells the
caller to reload the record.

## Risks / Trade-offs

- A plugin or theme that passes a negative number, a Float or a text that is not digits to
  `set_field_value` gets `ActiveRecord::RecordInvalid`. No surveyed consumer does.
- Outside `AdminController` a `RecordInvalid` is not rescued. No core caller outside the admin takes
  the group number from a request.
