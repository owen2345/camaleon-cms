# meta-storage-integrity Specification

## Purpose
Records store their options and metas as JSON rows. Plugins and themes read them back through the meta
API, both on the instance that wrote them and after a reload. This capability pins what a write stores
and what a read returns, so a value is never lost or reverted by key types, repeated keys in stored JSON,
or duplicate rows.

## Requirements

### Requirement: Option writes store one entry per key whatever its type

Writing an option with `set_option`, `set_options` or `delete_option` SHALL treat a String key and its
Symbol twin as the same option. A write SHALL replace the other type's entry rather than store the key
twice. The writing instance SHALL read the option back by either key type, as a reloaded record does.

#### Scenario: A String-keyed option after Symbol-keyed defaults

- **WHEN** a post type, whose creation stored its default options with Symbol keys, sets `has_category`
  with a String key
- **THEN** the stored options hold `has_category` once
- **AND** both the same instance and a reloaded post type read it as the new value

#### Scenario: An option is deleted by the other key type

- **WHEN** a record's options hold `color` under a String key and `size` under a Symbol key, and `color`
  is deleted with a Symbol key and `size` with a String key
- **THEN** a reloaded record holds no options

#### Scenario: A record's first option is written with a String key

- **WHEN** a record with no stored options sets an option with a String key
- **THEN** the same instance reads that option back by its Symbol key

### Requirement: set_meta keeps the caller's value on the writing instance

A value written with `set_meta` SHALL be returned by `get_meta` on the same instance as the object the
caller passed, with the caller's own keys, until the record is loaded again.

#### Scenario: A plugin reads back the hash it wrote

- **WHEN** a hash with Symbol keys is written with `set_meta`
- **THEN** `get_meta` on the same instance returns that same hash object

### Requirement: Hash and Array values are stored with one entry per key

A Hash or Array value written as a meta or as a custom-field value SHALL be stored as JSON with one entry
per key at any depth. When the value holds a key as both a String and a Symbol, the value written last
for that key SHALL be stored. The write MUST NOT fail or store a repeated key.

#### Scenario: A meta hash merges Symbol defaults with String-keyed input

- **WHEN** a meta is written with a hash holding `sec` as both a Symbol and a String key, or with an array
  containing such a hash
- **THEN** the stored JSON holds `sec` once, with the String key's value

#### Scenario: A custom-field value holds a key twice

- **WHEN** a custom-field value is written with a hash holding `a` as both a Symbol and a String key
- **THEN** the stored JSON holds `a` once, with the value written last

### Requirement: A stored meta that repeats a key reads with its last value

Reading a meta whose stored JSON repeats a key, as earlier releases could write it, SHALL return the
parsed value with that key's last value. This SHALL hold on every supported json version, with no parse
failure and no json deprecation warning.

#### Scenario: Options stored with a repeated key

- **WHEN** a record's stored options hold `has_category` twice, `false` and then `true`
- **THEN** reading the option returns `true`
- **AND** no duplicate-key warning is emitted

### Requirement: Writes and reads agree on a key with several rows

When a record holds more than one meta row for a key, a write SHALL update the row with the lowest id,
and a read SHALL return that same row. This SHALL hold whether the read loads the row from the database
or finds it among eager-loaded metas.

#### Scenario: A write reaches the row reads return

- **WHEN** a record has two rows for a key, the database returns unordered rows in reverse, and a value
  is written for the key
- **THEN** a freshly loaded record reads the written value

#### Scenario: Eager-loaded and database reads agree

- **WHEN** a record with two rows for a key is read once with its metas eager-loaded and once without
- **THEN** both reads return the same row's value

### Requirement: A meta built before the first save is not duplicated on create

A meta set on a record before its first save SHALL be stored as one row. Options or metas saved while the
record is created, such as creation-time options, SHALL update that pending meta rather than store a
second row with the same key.

#### Scenario: Options set before and while creating a post

- **WHEN** a new post gets an option before its first save and is saved with creation-time options
- **THEN** the post has one options row, holding both values
