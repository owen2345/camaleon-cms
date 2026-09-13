## MODIFIED Requirements

### Requirement: set_meta keeps the caller's value on the writing instance

A value written with `set_meta` SHALL be returned by `get_meta` on the same instance as the object the
caller passed, with the caller's own keys, until the record is loaded again. An empty string SHALL be the
exception: `get_meta` SHALL read it as a meta with no value and return the caller's default, as a reloaded
record does.

#### Scenario: A plugin reads back the hash it wrote

- **WHEN** a hash with Symbol keys is written with `set_meta`
- **THEN** `get_meta` on the same instance returns that same hash object

#### Scenario: A meta written as an empty string

- **WHEN** a meta is written with `set_meta` as an empty string and read with a default
- **THEN** the same instance and a reloaded record return that default

## ADDED Requirements

### Requirement: Each read of a meta with no value returns its caller's default

When a record has no row for a meta, or the meta's stored value is an empty string, each `get_meta` call
SHALL return the default passed to that call. It SHALL NOT return a default an earlier call passed, or a
change a caller made to that default in place. This SHALL hold whether the record's metas are eager-loaded
or read from the database. Reading the meta again on the same instance SHALL NOT query the database again
until the meta is written or deleted.

#### Scenario: A missing meta read with different defaults

- **WHEN** a post with no `gallery` meta reads it without a default and then with an empty array as the
  default
- **THEN** the first read returns nil and the second returns an empty array
- **AND** the same two reads return the same values on a freshly loaded post and on a post loaded with its
  metas eager-loaded

#### Scenario: A default changed in place

- **WHEN** a caller appends to the empty array returned as a missing meta's default, without writing it
  with `set_meta`, and the meta is read again with an empty array as the default
- **THEN** the later read returns an empty array

#### Scenario: A meta stored as an empty string

- **WHEN** a record's stored value for a meta is an empty string, and the meta is read without a default
  and then with a default
- **THEN** the first read returns nil and the second returns that default

#### Scenario: Repeated reads of a missing meta

- **WHEN** a post loaded without its metas reads a missing meta three times: with no default, with an empty
  array and with an empty hash
- **THEN** one database query reads the post's metas
