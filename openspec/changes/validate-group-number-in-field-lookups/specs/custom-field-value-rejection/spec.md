## MODIFIED Requirements

### Requirement: A custom-field value validates its group number

An author can add a repeatable field group to a post several times. The group number of a
custom-field value is the index of the copy that the value belongs to, from 0.

A value SHALL be valid only when its group number is nil, an Integer from 0 to 2147483647, or a
String of 1 to 16 digits with such a number. For any other group number, the save MUST fail with
`ActiveRecord::RecordInvalid` and a message that names the field ("the group number error"), on
each supported database. The system SHALL NOT change an invalid group number to a valid one. The
writes that skip the validation (`update_attribute`, `save(validate: false)`, `update_column`,
`update_all` with a hash, `insert_all`) are the exception: they store a castable group number inside
the 4-byte range as Rails casts it, as before. For a String with no leading digit (`'abc'`),
`update_column` stores NULL.

- **When the validation runs.** A new value is always validated. A stored value SHALL be validated
  only when a save changes its group number. A copy (`dup`) is a new value, and it SHALL keep the
  group number as the caller gave it. So the copy of an invalid value MUST be invalid.
- **Admin saves.** An admin save that reaches the controller with an invalid group number MUST NOT
  answer with a 500. It SHALL answer with the error as a refused admin save answers (the requirement "A refused admin save answers by the kind of the request"), and the record SHALL keep its stored values. Rails answers a param in an invalid encoding with a 400 before the controller. An absent
  or empty group number SHALL mean group 0. `cama_permitted_field_options` SHALL keep a group
  number that is a list or a hash, with its content removed, so that the save fails.
- **Calls with no values.** `set_field_value` with an empty list of values MUST get the error, and
  it SHALL validate the group number before it deletes a stored value. An entry of
  `set_field_values` with no values MUST get the error too.
- **A call that looks the value up.** `update_field_value` MUST get the error for an invalid group
  number, and it SHALL validate the number before its lookup. Without the validation, the lookup
  finds the groups of a list (`[1]`) and no value for `'1abc'` or `true`. The caller then
  gets no error. A negative Integer is the exception: the method SHALL look it up with no
  validation. The lookup finds only a value with that number, and the method changes
  no group number. The method returns false for a value that a validation refuses, and nil for each
  other error in the lookup or the write, as before.
- **An update with a loaded association.** `update_field_value` SHALL update the stored value in
  the database. With a loaded `custom_field_values` association, it SHALL then put the saved value
  in the row with the same id that the association holds. The record then reads the new value. When
  another instance replaced the stored row, the association holds no such row, and the record reads
  the old value until it is loaded again. The method SHALL save no other change of that row.
- **Reads.** `get_field_values` SHALL read no value for an invalid group number, other than a
  negative Integer down to -2147483648 or a list. `get_field_value` SHALL return its default for
  a group number that reads no value. A negative Integer down to -2147483648 reads a stored value
  with that number. A list (Array) SHALL read each group in the list when each item is a valid
  group number or a negative Integer down to -2147483648. A list with any other item SHALL read no
  value. A list in a list (`[[1]]`) is such an item.
- **Reads with a loaded association.** Each group number SHALL read the same stored values with or
  without a loaded `custom_field_values` association. A loaded association SHALL read `:note` as
  `'note'`, `5` as `'5'`, a Date as `'2020-01-01'` and a Range key as its slugs, as the database
  does. It SHALL read each key of a list, and the keys of a list in a list. The database gives the
  values in the order of `term_order`, and a loaded association in the order of its rows. So the
  first value, which `get_field_value` returns, can differ. The values differ in these cases:
  - A loaded association reads unsaved values: the values of the rows that the record built, and
    the changed values of its rows. It reads each row under the group number and the slug that the
    row holds, also when they are not saved. It reads an unsaved invalid group number as the
    integer cast gives it (`'1abc'` as group 1).
  - A loaded association reads the rows that it holds, until it is loaded again. A write of another
    instance, or an `update_all`, changes no row that the association holds, so the association
    reads the old values.
  - On MySQL, the collation can match another spelling of a slug (`'Note'` or `'nóte'` for
    `'note'`), and a loaded association matches only the same slug.
  - The database compares the slugs in a Range key with its collation. A loaded association
    compares their bytes.
  - The database raises an error for a key that it cannot read, for example a Hash. A loaded
    association reads no value for such a key.
- **Reads of each group.** `get_fields_grouped` SHALL read the values of a Symbol key (`:note`) as
  it reads the values of the String key (`'note'`). An Integer key (`5`) SHALL read the values of
  its String (`'5'`). A Date key SHALL read the values of the slug that the connection quotes for it
  (`'2020-01-01'`). A Range key SHALL read the values of each slug in the Range. Each group
  SHALL give the values under the key as given.
- **A String that Rails cannot cast.** Rails cannot read a String in an invalid encoding, or in an
  encoding that is not ASCII-compatible (UTF-16), as an Integer. The integer cast of Rails raises an
  `ArgumentError` for an invalid encoding. For UTF-16LE or UTF-16BE, the cast returns nil, and a
  lookup raises an encoding error. For such a group number, each write path MUST fail with the group number
  error. A lookup (`where`, `find_by`) SHALL find no row. `update_attribute` and
  `save(validate: false)` MUST NOT store it.
  `update_column`, `update_all` with a hash and `insert_all` are not write paths of this
  requirement: they store NULL.
- **A slug that is not in UTF-8.** The message of the group number error SHALL hold the slug of
  the field in UTF-8. Without the conversion, a slug in an encoding that is not ASCII-compatible
  (UTF-16) raises an encoding error in place of the group number error.
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

- **WHEN** a stored value holds a negative group number down to -2147483648
- **AND** a caller updates only its content: `row.update(value: 'new')`, or `update_field_value`
  with that number as an Integer
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

#### Scenario: update_field_value with an invalid group number

- **WHEN** `update_field_value` gets an invalid group number other than a negative Integer, for
  example `'1abc'` or `true`
- **THEN** the caller gets the group number error, and the stored values of the record are
  unchanged

#### Scenario: update_field_value with a slug in UTF-16 and an invalid group number

- **WHEN** `update_field_value` gets a slug in UTF-16 and an invalid group number (`'1abc'`)
- **THEN** the caller gets the group number error with the slug in UTF-8, and the stored values of
  the record are unchanged

#### Scenario: update_field_value with a loaded association

- **WHEN** the `custom_field_values` association of a record is loaded, and `update_field_value`
  updates a stored value
- **THEN** the record reads the new value, also before it is loaded again

#### Scenario: update_field_value after another instance replaced the stored value

- **WHEN** the `custom_field_values` association of a record is loaded, and another instance of the
  record replaced the stored value with `set_field_value`
- **AND** `update_field_value` updates that value
- **THEN** the stored value holds the new value
- **AND** the record reads the old value until it is loaded again

#### Scenario: A reader with a group number that the integer cast misreads

- **WHEN** `get_field_values` or `get_field_value` gets `'1abc'` or `true` as the group number
- **THEN** it reads no value, and `get_field_value` returns its default

#### Scenario: A reader with an Integer outside the 4-byte range

- **WHEN** a stored value holds a group number outside the 4-byte range (SQLite, a `bigint` column)
- **AND** `get_field_values` gets that number, with or without a loaded association
- **THEN** it reads no value

#### Scenario: A reader with a String of digits and a loaded association

- **WHEN** the `custom_field_values` association of a record is loaded, and `get_field_values` gets
  `'1'` as the group number
- **THEN** it reads the values of group 1

#### Scenario: A reader with a Symbol key and a loaded association

- **WHEN** the `custom_field_values` association of a record is loaded, and `get_field_values` gets
  `:note` as the key
- **THEN** it reads the values of the slug `note`

#### Scenario: A reader with a list of keys and a loaded association

- **WHEN** the `custom_field_values` association of a record is loaded, and `get_field_values` gets
  `['note', :other]` as the key
- **THEN** it reads the values of the slugs `note` and `other`

#### Scenario: A reader with an Integer key and a loaded association

- **WHEN** the `custom_field_values` association of a record is loaded, and `get_field_values` gets
  `5` as the key
- **THEN** it reads the values of the slug `5`

#### Scenario: A reader with a Range key and a loaded association

- **WHEN** the `custom_field_values` association of a record is loaded, and `get_field_values` gets
  `'n'..'o'` as the key
- **THEN** it reads the values of the slug `note`, and no value of the slug `other`

#### Scenario: A reader with a list in a list and a loaded association

- **WHEN** the `custom_field_values` association of a record is loaded, and `get_field_values` gets
  `[['note', 'other']]` as the key
- **THEN** it reads the values of the slugs `note` and `other`

#### Scenario: get_fields_grouped with a Symbol key

- **WHEN** `get_fields_grouped` gets `[:note]` as the list of keys
- **THEN** each group gives the values of the slug `note` under the key `:note`

#### Scenario: get_fields_grouped with an Integer key

- **WHEN** `get_fields_grouped` gets `[5]` as the list of keys
- **THEN** each group gives the values of the slug `5` under the key `5`

#### Scenario: get_fields_grouped with a Range key

- **WHEN** `get_fields_grouped` gets `['n'..'o']` as the list of keys
- **THEN** each group gives the values of the slug `note` under the Range

#### Scenario: A reader with a list of group numbers

- **WHEN** `get_field_values` gets `[0, 1]` as the group number, with or without a loaded
  association
- **THEN** it reads the values of group 0 and of group 1

#### Scenario: A reader with a list that holds an invalid group number

- **WHEN** `get_field_values` gets `[1, '1abc']` as the group number
- **THEN** it reads no value

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
