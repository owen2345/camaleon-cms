## MODIFIED Requirements

### Requirement: set_meta keeps the caller's value on the writing instance

A value written with `set_meta` SHALL be returned by `get_meta` on the same instance as the object the
caller passed, with the caller's own keys, until the record is loaded again. A record not yet saved
SHALL keep it until its first save, after which the instance reads what it stored. When the value is
the record's options, `options` and `get_option` on that instance SHALL find an option by a String key
or its Symbol twin, as a freshly loaded record does, whether the caller passed a plain Hash, request
parameters or a JSON string.

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
