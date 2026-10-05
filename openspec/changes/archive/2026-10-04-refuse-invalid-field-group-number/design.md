# Design

## Context

See proposal.md, "Why". The value row is the last point before the database, and each write path
reaches it: `set_field_values`, `set_field_value` and a direct `custom_field_values.create!`.

## Goals / Non-Goals

**Goals:**

- No admin save answers a group number in the request with a 500.
- A refused group number stores no value row and removes no stored value.
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

The validation covers each caller, rolls the write of the values back, and reaches the existing
`RecordInvalid` rescue, which shows the message.

**D2. The validation reads the value before the cast.** The integer cast makes `true` 1, `false` 0
and `'abc'` 0, so a check of the cast value accepts them. The numericality validator of Rails falls
back to the cast value for `false`. The check accepts the given value only when its text is ASCII
digits and the number is not above 2147483647. An Integer, and a String of digits, pass.

**D3. The bound is 2147483647 on each database.** SQLite stores an 8-byte integer, so the save of
2147483648 does not raise there. A value stored on SQLite must also be valid on PostgreSQL and MySQL.

The type of the group number (D7) has the same 4-byte range on each database. Some databases hold a
wider integer in the column: SQLite, and a host whose column is `bigint`. There,
`where(group_number: n)` and `find_by(group_number: n)` find no row for a number n above 2147483647
or below -2147483648. A write that skips the validation raises `ActiveModel::RangeError` for that
number: `update_attribute`, `save(validate: false)`, `update_column`, `update_all` with a hash and
`insert_all`. An SQL text skips the type. On those databases, a condition with it finds the row, and
`update_all` with it stores the number. Before, those databases found and stored such a
number. On Rails 7.0 or earlier, each save of a row that holds such a number raises that error:
those versions serialize each attribute of the row again after a save.

The maintainer chose to leave that range on 2026-10-04. A type that takes the range of the column is
possible. The admin form sends the index of the group, so only custom code can store such a number.

**D4. A new row is always checked. A stored row is checked when the number changes.** A change check
alone skips a value that casts to the default (`'0abc'` casts to 0). A stored row that holds a
negative number stays valid, so `update_field_value` can still change its value.

**D5. Nil passes, and `set_field_values` maps an absent or empty number to 0.** `camaleon_export_import`
passes the number of an exported row, which can be nil. A form can express "no number" only as an
empty text, and the core forms always send a number. An empty text in an encoding that is not
ASCII-compatible is the text of D7, and the row refuses it.

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
`find_or_create_by!` looks the number up first. It reaches the row after the lookup, and the row
gives the refusal. `set_field_value` did the same until D11: it checks the number before its lookup
now. The type replaced three guards: a writer and a
`write_attribute` override that gave the cast a Symbol, and a check before the lookup of
`set_field_value`. With those guards, `find_or_create_by!` raised the error of Rails.

A save that skips the validation (`update_attribute`, `save(validate: false)`) stored no number for
such a text. The maintainer chose a guard on 2026-10-04. A `before_save` callback raises the
refusal: `save` returns false, and `save!` raises the refusal. For another refused number, such a
save runs no check of the row: it stores what the integer cast of the type gives, or it raises an
error for a value that the type cannot store. `update_column`, `update_all` with a hash and
`insert_all` skip the validation and the callbacks. They store no group number for such a text.

The maintainer chose to leave those three writes on 2026-10-04. Before, Rails raised its own error
there in most cases. In the other cases it stored the digits at the start of the text, or no
number. The type only maps a value, so it cannot keep the stored number. A refusal is possible for
`update_column` only: `update_all` and `insert_all` cast the value first, with the cast that the row
uses. Rails gives those writes no check for other values: `'abc'` becomes NULL or 0.

**D8. A copy of a row keeps the given group number.** A copy (`dup`) takes the cast value of each
attribute. The cast hides a group number that the row refuses: `'abc'` becomes 0, `true` becomes 1,
and the text of D7 becomes nil. The copy was valid, and its save stored that number.
`initialize_dup` gives the copy the group number as the caller gave it to the original row.

A copy is a new row, so the validation checks its number (D4). The copy of a stored row that holds
a number outside the range gets the refusal. Such a number is negative, or above 2147483647 in a
wider column. Before, the copy stored that number. The maintainer chose to leave that refusal on
2026-10-04.

The master branch of `camaleon-post-clone` copies the value rows of a post, so its clone of a post
with such a row raises `ActiveRecord::RecordInvalid`. Only custom code stored such a number: the
admin form sends the index of the group.

**D9. The writers open a savepoint.** The maintainer chose it on 2026-10-04. `set_field_value` and
`set_field_values` delete stored values before they create the rows. Their transaction joined a
transaction of the caller, so a caller that rescued the refusal there and committed kept the delete.
The writers call `transaction(requires_new: true)`, with the one exception of the next paragraph.
The savepoint covers each refusal of a row, the refusal of the value gate included. Each savepoint
costs two statements. On PostgreSQL, more than 64 savepoints that write in one transaction overflow
the subtransaction cache of the session.

Rails 8.1 has `ActiveRecord.with_transaction_isolation_level`. It gives the pool an isolation level
inside each transaction that a model class or a record opens in its block.
`Model.with_pool_transaction_isolation_level` gives the pool a level inside its block. Rails refuses
a savepoint while the pool has a level. The `create_or_find_by` method of Rails fails in such a
transaction too. The post save of the admin calls `set_field_values` inside `ActiveRecord::Base.transaction`.
With `requires_new: true`, Rails refused the savepoint of the writer there, and the save failed.
On 2026-10-05, the maintainer chose to ask for no savepoint while the pool has an isolation level
(`pool_transaction_isolation_level`). In a joinable transaction of the caller, the writers then
join it. With no open transaction, they open their own. The post save does not rescue the refusal
inside its transaction, so a refused save still rolls back as a whole. A failed call rolls back
nothing there by itself. A caller that rescues the refusal and commits loses the stored values that
the call deleted. The rows that the call stored before the refusal stay. The release before did the
same for a refusal of the value gate.
`ActiveRecord::Rollback` that leaves the block of a writer rolls nothing back there either, and
the writer returns nil. The other remedy was a note on the limit.

No example uses the isolation level API of Rails itself. Inside the transaction of an example,
Rails refuses each model transaction under that API. A group of examples with no such transaction
can use it, but that group commits its rows on the site that the suite shares, and SQLite sets a
level in its shared-cache mode only. On 2026-10-05, the maintainer chose to keep the examples that
stub `pool_transaction_isolation_level`. Probes with the API back the notes of this decision.

**D10. The writers reset the association after an error.** The maintainer chose it on 2026-10-04.
The rollback restores the database. The record still holds the rows of the call in its
`custom_field_values` association. After a refused `set_field_values`, the record read those rows,
and its next save failed. After a refused list of `set_field_value`, the next save of the record
stored the rows before the refused value. Each writer resets the association when its transaction
raises an error of any class, so the record reads the stored values again. The reset is in an
`ensure` block: a timeout of the caller can stop the writer with an exception that is not a
`StandardError`, or with a `throw`. After a `throw`, Rails can commit what the call stored or
deleted before it. The reset also runs when the call rolls back with
`ActiveRecord::Rollback`, which the transaction does not raise again.

The reset also covers a refusal of the value gate. The other remedy was a note that tells the
caller to reload the record.

The reset drops each unsaved row of the association, also a row that the caller built before the
call. The maintainer chose on 2026-10-04 to put those rows back. Each writer reads the unsaved rows
of the association before its transaction, and adds them to the association after the reset. A
`set_field_values` call that stores its rows still drops them: its delete clears the association.

A callback of a value row can raise `ActiveRecord::Rollback` before Rails stores the row. Rails
ends the save of that row with no error: `create!` returns an unsaved record. The writer goes on, its
delete stays, and the unsaved row stays in the association. The maintainer chose on 2026-10-05 to
leave this. It is the behavior of Rails for such a callback, the code before this change did the
same, and no surveyed consumer adds such a callback. The other remedies were an error for a row
that is not stored, and a reset after each call.

**D11. `set_field_value` refuses the group number before its delete.** The maintainer chose it on
2026-10-04. A call with an empty list builds no row, so no row refused the group number. The lookup
of the delete cast the number, and the call deleted the stored values of that group: `'1abc'` and
`true` were group 1. `set_field_value` gives the group number to a row that it does not store. That
row raises the refusal before the delete. The check runs on each call, so an empty list for a
stored negative group also raises.

The other remedy was a type that reads each refused number as no number in a lookup. That type
changes the readers.

**D12. The permit gives a group number that is not a scalar to the row.** The maintainer chose it on
2026-10-04. `cama_permitted_field_options` took the group number as a scalar. Rails dropped a list or
a hash there, and `set_field_values` read the absent number as group 0. The save stored the value in
group 0 with no error. The entry filter has `{ group_number: [{}] }` now. That filter gives a list or
a hash to the row with no content, and the row refuses the shape.

The filter also covers a list that holds a hash or a list. The other remedy was to leave the permit
and to say in the requirement that the permit drops such a number.

**D13. The writers keep the connection pool of `ActiveRecord::Base`.** The transaction of the
writers is `ActiveRecord::Base.transaction`, as before this change. The writers also read the
isolation level of that pool. A host can put the models of the engine on a pool of their own
(`CamaleonRecord.establish_connection`). There, that transaction does not cover the value rows, and
it does not roll back the delete of a refused call. The code before this change did the same.

On 2026-10-05, the maintainer chose to leave this. The engine uses the pool of `ActiveRecord::Base`
in other places too: the post save of the admin opens `ActiveRecord::Base.transaction`, and
`PluginRoutes.db_installed?` reads `ActiveRecord::Base.connection`. The other remedy was a
transaction on the class of the value rows.

## Risks / Trade-offs

- A plugin or theme that passes a negative number, a Float or a text that is not digits to
  `set_field_value` gets `ActiveRecord::RecordInvalid`. No surveyed consumer does.
- Outside `AdminController` a `RecordInvalid` is not rescued. No core caller outside the admin takes
  the group number from a request.
