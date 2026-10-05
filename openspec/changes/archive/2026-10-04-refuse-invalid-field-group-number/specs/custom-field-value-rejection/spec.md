## ADDED Requirements

### Requirement: A custom-field value refuses a group number outside its range

In this requirement, "a value" is a custom-field value row (`CamaleonCms::CustomFieldsRelationship`).
"The two writers" are `set_field_value` and `set_field_values`. "The group number error" is
`ActiveRecord::RecordInvalid` with a message that names the field.

A value SHALL be valid only when its group number is nil or an integer from 0 to 2147483647. A
caller gives the integer as an Integer or as a text of 1 to 16 ASCII digits. For any other group
number, the save of the value MUST fail with the group number error, on each write path and on each
supported database. Examples are a larger number, a negative number, a boolean and a file. So are a
text that is not digits and a text of more than 16 digits.

The system SHALL NOT change a group number that is not valid to a valid one. A new value is always
checked. A stored value SHALL be checked only when a save changes its group number.

**Admin saves.** An admin save that reaches the controller with such a group number MUST NOT answer
with a 500. It SHALL redirect back with the error, and the record SHALL keep its stored values. Two
kinds of request stop before the controller. A request with a param in a broken encoding gets a 400.
A multipart request with a part in an encoding that is not ASCII-compatible stops in the param
parser. An absent or empty group number in an admin save SHALL mean group 0.

A group number that an admin save sends as a list or a hash MUST get the group number error too. An
empty list is a list. `cama_permitted_field_options` SHALL keep such a group number, with its
content removed. It SHALL NOT drop it, because `set_field_values` reads an absent group number as
group 0.

**A text that Rails cannot read as a number.** The integer cast of Rails raises an encoding error
for a text with a broken encoding, and for a text in an encoding that is not ASCII-compatible. For
such a group number text:

- Each write path MUST fail with the group number error, not with the encoding error of Rails.
- A lookup (`where`, `find_by`) SHALL find no row. So a write that looks the number up first
  (`find_or_create_by!`) gets the group number error.
- `update_attribute` and `save(validate: false)` run no validation. They MUST NOT store a group
  number for such a text: they SHALL stop with the group number error.
- `update_column`, `update_all` with a hash and `insert_all` run no validation and no callback. They
  are not write paths of this requirement. They store NULL as the group number for such a text.

For each other group number that is not valid, `update_attribute` and `save(validate: false)` run
no check. They store what the integer cast gives (-1 stays -1, and `abc` becomes 0), or they raise
an error for a value that the type cannot store.

**The range of the type.** The group number attribute SHALL have the range of a 4-byte integer on
each supported database, also where the column can hold a larger integer (SQLite, a `bigint`
column). There, for a number n above 2147483647 or below -2147483648, `where(group_number: n)` and
`find_by(group_number: n)` find no row. A write that gives n and runs no validation raises
`ActiveModel::RangeError`. An SQL text is not checked.

**A copy of a value.** A copy (`dup`) SHALL keep the group number as the caller gave it to the
original value. So the copy of a value with a group number that is not valid MUST get the group
number error. A copy is a new value, and a new value is always checked. So the copy of a stored
value with a negative group number MUST get the group number error. So MUST the copy of a stored
value with a number above 2147483647, which a column for a larger integer can hold.

**Calls with no values.** `set_field_value` SHALL check the group number before it deletes a stored
value. A call with an empty list of values builds no row, and that call MUST get the group number
error too. `set_field_values` SHALL check the group number of each entry. An entry with no values
builds no row, and that entry MUST get the group number error too.

**The rollback.** The two writers delete stored values before they create the new values. When a
new value is not valid, that delete MUST roll back, so the record keeps its stored values.

A caller can run a writer inside its own transaction, rescue the error and commit. The stored
values MUST stay in that case too. So the writers SHALL ask Rails for a savepoint inside a
transaction of the caller. They SHALL run one statement in that transaction first. With no
statement there, Rails opens no savepoint, and it restarts the whole transaction of the caller
after a failed call.

Rails permits no savepoint while the connection pool has an isolation level. On Rails 8.1,
`ActiveRecord.with_transaction_isolation_level` and `Model.with_pool_transaction_isolation_level`
give the pool a level. While the pool has a level and a joinable transaction of the caller is
open, the writers SHALL NOT ask for a savepoint. They SHALL run inside that transaction. A failed
call then rolls back nothing by itself: the stored values come back only when the transaction of
the caller rolls back. A caller that rescues the error and commits loses the stored values that the
call deleted. The values that the call stored before the error stay.

The writers open their transaction on the connection pool of `ActiveRecord::Base`. The rollback of
this requirement needs the values on that pool. With the values on another pool, a failed call
does not roll back its delete.

**The record after a call.** `set_field_value` deletes stored values with an SQL DELETE, which does
not change a loaded `custom_field_values` association. After that delete, a loaded association of
the record SHALL NOT hold a row that the call deleted, so the record reads only the new values. The
call SHALL NOT load an association that is not loaded.

After a failed call, the `custom_field_values` association of the record still holds the rows that
the call built. The writer SHALL reset that association. The record then SHALL read its stored
values, and its next save MUST NOT store a row of the failed call. A failed call is each of these:

- An exception of any class leaves the call, also an exception that is not a `StandardError`.
- A `throw` leaves the call. After a `throw`, Rails can commit the work that the call did before it.
- `ActiveRecord::Rollback` rolls the call back.

A timeout of the caller stops the call with an exception or with a `throw`.

The reset removes each unsaved row of the association. So the writer SHALL put back the unsaved
rows that the caller built before the call.

One case is not a failed call. A callback of a value can raise `ActiveRecord::Rollback` before
Rails stores the row. Rails ends the save of that row with no error. The writer goes on, and the
unsaved row stays in the association.

#### Scenario: A group number above the range is refused in an admin save

- **WHEN** an admin save submits a registered field with a group number above 2147483647
- **THEN** the response redirects back with an error that names the field, and the stored values of
  the record are unchanged

#### Scenario: A boolean group number is refused in an admin save

- **WHEN** an admin save with a JSON body submits `true` or `false` as a group number
- **THEN** the response redirects back with an error that names the field, and the stored values of
  the record are unchanged

#### Scenario: A group number sent as a list or a hash is refused in an admin save

- **WHEN** an admin save submits a registered field with a group number that is a list, a hash or a
  list of hashes
- **THEN** the response redirects back with an error that names the field, and the stored values of
  the record are unchanged

#### Scenario: A negative group number or a text that is not digits is refused

- **WHEN** a save submits a group number of `-1`, `abc` or `0abc`
- **THEN** the save fails with the group number error, and no value is stored for it

#### Scenario: A text of more than 16 digits is refused

- **WHEN** a save submits a group number text of 17 digits whose number is in the range
- **THEN** the save fails with the group number error, and no value is stored for it

#### Scenario: The largest group number is stored

- **WHEN** a save submits a group number of 2147483647
- **THEN** the value is stored under that group number

#### Scenario: A stored value with a negative group number stays writable

- **WHEN** a stored value holds a negative group number and a caller updates only its content
- **THEN** the update succeeds

#### Scenario: A group number text that the integer cast cannot read is refused

- **WHEN** `set_field_value`, `set_field_values` or a direct `custom_field_values.create!` gets a
  group number text with a broken encoding, or in an encoding that is not ASCII-compatible
- **THEN** the caller gets the group number error, and the stored values of the record are
  unchanged

#### Scenario: A save with no validation stops for a text that the integer cast cannot read

- **WHEN** `update_attribute` or `save(validate: false)` saves a value with a group number text with
  a broken encoding, or in an encoding that is not ASCII-compatible
- **THEN** the save returns false, the value holds the message of the group number error, and the
  stored value is unchanged

#### Scenario: A write that looks the number up first gets the group number error

- **WHEN** `custom_field_values.find_or_create_by!` gets a group number text with a broken
  encoding, or in an encoding that is not ASCII-compatible
- **THEN** the lookup finds no row, the caller gets the group number error, and the stored values
  of the record are unchanged

#### Scenario: A copy of a value with a group number that is not valid is not valid

- **WHEN** a caller copies a value with `dup`, and the value holds a group number that is not valid
- **THEN** the save of the copy returns false, the copy holds the message of the group number
  error, and the save stores no row

#### Scenario: A call with an empty list and a group number that is not valid fails

- **WHEN** `set_field_value` gets an empty list of values and a group number that is not valid
- **THEN** the caller gets the group number error, and the stored values of the record are
  unchanged

#### Scenario: An entry with no values and a group number that is not valid fails

- **WHEN** `set_field_values` or an admin save gets an entry with no values and a group number that
  is not valid
- **THEN** the caller gets the group number error, and the stored values of the record are
  unchanged

#### Scenario: A failed call inside a transaction of the caller keeps the stored values

- **WHEN** the pool has no isolation level, and a caller runs `set_field_value` or
  `set_field_values` inside its own transaction with a group number that is not valid, rescues the
  error inside that transaction and commits
- **THEN** the stored values of the record are unchanged

#### Scenario: A failed call in a new transaction of the caller rolls back to a savepoint

- **WHEN** the pool has no isolation level, a caller opens a transaction, and `set_field_value` or
  `set_field_values` is its first statement and fails after its delete
- **THEN** the writer rolls back to a savepoint of its own, and Rails does not restart the
  transaction of the caller

#### Scenario: The writers run inside a transaction of the caller that has a pool isolation level

- **WHEN** a caller on Rails 8.1 runs `set_field_value` or `set_field_values` inside a joinable
  `Model.transaction` that starts under `ActiveRecord.with_transaction_isolation_level`
- **THEN** the writer opens no savepoint, and the call stores its values

#### Scenario: A record with a loaded association reads the new values after set_field_value

- **WHEN** the `custom_field_values` association of a record is loaded, and `set_field_value` stores a
  new value for a group that holds a stored value
- **THEN** the record reads the new value and not the deleted value, and the association stays
  loaded

#### Scenario: The record reads the stored values after a failed call

- **WHEN** `set_field_value` or `set_field_values` raises an error, and the caller rescues it and
  goes on with the same record
- **THEN** the record reads the stored values, and its next save stores no row of the failed call

#### Scenario: The rows that the caller built stay after a failed call

- **WHEN** a caller builds an unsaved row on the `custom_field_values` association, and
  `set_field_value` or `set_field_values` then raises an error
- **THEN** the association holds that row, and the next save of the record stores it
