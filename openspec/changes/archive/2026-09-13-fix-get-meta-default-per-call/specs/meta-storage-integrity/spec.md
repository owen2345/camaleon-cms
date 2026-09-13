## MODIFIED Requirements

### Requirement: set_meta keeps the caller's value on the writing instance

A value written with `set_meta` SHALL be returned by `get_meta` on the same instance as the object the
caller passed, with the caller's own keys, until the record is loaded again or an option writer on that
instance stores its own indifferent hash, which `get_meta` returns from then on, the caller's hash left
as passed. An empty string SHALL be the exception: `get_meta` SHALL read it as a meta with no value and
return the caller's default, as a reloaded record does. A record not yet saved SHALL keep it until its
first save, after which the instance reads what it stored. When the value is the record's options,
`options` and `get_option` on that instance SHALL find an option by a String key or its Symbol twin, as a
freshly loaded record does, whether the caller passed a plain Hash, request parameters or a JSON string.
The copy `options` returns SHALL share nothing with the caller's value, its nested hashes included, and
SHALL carry no default of the caller's hash, so a missing option reads nil as after a reload.

#### Scenario: A plugin reads back the hash it wrote

- **WHEN** a hash with Symbol keys is written with `set_meta`
- **THEN** `get_meta` on the same instance returns that same hash object

#### Scenario: A new record saved after the write

- **WHEN** a hash is written with `set_meta` on an unsaved post type and the post type is saved
- **THEN** the same instance reads the stored hash by its keys, no longer the caller's object

#### Scenario: A meta written as an empty string

- **WHEN** a meta is written with `set_meta` as an empty string and read with a default
- **THEN** the same instance and a reloaded record return that default

#### Scenario: Options a caller passed to set_meta as a plain Hash

- **WHEN** a post type's options are written with `set_meta` as a plain Hash holding `color` under a String
  key and `size` under a Symbol key
- **THEN** on the same instance, `options` and `get_option` read `color` by its Symbol key and `size` by
  its String key
- **AND** a freshly loaded post type reads the same values
- **AND** `get_meta` on the same instance returns the hash the caller passed, with its own keys

#### Scenario: An option written after set_meta

- **WHEN** a post type's options are written with `set_meta` as a plain Hash and an option is then set on
  the same instance
- **THEN** `get_meta` on that instance returns the writer's hash, holding both, not the caller's hash
- **AND** the caller's hash holds only what it passed

#### Scenario: Options a caller passed to set_meta as request parameters

- **WHEN** a post type's options are written with `set_meta` as request parameters holding `color` and a
  nested `sizes`
- **THEN** on the same instance, `options` reads `color` by its String key and by its Symbol key, and
  `get_option` reads it
- **AND** `options` is an indifferent hash whose `sizes` is a hash, and the parameters stay unpermitted
- **AND** an option set on the same instance is stored beside `color` and `sizes`, and the instance reads
  what a freshly loaded post type reads

#### Scenario: Options a caller passed to set_meta as a JSON string

- **WHEN** a post type's options are written with `set_meta` as a JSON string holding `has_tags`
- **THEN** on the same instance, `options` and `get_option` read `has_tags`
- **AND** an option set on the same instance is stored beside it, and the same instance and a freshly loaded
  post type read both

#### Scenario: A plain Hash with a default

- **WHEN** a post type's options are written with `set_meta` as a Hash whose default proc stores an empty
  array for a missing key, and options are set and a missing option read on the same instance
- **THEN** the missing option reads nil, on the read and in `manage_categories?`
- **AND** a freshly loaded post type holds only the options written

#### Scenario: A plain Hash with a nested indifferent hash

- **WHEN** a post type's options are written with `set_meta` as a plain Hash holding an indifferent hash
  under `theme` and one inside an array under `sizes`, and a nested option of each is changed on the hash
  `options` returns
- **THEN** the caller's hashes still hold their values
- **AND** `get_meta` on the same instance returns the hash the caller passed

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
