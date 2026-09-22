## RENAMED Requirements

- FROM: `### Requirement: set_meta keeps the caller's value on the writing instance`
- TO: `### Requirement: set_meta reads back on the writing instance as a reloaded record does`

## MODIFIED Requirements

### Requirement: set_meta reads back on the writing instance as a reloaded record does

A value written with `set_meta` SHALL be returned by `get_meta` on the same instance in the form a freshly
loaded record reads it: a Hash, an Array or request parameters as the indifferent hash, or array, their
JSON parses to; a String holding JSON as the value it holds; a numeric or boolean String as the number or
the boolean; a String or a Symbol `t` or `f`, stored as its JSON string, as that String; any other String as a plain
String, not html_safe even when the caller's was; a value of another class, such as a BigDecimal, a Time
or a Date, as its stored text reads, a BigDecimal as a Float and a Time or a Date as that text; nil or an
empty string as a meta with no value, so the caller's default is returned. An object the caller passed SHALL be
left as passed and SHALL NOT be returned by a read, so a change made to it after the write is not read,
unless it is the Hash or the Array the instance handed out for that key: written back, that object SHALL
take the stored form in place and remain the one the instance reads, unless it is frozen, when the stored
form SHALL be memoized apart from it, so a hash `options` returned keeps
reading every later option write on the instance; when that write raises, refused or failed, the object
SHALL take the form the key's stored row reads as again. A record not yet saved SHALL read a written value the
same way until its first save, after which the instance reads what it stored. When the value is the record's options, `options` and `get_option` on that instance SHALL
find an option by a String key or its Symbol twin, as a freshly loaded record does, whether the caller
passed a plain Hash, request parameters or a JSON string. The hash `options` returns SHALL share nothing
with the caller's value, its nested hashes included, and SHALL carry no default of the caller's hash, so a
missing option reads nil as after a reload. `set_meta` SHALL return the value passed, whatever form a read
returns for it, and `set_options` and `delete_option` SHALL return the options the instance reads after the
write, the hash `options` returns, on a record's first options write too.

#### Scenario: A plugin reads back the hash it wrote

- **WHEN** a hash with Symbol keys is written with `set_meta` and a key is then added to the caller's hash
- **THEN** `get_meta` on the same instance returns an indifferent hash holding the values written, read by
  either key type, not the caller's object, and without the key added afterwards

#### Scenario: A string that stores as a number, a boolean or JSON

- **WHEN** `'2024'`, `'false'` and `'[1, 2]'` are written with `set_meta`
- **THEN** the same instance reads `2024`, `false` and `[1, 2]`, as a freshly loaded record does

#### Scenario: A one-letter t or f

- **WHEN** `'t'` and `'f'` are written with `set_meta`, as Strings and as Symbols
- **THEN** the same instance and a freshly loaded record read the Strings `'t'` and `'f'`
- **AND** a row an earlier release stored as the bare letter still reads as the boolean

#### Scenario: A BigDecimal, a Time and a Date

- **WHEN** a `BigDecimal`, a `Time` and a `Date` are written with `set_meta`
- **THEN** the same instance reads a Float and two Strings, as a freshly loaded record does

#### Scenario: A plugin reads back the text it wrote

- **WHEN** a String holding no JSON is written with `set_meta` and the caller's String is then changed in
  place
- **THEN** `get_meta` on the same instance returns the text as written, not the caller's object
- **AND** an html_safe String written the same way reads back as a plain String, as a freshly loaded
  record reads it

#### Scenario: A new record saved after the write

- **WHEN** a hash is written with `set_meta` on an unsaved post type and the post type is saved
- **THEN** the same instance reads the stored hash by its keys before and after the save

#### Scenario: A meta written as nil or as an empty string

- **WHEN** a meta is written with `set_meta` as nil, or as an empty string, and read with a default
- **THEN** the same instance and a reloaded record return that default

#### Scenario: What set_meta returns

- **WHEN** `'false'`, `'null'` and request parameters are written with `set_meta`, and options with
  `set_options` and `delete_option`
- **THEN** `set_meta` returns the String `'false'`, the String `'null'` and the parameters object passed
- **AND** the option writers return the hash `options` returns afterwards, from a record's first options
  write on

#### Scenario: A hash options returned before option writes

- **WHEN** a post type's options are read, and options are then set, set in bulk and deleted on the same
  instance
- **THEN** the hash read first is the one `options` returns, holding every write

#### Scenario: A hash or a list read from the record and written back

- **WHEN** a hash read with `get_meta` is changed and written back with `set_meta`, an option is set, and
  the hash is written back again; and a list read with `get_meta` is changed and written back
- **THEN** a freshly loaded post type holds both the change and the option
- **AND** `get_meta` on the writing instance returns the list that was written back

#### Scenario: A frozen hash read from the record and written back

- **WHEN** a hash read with `get_meta` is changed, frozen and written back with `set_meta`
- **THEN** the write is stored without raising and the instance reads the stored form, not the frozen hash

#### Scenario: A hash handed out and written back by a refused write

- **WHEN** a post type's options are read, changed in place and written back with `set_meta`, and the
  write is refused
- **THEN** the options the instance reads, the hash read among them, hold what is stored
- **AND** a later option write on the instance is stored

#### Scenario: Options a caller passed to set_meta as a plain Hash

- **WHEN** a post type's options are written with `set_meta` as a plain Hash holding `color` under a String
  key and `size` under a Symbol key
- **THEN** on the same instance, `options` and `get_option` read `color` by its Symbol key and `size` by
  its String key
- **AND** a freshly loaded post type reads the same values
- **AND** the caller's hash keeps its own keys, and `get_meta` on the same instance returns an indifferent
  hash holding both values

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
- **AND** `get_meta` on the same instance does not return the caller's hash

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

#### Scenario: A row holding a JSON string whose text is an object

- **WHEN** a post's `_default` meta holds a JSON string whose text is an object holding `status_default`
- **THEN** `options` is empty and `get_option` returns the caller's default, on the writing instance and on
  a freshly loaded post

### Requirement: Writes and reads agree on a key with several rows

When a record holds more than one meta row for a key, a write SHALL update the row with the lowest id,
and a read SHALL return that same row. This SHALL hold whether the read loads the row from the database
or finds it among eager-loaded metas. A meta built for the key on a saved record and not saved yet SHALL
NOT take a write from the stored row, nor be read in its place.

#### Scenario: A write reaches the row reads return

- **WHEN** a record has two rows for a key, the database returns unordered rows in reverse, and a value
  is written for the key
- **THEN** a freshly loaded record reads the written value

#### Scenario: Eager-loaded and database reads agree

- **WHEN** a record with two rows for a key is read once with its metas eager-loaded and once without
- **THEN** both reads return the same row's value

#### Scenario: A meta built for a key the record stores

- **WHEN** a saved post type, loaded with its metas eager-loaded or without them, builds a meta for a key
  it stores, writes the key and is saved
- **THEN** a freshly loaded post type reads the written value

#### Scenario: A meta built for a key the record stores, read from eager-loaded metas

- **WHEN** a post type loaded with its metas eager-loaded builds a meta for a key it stores and one for a
  key it does not store
- **THEN** a read of the first key returns the stored row's value, and a read of the second the built meta's

### Requirement: A meta built before the first save is not duplicated on create

A meta set on a record before its first save SHALL be stored as one row. Options or metas saved while the
record is created, such as creation-time options, SHALL update that pending meta rather than store a
second row with the same key. A record not saved yet, before its first save or once its creation is
rolled back, SHALL read the metas built on it, which its next save stores.

#### Scenario: Options set before and while creating a post

- **WHEN** a new post gets an option before its first save and is saved with creation-time options
- **THEN** the post has one options row, holding both values

#### Scenario: A meta built on a record not saved yet

- **WHEN** a meta is built on an unsaved post and read with a default
- **THEN** the built value is returned

#### Scenario: A creation rolled back

- **WHEN** a post type created with a meta in `data_metas` and an option in `data_options` has its
  creation rolled back
- **THEN** the unsaved post type reads that meta and that option

### Requirement: Options and metas given to a save are written once

Options and metas assigned through `data_options` and `data_metas` SHALL be written by the first save
of the record that completes, and a later save of the same instance SHALL NOT write them again; once
written, both accessors SHALL read `nil`. The metas SHALL be written before the options, so a
`_default` meta given in `data_metas` merges with `data_options` instead of replacing them. When the
transaction that wrote them is rolled back, they SHALL be queued again for the record's next save,
keeping any value queued since, and a record whose creation was rolled back SHALL store the metas
built before that save too; a rollback of a later transaction of the instance SHALL leave them
written. A record whose creation is rolled back, whether or not it was given any, SHALL have the metas
it holds built again for its next save and SHALL read them, not a value it memoized before or while it
was created. A post type SHALL fill its default options in under the options set on the record before
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

#### Scenario: The first update after a creation rolled back

- **WHEN** a post created with a meta in `data_metas` has its first update, given a new value for that meta
  in `data_metas`, rolled back, and is saved again
- **THEN** it holds one row for the meta, and a freshly loaded post reads the new value

#### Scenario: A creation rolled back after a meta was written twice

- **WHEN** a post type sets a meta, is saved and sets the meta again inside a transaction that is rolled
  back, and is saved again
- **THEN** the value it reads after the rollback is the one it reads after that save, and the one a
  freshly loaded post type reads

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

## ADDED Requirements

### Requirement: Each read of a meta with no value returns its caller's default

When a record has no row for a meta, or the meta's stored value is null or an empty string, each `get_meta`
call SHALL return the default passed to that call. It SHALL NOT return a default an earlier call passed, or a
change a caller made to that default in place, and what the instance memoizes for a key with no row SHALL
be nil. This SHALL hold whether the record's metas are eager-loaded or read from the database. `get_option`
SHALL likewise return its default for an option whose value is null or an empty string. Reading the meta
again on the same instance SHALL NOT query the database again until the meta is written or deleted on it,
or the instance drops its memoized values (a reload, a copy, a rolled-back write, `cama_clear_cache`), as
the requirement on memoized values states.

#### Scenario: A missing meta read with different defaults

- **WHEN** a post with no `gallery` meta reads it without a default and then with an empty array as the
  default
- **THEN** the first read returns nil and the second returns an empty array
- **AND** the same two reads return the same values on a post loaded with its metas eager-loaded, without
  a query

#### Scenario: A default changed in place

- **WHEN** a caller appends to the empty array returned as a missing meta's default, without writing it
  with `set_meta`, and the meta is read again with an empty array as the default
- **THEN** the later read returns an empty array

#### Scenario: A meta stored as an empty string

- **WHEN** a record's stored value for a meta is an empty string, and the meta is read without a default
  and then with a default
- **THEN** the first read returns nil and the second returns that default

#### Scenario: A meta stored as null

- **WHEN** a record's stored value for a meta is null, and the meta is read with a default
- **THEN** that default is returned, on the writing instance and on a freshly loaded record

#### Scenario: An option stored as null

- **WHEN** a record's options hold `color` as null and `size` as an empty string, and each is read with
  `get_option` and a default
- **THEN** both reads return that default, on the writing instance and on a freshly loaded record

#### Scenario: Repeated reads of a missing meta

- **WHEN** a post loaded without its metas reads a missing meta three times, with no default, with an empty
  array and with an empty hash, and then another missing meta
- **THEN** the metas table is queried once for each of the two keys

#### Scenario: What a read of a missing meta memoizes

- **WHEN** a post loaded without its metas reads a missing meta with a default
- **THEN** the value memoized for the key is nil, and a later read with another default issues no query

### Requirement: Decorator meta reads translate only strings

`the_meta` and `the_option` on a decorated record SHALL return the meta or option read with an empty-string
default: translated for the decoration locale when it is a String; when it is an Array, as an Array of its
items each read as a String and translated, whatever the item holds; and as read when it is a number, a
boolean or a hash; on the writing instance and on a freshly loaded record alike.

#### Scenario: A meta stored as a number

- **WHEN** a post's `year` meta is written as `'2024'` and `the_meta('year')` is read on the writing post and
  on a freshly loaded one
- **THEN** both return `2024`

#### Scenario: A translatable meta

- **WHEN** a post's `greeting` meta holds an English and a Spanish translation and `the_meta('greeting')` is
  read with the Spanish decoration locale
- **THEN** it returns the Spanish text

#### Scenario: An Array holding a number and a boolean

- **WHEN** a post's `mixed` meta and option are written as an Array of a translatable String, `7` and
  `true`, and read with `the_meta` and `the_option` with the Spanish decoration locale, on the writing post
  and on a freshly loaded one
- **THEN** each read returns the Spanish text, `'7'` and `'true'`

#### Scenario: A meta and an option stored as a hash

- **WHEN** a post's `settings` meta and option are written as a hash holding `color` and read with
  `the_meta` and `the_option`, on the writing post and on a freshly loaded one
- **THEN** each read returns an indifferent hash holding `color`

### Requirement: A meta is read by the String form of its key

`get_meta` SHALL look a key up by its String form, as `set_meta` and `delete_meta` store and remove it,
whatever object names the key, so a meta written with a key that is neither a String nor a Symbol reads
back whether the record's metas are eager-loaded or read from the database.

#### Scenario: A meta written with an Integer key

- **WHEN** a post's meta is written with the key `2024` and read with the same key on a post loaded with its
  metas eager-loaded and on one loaded without them
- **THEN** both reads return the value written

### Requirement: An option write that raises leaves the options as stored

When `set_option`, `set_options` or `delete_option` raises, because the write is refused or storing it
fails, the options the instance holds SHALL be those it held before the call, so the instance reads what is
stored without querying the database for it again. They SHALL NOT show a write before it is stored, while
it is checked included.

#### Scenario: A refused option write

- **WHEN** a post type's option write is refused and its options are read again on the same instance
- **THEN** they hold the options stored before the write, read without a metas query

#### Scenario: A failed option write

- **WHEN** storing an option set, set in bulk or deleted on a post raises
- **THEN** the post's options are those stored before each write

#### Scenario: Options read while a write is checked

- **WHEN** the options a post type holds are read while its option write is checked
- **THEN** they do not show that write

