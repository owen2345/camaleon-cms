# Design

## Terms

- A **value** is a custom-field value row, a record of `CamaleonCms::CustomFieldsRelationship`.
- A field group can repeat on a record. The **group number** of a value says which copy of the group
  holds the value. The first copy has the number 0.
- A group number is **not valid** when it is not nil and not an integer from 0 to 2147483647.
- The **group number error** is `ActiveRecord::RecordInvalid` with a message that names the field.
- The **two writers** are `set_field_value` and `set_field_values`. Each one deletes stored values
  and then creates the new values.

## Context

See proposal.md, "Why". Each write path stores a value through the model: `set_field_values`,
`set_field_value` and a direct `custom_field_values.create!`. So a check in the model covers each
path.

## Goals / Non-Goals

**Goals:**

- An admin save that reaches the controller with a group number that is not valid does not answer
  with a 500. D7 names the requests that stop before the controller.
- Such a save stores no new value and removes no stored value. D9 and D13 name the exceptions.
- The same rule holds on SQLite, PostgreSQL and MySQL.

**Non-Goals:**

- A repair of stored values. A stored value with a negative group number, or with none, stays as it
  is.
- The readers (`get_field_values`, `get_fields_grouped`). They get the group number from theme code,
  not from a request.
- The response of the draft save to a value that is not valid. The handler of `AdminController`
  still gives that response.

## Decisions

**D1. A validation in the value model.** The maintainer chose it on 2026-10-04 from four remedies.
The other three:

- An error in the permit helper (`cama_permitted_field_options`). The helper then drops the entry of
  the field. `set_field_values` deletes each stored value of the record first, so that field loses
  its stored values while the save stores the other entries. Plugins and themes that pass raw
  params to `set_field_values` do not call the helper, so they keep the 500.
- A clamp of the number to the valid range. A clamp changes the input with no notice, which
  `docs/security/permissions.md` does not allow.
- A `rescue_from ActiveModel::RangeError` in `AdminController`. It hides each range error of the
  admin, also an error with another cause, and it does not cover the `NoMethodError`.

The validation covers each caller. The save of the values rolls back, and the `RecordInvalid`
handler of `AdminController` shows the message.

**D2. The validation reads the group number as the caller gave it.** The integer cast of Rails
changes a group number that is not valid to a valid one: `true` becomes 1, and `false` and `'abc'`
become 0. A check after the cast accepts them. The numericality validator of Rails also uses the
cast value for `false`. So the validation reads the value before the cast. It accepts an Integer
from 0 to 2147483647, or a text of ASCII digits with a number in that range.

On 2026-10-05, the maintainer chose a limit of 16 digits for a text. Rails 8.1.4 reads only the
first 16 bytes of a text in the integer cast, and the validation read the whole text. So a text of
17 zeros and a 7 was valid as the number 7, and Rails stored 0. A text of more than 16 bytes is now
not valid. The validation checks the size before it scans the text, so it does not scan a long text.
The other remedy was a limit of 10 digits, the length of 2147483647.

**D3. The largest valid number is 2147483647 on each database.** PostgreSQL and MySQL store the
group number in a 4-byte integer column. SQLite can hold a larger integer. Before this change,
SQLite stored 2147483648 with no error. A group number that is valid on SQLite must be valid on
PostgreSQL and MySQL too.

The type of the group number (D7) also has the 4-byte range on each database. A column can hold a
larger integer on SQLite, and on a host whose column is `bigint`. There, for a number n above
2147483647 or below -2147483648:

- `where(group_number: n)` and `find_by(group_number: n)` find no row.
- A write of n that runs no validation raises `ActiveModel::RangeError`: `update_attribute`,
  `save(validate: false)`, `update_column`, `update_all` with a hash, `insert_all` and `upsert_all`.
- An SQL text is not checked. A condition with an SQL text finds the row, and `update_all` with an
  SQL text stores n.
- Some calls serialize each attribute of a stored row. They raise `ActiveModel::RangeError` for a
  row that holds n. `attributes_for_database` is one. `Marshal.dump` of the row is another, with the
  marshalling format 7.1, which `load_defaults 7.1` and later set. `Marshal.dump` of a record with
  the row in a loaded association raises it too, and so does a cache write of the row. With the
  format 6.1, `Marshal.dump` and the cache write pass.
- On Rails 7.0 or earlier, each save of a row that holds n raises that error. Those versions
  serialize each attribute of the row again after a save.

Before this change, those databases found and stored such a number. The maintainer chose to keep
the 4-byte range of the type on 2026-10-04. A type with the range of the column is possible. The
admin form sends the index of the group, so only custom code can store such a number.

**D4. A new value is always checked. A stored value is checked only when its group number
changes.** Rails compares the cast values to find a change. `'0abc'` casts to 0, which is the
default, so Rails sees no change on a new value with that text. For this reason, a new value is
always checked. A stored value with a negative number stays valid until its number changes, so
`update_field_value` can still change its content.

**D5. Nil is valid, and `set_field_values` reads an absent or empty group number as group 0.**
`camaleon_export_import` passes the group number of an exported value, which can be nil. A form can
express "no group number" only as an empty text, and the core forms always send a number. An empty
text in an encoding that is not ASCII-compatible is a text of D7, and it is not valid.

**D6. `set_field_values` no longer changes a negative number to 0.** That change was a transform of
the input with no notice. The value is now not valid, as the remedy rule of the security model asks:
reject, do not transform.

**D7. A group number text that the integer cast cannot read is not valid.** The maintainer chose it
on 2026-10-04. The integer type of Rails raises an encoding error for a text with a broken
encoding. It does the same for a text in an encoding that is not ASCII-compatible (UTF-16, UTF-7).
It raises that error before the validation runs. So the caller got an encoding error, not the group
number error.

The group number has its own integer type, `GroupNumberType`. The maintainer chose the type on
2026-10-04. The type gives nil for such a text and raises no error. The value keeps the text as the
caller gave it. The validation reads that text and adds the group number error. The type applies to
each write of the attribute (`group_number=`, `[]=`, `write_attribute`) and to each lookup.

No request can send such a text to the model. Rails answers a param with a broken encoding with a
400. A multipart part in an encoding that is not ASCII-compatible stops the request in the param
parser of Rack, before the save. Only Ruby code can pass such a text.

A lookup with such a text finds no row. Rails does the same for a lookup with a text that is not a
number. `find_or_create_by!` looks the number up first and finds no row. It then creates a value,
which gets the group number error. Before D11, `set_field_value` did the same. It now checks the
number before its lookup.

The type replaced three earlier guards of this change. Two of them gave the cast a Symbol: a writer
method and a `write_attribute` override. The third was a check before the lookup of
`set_field_value`. With those guards, `find_or_create_by!` raised the encoding error of Rails.

`update_attribute` and `save(validate: false)` run no validation. With the type alone, they stored
NULL for such a text. On 2026-10-04, the maintainer chose a guard. A `before_save` callback raises
the group number error, so `save` returns false and `save!` raises it. For each other group number
that is not valid, those two saves run no check. They store what the integer cast gives, or they
raise an error for a value that the type cannot store.

`update_column`, `update_all` with a hash and `insert_all` run no validation and no callback. They
store NULL as the group number for such a text. The maintainer chose to keep this on 2026-10-04.
Before this change, Rails raised its own error for those writes in most cases. In the other cases
it stored the digits at the start of the text, or NULL. A type can only change one value to another
value, so it cannot keep the number that the row held before. An error is possible for
`update_column` only: `update_all` with a hash and `insert_all` cast the value before the model
sees it. Rails checks no other value in those writes either: `'abc'` becomes NULL or 0.

**D8. A copy of a value keeps the group number as the caller gave it.** Rails copies (`dup`) each
attribute after the cast. The cast hides a group number that is not valid: `'abc'` becomes 0,
`true` becomes 1, and a text of D7 becomes nil. So the copy was valid, and its save stored the cast
number. `initialize_dup` now gives the copy the group number as the caller gave it to the original
value.

A copy is a new value, so it is always checked (D4). The copy of a stored value is not valid when
that value holds a negative number. The same applies to a number above 2147483647 in a column for a
larger integer. Before, the copy stored that number. The maintainer chose to keep this on
2026-10-04.

The master branch of `camaleon-post-clone` copies the values of a post. Its clone of a post with
such a value raises `ActiveRecord::RecordInvalid`. Only custom code stored such a number, because
the admin form sends the index of the group.

**D9. The two writers ask Rails for a savepoint.** The maintainer chose it on 2026-10-04. The two
writers delete stored values before they create the new values. Before this change, their
transaction joined an open transaction of the caller. A caller that rescued the error inside its
transaction and committed kept that delete, and the stored values were lost.

The writers now call `transaction(requires_new: true)`. The paragraphs on the isolation level hold
the one exception. The savepoint covers each error of a value, also the error for content that the
author is not permitted to save. Each savepoint costs two statements.

**D9, the restart of Rails.** Rails 7.2 and 8.1 open no savepoint when no statement ran yet in the
joinable transaction of the caller. After a failed call that ran a statement, Rails then rolls back
the whole transaction of the caller and begins it again. On SQLite, that restart is a ROLLBACK and a
BEGIN. With Rails 8.1, another connection can take the write lock between the two statements and
hold it past the busy timeout. The caller then gets
`ActiveRecord::ConnectionAdapters::TransactionInstrumenter::InstrumentationNotStartedError` in place
of the group number error. The stored values stay.

On 2026-10-05, the maintainer chose to make Rails open the savepoint. Before the writers open their
transaction, they run one statement (`SELECT 1`) in an open transaction of the caller. The statement
runs with the query cache off, because a statement that the cache answers does not reach the
database. Rails documents no option that stops the restart. The remedy relies on the rule of Rails
that it does not restart a transaction that ran a statement. While the pool has an isolation level,
the writers ask for no savepoint and run no such statement. The other remedy was a note on the
restart.

**D9, PostgreSQL.** More than 64 savepoints that write in one transaction overflow the
subtransaction cache of the session.

**D9, a pool with an isolation level.** Rails 8.1 has `ActiveRecord.with_transaction_isolation_level`.
It gives the connection pool an isolation level inside each transaction that a model class or a
record opens in its block. `Model.with_pool_transaction_isolation_level` gives the pool a level
inside its block. While the pool has a level, Rails raises an error for a savepoint.
`create_or_find_by` of Rails fails in such a transaction for the same reason.

The post save of the admin calls `set_field_values` inside `ActiveRecord::Base.transaction`. With
`requires_new: true`, Rails raised that error there, and the save failed. On 2026-10-05, the
maintainer chose that the writers ask for no savepoint while the pool has an isolation level. They
read `pool_transaction_isolation_level` for it. The results:

- Inside a joinable transaction of the caller, the writers run in that transaction. With no open
  transaction, they open their own.
- A failed call rolls back nothing by itself. The post save does not rescue the error inside its
  transaction, so a failed post save still rolls back as a whole.
- A caller that rescues the error and commits loses the stored values that the call deleted. The
  values that the call stored before the error stay. The release before did the same for content
  that the author was not permitted to save.
- `ActiveRecord::Rollback` that leaves the block of a writer rolls nothing back there either, and
  the writer returns nil.

The other remedy was a note on the limit.

No example uses the isolation level API of Rails itself. Each example runs in a transaction, and
under that API Rails raises an error for each model transaction inside it. A group of examples with
no such transaction can use the API. But that group commits its rows on the site that the suite
shares, and SQLite sets a level only in its shared-cache mode. On 2026-10-05, the maintainer chose
to keep the examples that stub `pool_transaction_isolation_level`. Probes with the real API back the
notes of this decision.

**D10. The two writers reset the association after a failed call.** The maintainer chose it on
2026-10-04. The rollback restores the database. But the `custom_field_values` association of the
record still holds the rows that the call built. After a failed `set_field_values`, the record read
those rows, and its next save failed. After a `set_field_value` call that failed for a list, the
next save of the record stored the rows before the value that was not valid.

Each writer now resets the association when its transaction fails with an error of any class. The
record then reads its stored values again. The reset is in an `ensure` block. A timeout of the
caller can stop a writer with an exception that is not a `StandardError`, or with a `throw`.
After a `throw`, Rails can commit the work that the call did before it. The reset also runs when
`ActiveRecord::Rollback` rolls the call back. Rails does not raise that error again.

The reset also runs after an error for content that the author is not permitted to save. The other
remedy was a note that tells the caller to reload the record.

The reset removes each unsaved row of the association, also a row that the caller built before the
call. The maintainer chose on 2026-10-04 to put those rows back. Each writer reads the unsaved rows
of the association before its transaction, and adds them again after the reset. One case differs: a
`set_field_values` call that succeeds removes those rows, because its delete empties the
association.

A callback of a value can raise `ActiveRecord::Rollback` before Rails stores the row. Rails ends the
save of that row with no error, and `create!` returns an unsaved record. The writer sees no error.
It goes on, its delete stays, and the unsaved row stays in the association. The maintainer chose on
2026-10-05 to keep this. It is the behavior of Rails for such a callback, and the code before this
change did the same. No surveyed consumer adds such a callback. The other remedies were an error
for a row that is not stored, and a reset after each call.

**D11. `set_field_value` checks the group number before its delete.** The maintainer chose it on
2026-10-04. A call with an empty list of values builds no row, so no row checked the group number.
The delete of the call finds the stored values by the group number, and that lookup casts the
number. So the call deleted the stored values of another group: `'1abc'` and `true` were group 1.
`set_field_value` now gives the group number to a row that it does not store. That row raises the
group number error before the delete. The check runs on each call, so a call with an empty list for
a stored negative group raises the error too.

The other remedy was a type that reads each group number that is not valid as no number in a
lookup. Such a type changes the readers.

**D12. The permit helper keeps a group number that is a list or a hash.** The maintainer chose it on
2026-10-04. `cama_permitted_field_options` permitted the group number as a scalar only. Rails drops
a list or a hash for a scalar filter, and `set_field_values` reads an absent number as group 0. So
the save stored the value in group 0 with no error. The filter of an entry now also has
`{ group_number: [{}] }`. That filter keeps a list or a hash, with its content removed, and the
value is then not valid. The filter also covers a list that holds a hash or a list. The other remedy
was to leave the permit, and to say in the requirement that the permit drops such a number.

**D13. The two writers keep the connection pool of `ActiveRecord::Base`.** The transaction of the
writers is `ActiveRecord::Base.transaction`, as before this change. The writers also read the
isolation level of that pool. A host can put the models of the engine on a pool of their own
(`CamaleonRecord.establish_connection`). That transaction then does not cover the values, and a
failed call does not roll back its delete. The code before this change did the same.

On 2026-10-05, the maintainer chose to keep this. The engine uses the pool of `ActiveRecord::Base`
in other places too: the post save of the admin opens `ActiveRecord::Base.transaction`, and
`PluginRoutes.db_installed?` reads `ActiveRecord::Base.connection`. The other remedy was a
transaction on the class of the values.

**D14. `set_field_values` checks the group number of an entry with no values.** The maintainer
chose it on 2026-10-05. `set_field_values` skips an entry with no values, and it read the group
number after that skip. So an entry with no values and a group number that is not valid got no
error, and the save passed. The method builds no row for that entry, so the save stored no wrong
value.

The requirement says that an admin save with such a group number gets the error.
`set_field_value` gives the error for an empty list too (D11). The method now reads the group
number of each entry before the skip. For an entry with no values, it gives the number to a row
that it does not store, as `set_field_value` does. The admin JavaScript sends the index of the
group, so no core form sends such an entry. The other remedy was a note on the skip.

**D15. `set_field_value` removes the rows that it deletes from a loaded association.** The
maintainer chose it on 2026-10-05. `set_field_value` deletes the stored values with an SQL DELETE on
a relation. An SQL DELETE does not change a loaded `custom_field_values` association, so the
deleted rows stayed in it. `get_field_values` reads a loaded association, so the same record read
the deleted values and the new values. `get_field_values_hash` loads the association. The master
branch has the same defect.

When the association is loaded, the method reads the ids of the stored rows before the DELETE.
After the DELETE, it removes the rows with those ids from the association. That is one more query,
only for a loaded association. The unsaved rows that the caller built stay. `set_field_values`
needs no such step, because its delete empties the association (D10). The other remedy was a reset
of the association after each call, which removes the unsaved rows of the caller.

## Risks / Trade-offs

- A plugin or theme that passes a negative number, a Float or a text that is not digits to
  `set_field_value` gets `ActiveRecord::RecordInvalid`. No surveyed consumer does.
- Outside `AdminController`, no code rescues that `RecordInvalid`. No core caller outside the admin
  takes the group number from a request.
