## ADDED Requirements

### Requirement: A copied or reloaded record does not reuse memoized values

A value a record memoizes for the request through `cama_fetch_cache`, which is how its meta and option
reads, a category's post type, a post's parents and a decorator's rendered fields are memoized, SHALL
belong to that instance and the state it loaded. A copy made with `dup` SHALL start without the
original's memoized values and, for an unsaved original, without its unsaved metas, so copies do not
read each other's writes. `reload` SHALL drop them once it has replaced the record's state, so reads
after it return the stored values, and SHALL leave them when it fails; it SHALL also rebuild the
record's ability and a user's role, whose stored inputs may have changed since. A refresh of the
`metas` association alone (`metas.reload`, `metas.reset`) does not drop them; `cama_clear_cache` drops
them on demand. A site's languages SHALL follow its languages meta as any other meta read does.

#### Scenario: Two copies of a post

- **WHEN** two copies are made of a post whose options were read, and one copy sets an option
- **THEN** the other copy does not read that option

#### Scenario: A copy of an unsaved post

- **WHEN** a meta is set on an unsaved post and the post is copied
- **THEN** the copy reads no value for it and holds no meta

#### Scenario: A post reloaded after another instance's write

- **WHEN** a post writes and reads a meta, another instance of the post writes a new value, and the
  first post is reloaded
- **THEN** the reloaded post reads the new value

#### Scenario: A derived value after a reload

- **WHEN** a value memoized through `cama_fetch_cache` is read after the record is reloaded
- **THEN** it is computed again

#### Scenario: A reload that fails

- **WHEN** a post's row was deleted elsewhere and the post is reloaded
- **THEN** the reload raises and the post still reads the meta it memoized

#### Scenario: Permissions after a reload

- **WHEN** a user's role is granted a permission through another instance and the user is reloaded
- **THEN** the user's permission check reflects the grant

#### Scenario: A user's role after a reload

- **WHEN** a user's role is changed through another instance and the user is reloaded
- **THEN** the user reads the role assigned since

#### Scenario: A site's languages after another instance's write

- **WHEN** a site's languages are stored through another instance and the site is reloaded, or stored
  on the site itself
- **THEN** it reads the stored languages

### Requirement: A boolean and the hashes in an array read back as written

A boolean written with `set_meta` SHALL be stored so that every read, on the writing instance, after a
reload and on a freshly loaded record, returns the boolean rather than the text column's cast of it.
The hashes inside a stored array SHALL read by either key type, as a stored hash does. A row an earlier
release stored as `t` or `f` SHALL read as that String.

#### Scenario: A false flag read after a reload

- **WHEN** `set_meta` stores `false` and the record is reloaded or loaded again
- **THEN** `get_meta` returns `false`, not the caller's default and not a String

#### Scenario: Hashes in a stored array

- **WHEN** an array of hashes with Symbol keys is stored and the record is reloaded
- **THEN** each hash reads by its Symbol and by its String key

## MODIFIED Requirements

### Requirement: Option writes store one entry per key whatever its type

Writing an option with `set_option`, `set_options` or `delete_option` SHALL treat a String key and its
Symbol twin as the same option. A write SHALL replace the other type's entry rather than store the key
twice. The writing instance SHALL read the option back by either key type, as a freshly loaded record
does.

#### Scenario: A String-keyed option after Symbol-keyed defaults

- **WHEN** a post type, whose creation stored its default options with Symbol keys, sets `has_category`
  with a String key
- **THEN** the stored options hold `has_category` once
- **AND** both the same instance and a freshly loaded post type read it as the new value

#### Scenario: An option is deleted by the other key type

- **WHEN** a record's options hold `color` under a String key and `size` under a Symbol key, and `color`
  is deleted with a Symbol key and `size` with a String key
- **THEN** a freshly loaded record holds no options

#### Scenario: A record's first option is written with a String key

- **WHEN** a record with no stored options sets an option with a String key
- **THEN** the same instance reads that option back by its Symbol key

### Requirement: set_meta keeps the caller's value on the writing instance

A value written with `set_meta` SHALL be returned by `get_meta` on the same instance as the object the
caller passed, with the caller's own keys, until the record is loaded again. A record not yet saved
SHALL keep it until its first save, after which the instance reads what it stored.

#### Scenario: A plugin reads back the hash it wrote

- **WHEN** a hash with Symbol keys is written with `set_meta`
- **THEN** `get_meta` on the same instance returns that same hash object

#### Scenario: A new record saved after the write

- **WHEN** a hash is written with `set_meta` on an unsaved post type and the post type is saved
- **THEN** the same instance reads the stored hash by its keys, no longer the caller's object

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
