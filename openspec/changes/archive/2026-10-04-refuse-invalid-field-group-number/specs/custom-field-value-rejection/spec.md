## ADDED Requirements

### Requirement: A value row refuses a group number outside the range of the column

A custom-field value row SHALL accept a group number only when it is nil or an integer from 0 to
2147483647, given as an Integer or as a text of ASCII digits. The row MUST refuse any other group
number (a larger number, a negative number, a boolean, a text that is not digits, a file) with an
error that names the field, on each write path and on each supported database. The row SHALL NOT
change the number to a valid one. A new row is always checked. A stored row SHALL be checked only
when its group number changes. An admin save that submits a refused group number MUST NOT answer with
a 500: it SHALL redirect back with the error and leave the stored values of the record unchanged. An
absent or empty group number in an admin save SHALL mean group 0.

In an admin save, a group number that is a list or a hash MUST get the same refusal. An empty list
is a list. `cama_permitted_field_options` SHALL give that shape to the row, with no content. It
SHALL NOT drop the number, because `set_field_values` reads an absent number as group 0.

A group number text with a broken encoding, or in an encoding that is not ASCII-compatible, SHALL
get the same refusal on each write path. The integer cast of Rails raises its own error for that
text, and that error MUST NOT replace the refusal. A save that skips the validation MUST NOT store
a group number for that text: it SHALL stop with the same refusal. A lookup with that text SHALL
find no row, so a write that looks the number up first SHALL get the same refusal.

A save that skips the validation (`update_attribute`, `save(validate: false)`) is a write path of
this requirement for that text only. For another refused group number, such a save runs no check
of the row. It stores what the integer cast of the type gives (-1 stays -1, and `abc` becomes 0), or
it raises an error for a value that the type cannot store.

A write that skips the validation and the callbacks (for example `update_column`, `update_all`,
`insert_all`) is not a write path of this requirement. Such a write stores no group number (NULL) for that text.

The type of the group number SHALL have the 4-byte range on each supported database, also where
the column holds a wider integer (SQLite, a `bigint` column). There, a lookup with a number above
2147483647 or below -2147483648 finds no row, and a write that skips the validation raises
`ActiveModel::RangeError` for that number.

A copy of a row (`dup`) SHALL keep the group number as the caller gave it to the original row. The
copy of a row with a refused group number MUST get the same refusal.

A copy is a new row, so the row SHALL check its group number. The copy of a stored row that holds
a negative number MUST get the same refusal. So MUST the copy of a stored row that holds a number
above 2147483647 in a wider column.

`set_field_value` SHALL check the group number before it deletes a stored value. A call with an
empty list of values builds no row, and that call MUST get the same refusal.

`set_field_value` and `set_field_values` delete stored values before they create the rows. A refusal
of a row MUST roll that delete back. Inside a transaction of the caller, the writers SHALL open a
savepoint, so the rollback also holds when the caller rescues the refusal and commits. The next
paragraph gives the exception for a pool with an isolation level.

While the pool has an isolation level, Rails refuses a savepoint. On Rails 8.1,
`ActiveRecord.with_transaction_isolation_level` gives the pool a level inside each transaction that
a model class or a record save opens. While the pool has a level and a joinable transaction of the
caller is open, the writers SHALL NOT open a savepoint. They SHALL run inside that transaction. A
failed call then rolls back nothing, unless the transaction of the caller rolls back. A caller that
rescues the refusal and commits keeps what the call deleted and stored before the refusal.

The rollback leaves the rows of the failed call in the `custom_field_values` association of the
record. After an error of a writer, the writer SHALL reset that association. The record then SHALL
read the stored values, and its next save MUST NOT store a row of the failed call. An exception that
is not a `StandardError` is such an error. So are a `throw` out of the call and a rollback of the
call with `ActiveRecord::Rollback`. A timeout of the caller stops the call in one of the first two
ways.

A callback of a value row that raises `ActiveRecord::Rollback` before the row is stored is not an
error of a writer. Rails ends the save of that row with no error. The writer then goes on, and the
unsaved row stays in the association.

The reset drops each unsaved row of the association, so the writer SHALL put back the unsaved rows
that the caller built before the call.

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
- **THEN** the save is refused and no value row is stored for it

#### Scenario: The largest group number is stored

- **WHEN** a save submits a group number of 2147483647
- **THEN** the value is stored under that group number

#### Scenario: A stored row with a negative group number stays writable

- **WHEN** a stored row holds a negative group number and a caller updates only its value
- **THEN** the update succeeds

#### Scenario: A group number text that the integer cast cannot read is refused

- **WHEN** `set_field_value`, `set_field_values` or a direct `custom_field_values.create!` gets a
  group number text with a broken encoding, or in an encoding that is not ASCII-compatible
- **THEN** the caller gets the refusal that names the field, and the stored values of the record
  are unchanged

#### Scenario: A save that skips the validation stops for a text that the integer cast cannot read

- **WHEN** `update_attribute` or `save(validate: false)` saves a row with a group number text with a
  broken encoding, or in an encoding that is not ASCII-compatible
- **THEN** the save returns false, the row holds the refusal that names the field, and the stored
  row is unchanged

#### Scenario: A write that looks the number up first is refused

- **WHEN** `custom_field_values.find_or_create_by!` gets a group number text with a broken
  encoding, or in an encoding that is not ASCII-compatible
- **THEN** the lookup finds no row, the caller gets the refusal that names the field, and the
  stored values of the record are unchanged

#### Scenario: A copy of a row with a refused group number is refused

- **WHEN** a caller copies a row with `dup`, and the row holds a group number that the row refuses
- **THEN** the save of the copy returns false, the copy holds the refusal that names the field, and
  the save stores no row

#### Scenario: An empty list with a refused group number is refused

- **WHEN** `set_field_value` gets an empty list of values and a group number that a row refuses
- **THEN** the caller gets the refusal that names the field, and the stored values of the record
  are unchanged

#### Scenario: A refusal inside a transaction of the caller keeps the stored values

- **WHEN** the pool has no isolation level, and a caller runs `set_field_value` or
  `set_field_values` inside its own transaction with a group number that the row refuses, rescues
  the refusal inside that transaction and commits
- **THEN** the stored values of the record are unchanged

#### Scenario: The writers join a transaction of the caller that has a pool isolation level

- **WHEN** a caller on Rails 8.1 runs `set_field_value` or `set_field_values` inside a joinable
  `Model.transaction` that starts under `ActiveRecord.with_transaction_isolation_level`
- **THEN** the writer opens no savepoint, and the call stores its values

#### Scenario: The record reads the stored values after a failed call

- **WHEN** `set_field_value` or `set_field_values` raises an error, and the caller rescues it and
  goes on with the same record
- **THEN** the record reads the stored values, and its next save stores no row of the failed call

#### Scenario: The rows that the caller built stay after a failed call

- **WHEN** a caller builds an unsaved row on the `custom_field_values` association, and
  `set_field_value` or `set_field_values` then raises an error
- **THEN** the association holds that row, and the next save of the record stores it
