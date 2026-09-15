## MODIFIED Requirements

### Requirement: set_meta keeps the caller's value on the writing instance

A value written with `set_meta` SHALL be returned by `get_meta` on the same instance as the object the
caller passed, with the caller's own keys, until the record is loaded again or an option writer on that
instance stores its own indifferent hash, which `get_meta` returns from then on, the caller's hash left
as passed. A record not yet saved SHALL keep it until its first save, after which the instance reads what
it stored. When the value is
the record's options, `options` and `get_option` on that instance SHALL find an option by a String key
or its Symbol twin, as a freshly loaded record does, whether the caller passed a plain Hash, request
parameters or a JSON string. The copy `options` returns SHALL share nothing with the caller's value, its
nested hashes included, and SHALL carry no default of the caller's hash, so a missing option reads nil as
after a reload.

#### Scenario: A plugin reads back the hash it wrote

- **WHEN** a hash with Symbol keys is written with `set_meta`
- **THEN** `get_meta` on the same instance returns that same hash object

#### Scenario: A new record saved after the write

- **WHEN** a hash is written with `set_meta` on an unsaved post type and the post type is saved
- **THEN** the same instance reads the stored hash by its keys, no longer the caller's object

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

### Requirement: An options row that is not an object reads as empty

When a record's stored options meta (`_default`, or another options meta key) holds a value that is not a JSON object, or the options the instance holds are nil or an empty string (a record with no options row, whether or not `get_meta` was asked for them first, or `set_meta` wrote nil or an empty string), reading the options or an option SHALL return the empty set or the caller's default, and writing an option SHALL start from an empty set, so no reader or writer raises, on the writing instance and on a freshly loaded record. The empty set `options` returns SHALL be a new hash on each read until an option is written, so a change made to it without an option writer is neither read back nor stored. The stored row SHALL be left as it is until an option is written to it.

#### Scenario: Options are read from a string row

- **WHEN** a post's `_default` meta holds the string `corrupt` and its option `status_default` is read with a default
- **THEN** the default is returned and nothing raises

#### Scenario: An option is written over a string row

- **WHEN** a post's `_default` meta holds the string `corrupt` and `status_default` is set
- **THEN** the options hold `status_default` and nothing raises

#### Scenario: Pages of a post with a string row render

- **WHEN** a post's `_default` meta holds a string and its admin edit page, its public page and its trash action are requested
- **THEN** each responds as for a post with no options

#### Scenario: A record with no options row

- **WHEN** a post with no options row has its options read with `get_meta` without a default, and then
  its options are read and an option is set on the same instance
- **THEN** `options` is empty and `get_option` returns the caller's default
- **AND** the same instance and a freshly loaded post read the option that was set

#### Scenario: A change made to the empty options of a record with no options row

- **WHEN** a post with no options row has a key set on the hash `options` returns, and then an option is
  set on the same instance
- **THEN** the same instance does not read that key
- **AND** a freshly loaded post holds only the option that was set

#### Scenario: Options written as nil or as an empty string

- **WHEN** a post's options are written with `set_meta` as nil, or as an empty string
- **THEN** `options` is empty and `get_option` returns the caller's default, on the same instance and on a
  freshly loaded post
- **AND** an option set on the freshly loaded post is read by a post loaded afterwards

### Requirement: Options and metas given to a save are written once

Options and metas assigned through `data_options` and `data_metas` SHALL be written by the first save
of the record that completes, and a later save of the same instance SHALL NOT write them again; once
written, both accessors SHALL read `nil`. The metas SHALL be written before the options, so a
`_default` meta given in `data_metas` merges with `data_options` instead of replacing them. When the
transaction that wrote them is rolled back, they SHALL be queued again for the record's next save,
keeping any value queued since, and a record whose creation was rolled back SHALL store the metas
built before that save too; a rollback of a later transaction of the instance SHALL leave them
written. A post type SHALL fill its default options in under the options set on the record before
its first save and under the ones given. A copy made with `dup` SHALL carry no record of the
original's write and SHALL queue only values given to the copy.

#### Scenario: A post type updated after an option write

- **WHEN** a post type created with `has_category` in `data_options` sets `has_category` to `false` and is
  then renamed
- **THEN** the same instance and a freshly loaded post type read `has_category` as `false`

#### Scenario: A post updated after new option and meta writes

- **WHEN** a post created or updated with `data_options` and `data_metas` writes new values for those keys
  and is then updated again
- **THEN** the same instance and a freshly loaded post read the new values

#### Scenario: A post type created with data_metas

- **WHEN** a post type is created with `data_metas`
- **THEN** a freshly loaded post type reads those metas

#### Scenario: A post type created with a `_default` meta and options

- **WHEN** a post type is created with `has_category` in `data_options` and a `_default` meta holding
  `has_tags`
- **THEN** a freshly loaded post type reads both, its remaining defaults, and has its default category

#### Scenario: An option set before a post type's first save

- **WHEN** an unsaved post type given `data_options` sets one of the default options and is saved
- **THEN** a freshly loaded post type reads the option it set, the options given and the remaining
  defaults, from one options row

#### Scenario: A meta built before a post type's first save

- **WHEN** an unsaved post type given a meta in `data_metas` sets the same meta and is saved
- **THEN** its loaded metas and a freshly loaded post type both read the value given in `data_metas`

#### Scenario: A save rolled back after writing them

- **WHEN** a post type's creation, with a meta set before it, raises in a later callback, or a post's
  update given `data_options` and `data_metas` is rolled back by an enclosing transaction, and the
  instance is saved again
- **THEN** a freshly loaded record reads the queued values and the meta set before the creation, each
  stored once

#### Scenario: A later save of the instance rolled back

- **WHEN** a post created with `data_options` sets an option, has a later update rolled back and is
  updated again
- **THEN** a freshly loaded post reads the option set after the creation

#### Scenario: A copy saved inside the rolled-back transaction of the original's write

- **WHEN** a post created with `data_options` is copied, the copy is saved inside the same transaction,
  and the transaction is rolled back
- **THEN** the copy has nothing queued and a value queued on one of them is not queued on the other

#### Scenario: A post type created with only a `_default` meta

- **WHEN** a post type is created with a `_default` meta holding `has_tags` under a String key in
  `data_metas` and no `data_options`
- **THEN** the same instance manages tags
- **AND** a freshly loaded post type reads `has_tags` and its remaining defaults, from one options row

#### Scenario: A post type created with a `_default` meta as request parameters

- **WHEN** a post type is created with `data_metas` given as request parameters holding a `_default` meta
  with `has_category`
- **THEN** the same instance manages categories and has its default category
- **AND** a freshly loaded post type reads `has_category` and its remaining defaults, from one options row
