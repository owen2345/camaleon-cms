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

**D7. The two writers refuse a text with a broken encoding before they build the row.** The
maintainer chose it on 2026-10-04. The integer cast of Rails raises `ArgumentError` for such a text
before the validation runs. The lookup in `set_field_value` raises the same error. No request can
send such a text, because Rails answers it with a 400. Only Ruby code can pass it. A direct
`custom_field_values.create!` keeps the `ArgumentError` of Rails.

The writers refuse a text in an encoding that is not ASCII-compatible (UTF-16, UTF-7) in the same
way. The lookup, the digits check or the integer cast raised an encoding error for that text. The
row refuses a text in UTF-16 or UTF-32 in its validation. A direct write of a row keeps the error of
Rails for a text in a dummy encoding (UTF-7): the integer cast raises before the validation runs.

## Risks / Trade-offs

- A plugin or theme that passes a negative number, a Float or a text that is not digits to
  `set_field_value` gets `ActiveRecord::RecordInvalid`. No surveyed consumer does.
- Outside `AdminController` a `RecordInvalid` is not rescued. No core caller outside the admin takes
  the group number from a request.
