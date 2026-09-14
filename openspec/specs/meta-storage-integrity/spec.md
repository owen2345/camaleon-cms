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

### Requirement: delete_meta removes the key from memory as well as storage

`delete_meta` SHALL remove the key's stored rows and the metas the record holds for it on its `metas`
association: loaded copies of those rows, and metas built with `set_meta` and not yet saved. `get_meta` on
that instance SHALL then return the default, and a save SHALL NOT store a deleted built meta. Metas for
other keys, and a stored row an unsaved record holds for another record, SHALL remain. A meta queued in
`data_metas` or `data_options` is out of scope: the next save writes it.

#### Scenario: A meta deleted from eager-loaded metas

- **WHEN** a site loaded with its metas deletes a meta
- **THEN** the same instance and a freshly loaded site read the default for that key

#### Scenario: A meta deleted before it is saved

- **WHEN** a meta set with `set_meta` on an unsaved user, or built on a saved post, is deleted and the record
  is saved
- **THEN** no row is stored for that key

#### Scenario: A sibling meta pending on the same record

- **WHEN** an unsaved user with two metas set deletes one of them and is saved
- **THEN** the other meta is stored

#### Scenario: A stored row held by an unsaved record

- **WHEN** an unsaved post holding another post's stored metas deletes one of their keys
- **THEN** the other post still reads that meta

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

### Requirement: An options row that is not an object reads as empty

When a record's stored options meta (`_default`, or another options meta key) holds a value that is not a JSON object, reading the options or an option SHALL return the empty set or the caller's default, and writing an option SHALL start from an empty set, so no reader or writer raises on the row. The stored row SHALL be left as it is until an option is written to it.

#### Scenario: Options are read from a string row

- **WHEN** a post's `_default` meta holds the string `corrupt` and its option `status_default` is read with a default
- **THEN** the default is returned and nothing raises

#### Scenario: An option is written over a string row

- **WHEN** a post's `_default` meta holds the string `corrupt` and `status_default` is set
- **THEN** the options hold `status_default` and nothing raises

#### Scenario: Pages of a post with a string row render

- **WHEN** a post's `_default` meta holds a string and its admin edit page, its public page and its trash action are requested
- **THEN** each responds as for a post with no options

### Requirement: Meta and option writers refuse a container that is not a set of fields

`set_metas` and `set_options` SHALL accept only a set of fields (a Hash, or request parameters) or nothing. A container that is present but not a set of fields, such as an array of pairs or a scalar, SHALL raise an argument error and store nothing. A `data_options` or `data_metas` value that is present but not a set of fields SHALL be refused the same way before the record's row is written, so no row is left behind it; a blank one SHALL be ignored. An admin save that passes such a container from the request SHALL answer with an error message on the submitted form's page, not a server error, and SHALL store none of it.

#### Scenario: An array of pairs is refused by the writer

- **WHEN** `set_metas` is called with `[["k", "v"]]`
- **THEN** it raises and no meta row is written

#### Scenario: A queued container that is not a set of fields

- **WHEN** a post type is saved with a JSON string in `data_options`, or a post with an array of pairs in
  `data_metas`, inside an enclosing transaction
- **THEN** the save raises the argument error and no row is stored

#### Scenario: A category save with an array container answers with a message

- **WHEN** an administrator saves a category with `meta[]=x`
- **THEN** the response redirects back with an error message and no option is stored

#### Scenario: A site settings save with an array of pairs stores nothing

- **WHEN** an administrator saves the site settings with a JSON `metas` array of pairs
- **THEN** the response carries an error message and none of the pairs is stored

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

### Requirement: A copied or reloaded record does not reuse memoized values

A value a record memoizes for the request through `cama_fetch_cache`, which is how its meta and option
reads, a category's post type, a post's parents and a decorator's rendered fields are memoized, SHALL
belong to that instance and the state it loaded. A copy made with `dup` SHALL start without the
original's memoized values and, for an unsaved original, without its unsaved metas, so copies do not
read each other's writes. `reload` SHALL drop them once it has replaced the record's state, so reads
after it return the stored values, and SHALL leave them when it fails; it SHALL also rebuild the
record's ability and a user's role, whose stored inputs may have changed since. A refresh of the
`metas` association alone (`metas.reload`, `metas.reset`) does not drop them; `cama_clear_cache` drops
them on demand. A site's languages SHALL follow its languages meta as any other meta read does. A post
SHALL read the request's user and site from `CurrentRequest` as every record does, not from a class
attribute.

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

#### Scenario: Permissions checked on a post

- **WHEN** a post checks a permission for the request's user, whose role is then granted it through
  another instance, and the post is reloaded
- **THEN** the first check answers false and the check after the reload answers true

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
release stored as `t` or `f` SHALL read as the boolean and SHALL be stored again as its JSON literal on
that read, except where writes are prevented, where the row is left for a later read.

#### Scenario: A false flag read after a reload

- **WHEN** `set_meta` stores `false` and the record is reloaded or loaded again
- **THEN** `get_meta` returns `false`, not the caller's default and not a String

#### Scenario: A boolean stored by an earlier release

- **WHEN** a row holds `f` and the record's meta is read
- **THEN** `get_meta` returns `false` and the row holds `false`, unless writes are prevented, when only the
  read happens

#### Scenario: Hashes in a stored array

- **WHEN** an array of hashes with Symbol keys is stored and the record is reloaded
- **THEN** each hash reads by its Symbol and by its String key
