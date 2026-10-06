# Design

## Terms

- A **value** is a custom-field value, a record of `CamaleonCms::CustomFieldsRelationship`.
- An author can add a repeatable field group (`is_repeat`) to a post several times, for example a
  "Slide" group, one time for each slide. The **group number** of a value is the index of the copy
  that the value belongs to: 0 for the first copy.
- A group number is **invalid** when it is not nil, not an Integer from 0 to 2147483647 and not a
  String of 1 to 16 digits with such a number.
- The **group number error** is `ActiveRecord::RecordInvalid` with a message that names the field.
- The **two methods** are `set_field_value` and `set_field_values`. Each one deletes stored values
  and then creates the new values.
- An **uncastable String** is a String in an invalid encoding, or in an encoding that is not
  ASCII-compatible (UTF-16, UTF-7). Rails raises an encoding error for it in the integer cast
  (an invalid encoding, UTF-7) or in a lookup (UTF-16).

## Context

See proposal.md, "Why". Each write path stores a value through the model: `set_field_values`,
`set_field_value` and a direct `custom_field_values.create!`. So a validation in the model covers
each path.

## Goals / Non-Goals

**Goals:**

- An admin save with an invalid group number does not answer with a 500.
- Such a save stores no new value and removes no stored value. D9 and D13 name the exceptions.
- The same rule holds on SQLite, PostgreSQL and MySQL.

**Non-Goals:**

- A repair of stored values. A stored value with a negative group number, or with none, stays.
- The readers (`get_field_values`, `get_fields_grouped`). They get the group number from theme
  code, not from a request.
- The response of the draft save to an invalid value.

## Decisions

The maintainer made each decision on 2026-10-04 or 2026-10-05. "Left as is" marks a behavior that
the maintainer chose to keep.

**D1. A validation in the value model.** It covers each caller. The save of the values rolls back,
and the `RecordInvalid` handler of `AdminController` shows the message. Rejected:

- An error in `cama_permitted_field_options`. Plugins and themes that pass raw params to
  `set_field_values` do not call the helper, so they keep the 500.
- A clamp of the number to the valid range. A clamp changes the input with no notice, which
  `docs/security/permissions.md` does not allow.
- A `rescue_from ActiveModel::RangeError` in `AdminController`. It hides each range error of the
  admin, also one with another cause, and it does not cover the `NoMethodError`.

**D2. The validation reads the group number before the type cast.** The cast changes an invalid
group number to a valid one: `true` becomes 1, and `false` and `'abc'` become 0. A String has a
maximum of 16 bytes, because Rails 8.1.4 casts only the first 16 bytes. Without the maximum, a
String of 17 zeros and a 7 passed as the number 7, and Rails stored 0. Rejected: a maximum of 10
digits, the length of 2147483647.

**D3. The largest valid number is 2147483647 on each database.** PostgreSQL and MySQL store the
column in 4 bytes. A group number that is valid on SQLite must be valid there too. The attribute
type (D7) also has the 4-byte range where the column can hold a larger integer (SQLite, a `bigint`
column). For a number n outside -2147483648..2147483647 in such a column:

- `where(group_number: n)` and `find_by(group_number: n)` find no row. An SQL string is not
  checked.
- A write of n that skips the validation raises `ActiveModel::RangeError`.
- A call that serializes each attribute of a stored row with n raises that error too:
  `attributes_for_database`, and `Marshal.dump` or a cache write with the marshalling format 7.1.
  On Rails 7.0 or earlier, each save of such a row raises it.

The admin form sends the index of the group, so only custom code can store such a number.
Rejected: a type with the range of the column.

**D4. A new value is always validated. A stored value is validated only when its group number
changes.** Rails compares the cast values to find a change. `'0abc'` casts to 0, which is the
default, so Rails sees no change on a new value. For this reason, a new value is always validated.
A stored value with a negative number stays valid until its number changes, so
`update_field_value` can still change its content.

**D5. Nil is valid, and `set_field_values` reads an absent or empty group number as group 0.**
`camaleon_export_import` passes the stored group number of an exported value, which can be nil. A
form can send "no group number" only as an empty String, and the Camaleon forms always send a
number.

**D6. `set_field_values` no longer changes a negative number to 0.** That change was a transform of
the input with no notice.

**D7. An uncastable String is invalid.** Before this change, the caller did not get the group number
error. Rails raised an encoding error, or, on Rails 7.1 and later, stored NULL for a UTF-16 String. The group number now has its own integer
type, `GroupNumberType`. The type returns nil for an uncastable String. The value keeps the String,
and the validation adds the group number error.

- A lookup with such a String finds no row. So `find_or_create_by!` creates a value, which gets the
  group number error.
- `update_attribute` and `save(validate: false)` skip the validation. A `before_save` callback
  stops them with the group number error. Without it, they store NULL. For each other invalid
  group number, those two saves run no check, as before.
- `update_column`, `update_all` with a hash and `insert_all` run no validation and no callback.
  They store NULL for such a String (left as is). A type can only change one value to another
  value, so it cannot keep the number that the row held before.
- No request can send such a String to the model. Rails answers a param in an invalid encoding with
  a 400, and a multipart part in an encoding that is not ASCII-compatible stops the request before
  the controller.

The type replaced three earlier guards of this change: a writer method, a `write_attribute`
override and a check before the lookup of `set_field_value`.

**D8. A copy of a value keeps the group number as the caller gave it.** Rails copies (`dup`) each
attribute after the cast, so the copy of an invalid value was valid. `initialize_dup` now gives the
copy the group number before the cast. A copy is a new value, so it is always validated (D4). The
copy of a stored value with a negative number is then invalid (left as is). The same applies to a
number above 2147483647 in a column for a larger integer. The master branch of
`camaleon-post-clone` copies the values of a post, so its clone of a post with such a value raises
`ActiveRecord::RecordInvalid`.

**D9. The two methods ask Rails for a savepoint (`requires_new`).** Before, their transaction
joined an open transaction of the caller. A caller that rescued the error inside its transaction
and committed kept the delete of the failed call, and the stored values were lost. Each savepoint
costs two statements.

- **The restart of Rails.** Rails 7.2 and 8.1 open no savepoint before the first statement in the
  joinable transaction of the caller. After a failed call, they roll back the whole transaction
  and begin it again. On SQLite with Rails 8.1, another connection can take the write lock between
  the ROLLBACK and the BEGIN. The caller then gets `InstrumentationNotStartedError` in place of
  the group number error. So the two methods run `SELECT 1` in an open transaction of the caller
  first, with the query cache off, and Rails opens the savepoint. Rejected: a note on the restart.
- **A pool with an isolation level.** On Rails 8.1, `ActiveRecord.with_transaction_isolation_level`
  and `Model.with_pool_transaction_isolation_level` give the connection pool an isolation level.
  Rails then raises an error for a savepoint, and the post save of the admin failed there. So the
  two methods ask for no savepoint, and run no `SELECT 1`, while `pool_transaction_isolation_level`
  has a value. Inside a transaction of the caller, a failed call then rolls back nothing by itself.
  A caller that rescues the error and commits loses the values that the call deleted, as in the
  release before. Rejected: a note on the limit.
- **PostgreSQL.** More than 64 savepoints that write in one transaction overflow the subtransaction
  cache of the session.
- **The specs.** The examples stub `pool_transaction_isolation_level` (left as is). Under the real
  API, Rails raises an error for each model transaction inside the transaction of an example.
  Probes with the real API back these notes.

**D10. The two methods reset the association after a failed call.** The rollback restores the
database. But the `custom_field_values` association of the record still holds the unsaved values of
the call. The record read those values, and its next save failed or stored some of them.

- A failed call is an exception of any class, a `throw` or `ActiveRecord::Rollback`, also one from
  a commit callback. A timeout of the caller can stop a method with an exception that is not a
  `StandardError`, or with a `throw`. So the reset is in an `ensure` block. After a `throw`, Rails
  can commit the work that the call did before it.
- The reset removes each unsaved value of the association. So the two methods put back the unsaved
  values that the caller built before the call. One case differs: a `set_field_values` call that
  succeeds removes them, because its delete empties the association.
- A callback of a value can raise `ActiveRecord::Rollback` before Rails stores the value. Rails
  ends that save with no error, so the method goes on, and the unsaved value stays in the
  association (left as is). The code before this change did the same, and no surveyed consumer adds
  such a callback.

Rejected: a note that tells the caller to reload the record.

**D11. `set_field_value` validates the group number before its delete.** A call with an empty list
of values creates no value, so nothing validated the group number. The delete of the call casts
the number, so the call deleted the stored values of another group: `'1abc'` and `true` were group
1. `set_field_value` now validates the number on a value that it does not store. Rejected: a type
that reads each invalid group number as no number in a lookup, which changes the readers.

**D12. `cama_permitted_field_options` keeps a group number that is a list or a hash.** Rails drops
a list or a hash for a scalar filter, and `set_field_values` reads an absent number as group 0. So
the save stored the value in group 0 with no error. The filter `{ group_number: [{}] }` keeps a
list or a hash with its content removed, and the value is then invalid. Rejected: a note in the
requirement that the permit drops such a number.

**D13. The transaction stays on the connection pool of `ActiveRecord::Base`** (left as is). A host
can put the Camaleon models on a pool of their own (`CamaleonRecord.establish_connection`). The
transaction then does not cover the values, and a failed call does not roll back its delete. The
code before this change did the same, and the post save of the admin uses the same pool. Rejected:
a transaction on the class of the values.

**D14. `set_field_values` validates the group number of an entry with no values.** Before, the
method skipped such an entry before it read the group number, so the save passed. It now validates
the number on a value that it does not store, as `set_field_value` does (D11). Rejected: a note on
the skip.

**D15. `set_field_value` removes the values that it deletes from a loaded association.** An SQL
DELETE does not change a loaded `custom_field_values` association, and `get_field_values` reads a
loaded association. So the record read the deleted values and the new values. The master branch
has the same defect. For a loaded association, the method now reads the ids of the stored values
before the DELETE and removes those values from the association after it. That is one more query.
`set_field_values` needs no such step, because its delete empties the association. Rejected: a
reset of the association after each call, which removes the unsaved values of the caller.

## Risks / Trade-offs

- A plugin or theme that passes a negative number, a Float or a String that is not digits to
  `set_field_value` gets `ActiveRecord::RecordInvalid`. No surveyed consumer does.
- Outside `AdminController`, no code rescues that `RecordInvalid`. No Camaleon caller outside the
  admin takes the group number from a request.
