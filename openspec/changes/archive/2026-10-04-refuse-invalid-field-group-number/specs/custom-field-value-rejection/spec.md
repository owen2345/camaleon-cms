## ADDED Requirements

### Requirement: A custom-field value validates its group number

An author can add a repeatable field group to a post several times. The group number of a
custom-field value is the index of the copy that the value belongs to, from 0.

A value SHALL be valid only when its group number is nil, an Integer from 0 to 2147483647, or a
String of 1 to 16 digits with such a number. For any other group number, the save MUST fail with
`ActiveRecord::RecordInvalid` and a message that names the field ("the group number error"), on
each supported database. The system SHALL NOT change an invalid group number to a valid one.

- **When the validation runs.** A new value is always validated. A stored value SHALL be validated
  only when a save changes its group number. A copy (`dup`) is a new value, and it SHALL keep the
  group number as the caller gave it. So the copy of an invalid value MUST be invalid.
- **Admin saves.** An admin save that reaches the controller with an invalid group number MUST NOT
  answer with a 500. It SHALL redirect back with the error, and the record SHALL keep its stored
  values. Rails answers a param in an invalid encoding with a 400 before the controller. An absent
  or empty group number SHALL mean group 0. `cama_permitted_field_options` SHALL keep a group
  number that is a list or a hash, with its content removed, so that the save fails.
- **Calls with no values.** `set_field_value` with an empty list of values MUST get the error, and
  it SHALL validate the group number before it deletes a stored value. An entry of
  `set_field_values` with no values MUST get the error too.
- **A String that Rails cannot cast.** Rails cannot read a String in an invalid encoding, or in an
  encoding that is not ASCII-compatible (UTF-16), as an Integer. The integer cast of Rails raises an
  encoding error for an invalid encoding. For UTF-16, the cast returns nil, and a lookup raises the
  error. For such a group number, each write path MUST fail with the group number error. A lookup (`where`,
  `find_by`) SHALL find no row. `update_attribute` and `save(validate: false)` MUST NOT store it.
  `update_column`, `update_all` with a hash and `insert_all` are not write paths of this
  requirement: they store NULL.
- **The range of the attribute.** The group number attribute SHALL have the range of a 4-byte
  integer on each supported database, also where the column can hold a larger integer (SQLite, a
  `bigint` column).
- **The rollback.** `set_field_value` and `set_field_values` delete stored values before they
  create the new values. When a new value is invalid, that delete MUST roll back. Inside a
  transaction of the caller, the two methods SHALL use a savepoint, so the stored values stay when
  the caller rescues the error and commits. They SHALL run one statement in that transaction
  first, because Rails 7.2 and later open no savepoint before the first statement.
- **A pool with an isolation level.** Rails 8.1 permits no savepoint while the connection pool has
  a transaction isolation level. The two methods then SHALL NOT ask for a savepoint. Inside a
  transaction of the caller, they run in that transaction, and only a rollback of it restores the
  deleted values. The transaction of the two methods is on the connection pool of
  `ActiveRecord::Base`.
- **The record after a call.** After a failed call, the two methods SHALL reset the
  `custom_field_values` association of the record. The record then SHALL read its stored values,
  and its next save MUST NOT store a value of the failed call. A failed call is an exception of any
  class, a `throw` or `ActiveRecord::Rollback`. The two methods SHALL put back the unsaved values
  that the caller built before the call. A callback of a value that raises `ActiveRecord::Rollback`
  before Rails stores the value is not a failed call.
- **A loaded association.** After `set_field_value`, a loaded `custom_field_values` association
  SHALL NOT hold a value that the call deleted. The call SHALL NOT load an association that is not
  loaded.

#### Scenario: An admin save with a group number above the range

- **WHEN** an admin save submits a registered field with a group number above 2147483647
- **THEN** the response redirects back with an error that names the field, and the stored values of
  the record are unchanged

#### Scenario: An admin save with a boolean group number

- **WHEN** an admin save with a JSON body submits `true` or `false` as a group number
- **THEN** the response redirects back with an error that names the field, and the stored values of
  the record are unchanged

#### Scenario: An admin save with a group number that is a list or a hash

- **WHEN** an admin save submits a registered field with a group number that is a list, a hash or a
  list of hashes
- **THEN** the response redirects back with an error that names the field, and the stored values of
  the record are unchanged

#### Scenario: A negative group number, or a String that is not digits

- **WHEN** a save submits a group number of `-1`, `abc` or `0abc`
- **THEN** the save fails with the group number error, and no value is stored for it

#### Scenario: A String of more than 16 digits

- **WHEN** a save submits a group number String of 17 digits whose number is in the range
- **THEN** the save fails with the group number error, and no value is stored for it

#### Scenario: The largest group number is stored

- **WHEN** a save submits a group number of 2147483647
- **THEN** the value is stored under that group number

#### Scenario: A stored value with a negative group number stays writable

- **WHEN** a stored value holds a negative group number and a caller updates only its content
- **THEN** the update succeeds

#### Scenario: A group number String that Rails cannot cast

- **WHEN** `set_field_value`, `set_field_values` or a direct `custom_field_values.create!` gets a
  group number String in an invalid encoding, or in an encoding that is not ASCII-compatible
- **THEN** the caller gets the group number error, and the stored values of the record are
  unchanged

#### Scenario: A save that skips the validation, with a String that Rails cannot cast

- **WHEN** `update_attribute` or `save(validate: false)` saves a value with a group number String
  in an invalid encoding, or in an encoding that is not ASCII-compatible
- **THEN** the save returns false, the value holds the message of the group number error, and the
  stored value is unchanged

#### Scenario: A write that looks the number up first

- **WHEN** `custom_field_values.find_or_create_by!` gets a group number String in an invalid
  encoding, or in an encoding that is not ASCII-compatible
- **THEN** the lookup finds no row, the caller gets the group number error, and the stored values
  of the record are unchanged

#### Scenario: The copy of an invalid value is invalid

- **WHEN** a caller copies a value with `dup`, and the value holds an invalid group number
- **THEN** the save of the copy returns false, the copy holds the message of the group number
  error, and the save stores no row

#### Scenario: An empty list of values with an invalid group number

- **WHEN** `set_field_value` gets an empty list of values and an invalid group number
- **THEN** the caller gets the group number error, and the stored values of the record are
  unchanged

#### Scenario: An entry with no values and an invalid group number

- **WHEN** `set_field_values` or an admin save gets an entry with no values and an invalid group
  number
- **THEN** the caller gets the group number error, and the stored values of the record are
  unchanged

#### Scenario: A failed call inside a transaction of the caller keeps the stored values

- **WHEN** the pool has no isolation level, and a caller runs `set_field_value` or
  `set_field_values` inside its own transaction with an invalid group number, rescues the error
  inside that transaction and commits
- **THEN** the stored values of the record are unchanged

#### Scenario: A failed call that is the first statement of a transaction rolls back to a savepoint

- **WHEN** the pool has no isolation level, a caller opens a transaction, and `set_field_value` or
  `set_field_values` is its first statement and fails after its delete
- **THEN** the method rolls back to a savepoint of its own, and Rails does not restart the
  transaction of the caller

#### Scenario: A transaction of the caller with a pool isolation level

- **WHEN** a caller on Rails 8.1 runs `set_field_value` or `set_field_values` inside a joinable
  `Model.transaction` that starts under `ActiveRecord.with_transaction_isolation_level`
- **THEN** the method opens no savepoint, and the call stores its values

#### Scenario: A loaded association reads the new values after set_field_value

- **WHEN** the `custom_field_values` association of a record is loaded, and `set_field_value` stores a
  new value for a group that holds a stored value
- **THEN** the record reads the new value and not the deleted value, and the association stays
  loaded

#### Scenario: The record reads the stored values after a failed call

- **WHEN** `set_field_value` or `set_field_values` raises an error, and the caller rescues it and
  goes on with the same record
- **THEN** the record reads the stored values, and its next save stores no value of the failed call

#### Scenario: The unsaved values of the caller stay after a failed call

- **WHEN** a caller builds an unsaved value on the `custom_field_values` association, and
  `set_field_value` or `set_field_values` then raises an error
- **THEN** the association holds that value, and the next save of the record stores it
