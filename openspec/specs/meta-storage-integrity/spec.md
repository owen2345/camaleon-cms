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
does. `set_options` SHALL skip a nil key and store a key of another type, such as an Integer, under its
text, as `set_option` does. An option writer SHALL leave the value passed as it was, the hashes in a list
included.

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

#### Scenario: Options written with a nil and an Integer key

- **WHEN** a post type and a post are given settings under a nil key, an Integer key and a Symbol key
- **THEN** a freshly loaded record holds the Integer key's setting under its text and the Symbol key's,
  and nothing under the nil key

#### Scenario: A list of hashes passed to an option writer

- **WHEN** a list holding a hash and a list of hashes is written with `set_option`, `set_setting` or
  `set_settings`
- **THEN** the hashes in the caller's list are still the plain hashes passed

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

### Requirement: set_meta reads back on the writing instance as a reloaded record does

A value written with `set_meta` SHALL be returned by `get_meta` on the same instance in the form a freshly
loaded record reads it: a Hash, an Array or request parameters as the indifferent hash, or array, their
JSON parses to; a String holding JSON as the value it holds; a numeric or boolean String as the number or
the boolean; a String or a Symbol `t` or `f`, stored as its JSON string, as that String; any other String as a plain
String in UTF-8, not html_safe even when the caller's was; a value of another class, such as a BigDecimal, a Time
or a Date, as its stored text reads, a BigDecimal as a Float and a Time or a Date as that text; nil or an
empty string as a meta with no value, so the caller's default is returned. An object the caller passed SHALL be
left as passed and SHALL NOT be returned by a read, so a change made to it after the write is not read,
unless it is the Hash or the Array the instance handed out for that key: written back, that object SHALL
take the stored form in place, keeping the values it holds unchanged and its default, and remain the one
the instance reads, unless it is frozen, when the stored form SHALL be memoized apart from it, so a hash
`options` returned, and a hash or list nested in it that a write leaves unchanged, keep reading every
later option write on the instance; when that write raises, refused or failed, the object
SHALL take the form the key's stored row reads as again, and SHALL hold nothing when the row is gone or
holds a value of another kind. A record not yet saved SHALL read a written value the
same way until its first save, after which the instance reads what it stored. A meta written or deleted in a
transaction that is rolled back, with `set_meta`, an option writer or `delete_meta`, SHALL read on the instance
what is stored once the rollback completes, in a hash `options` returned too, and SHALL NOT be stored again by
the record's next save. When the value is the record's options, `options` and `get_option` on that instance SHALL
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
- **AND** a String in another encoding reads back as the same text in UTF-8, as a freshly loaded record
  reads it

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

#### Scenario: A nested option taken from the options before a write of another option

- **WHEN** a post type's options are read, a nested hash is taken from them and a default set on them, and
  another option is written
- **THEN** the nested hash is still the one the options hold, and the default stays
- **AND** a write of that nested option replaces it, leaving the hash taken before as it was

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

#### Scenario: A write the database refuses, with the metas loaded

- **WHEN** a post's metas are eager-loaded and storing a meta, or a list read from the post, changed in place
  and written back, fails in the database
- **THEN** the post reads the value stored before the write, and the list holds it

#### Scenario: A hash or a list handed out and written back by a failed write after its row was deleted

- **WHEN** a post type's options, or a post's list, are read, changed in place, the row is deleted by another
  instance, and the write back with `set_meta` is refused or fails
- **THEN** the hash or the list holds nothing, and the record reads no value for the key

#### Scenario: A direct write rolled back with its transaction

- **WHEN** a post writes a meta and an option inside a transaction that is rolled back, deletes a meta its
  eager-loaded metas hold in another, and creates one in a third before it is saved again
- **THEN** the post reads the meta and the options stored before each transaction, in the options hash it
  handed out too, and its save stores no meta the rollback removed

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

### Requirement: Writes and reads agree on a key with several rows

When a record holds more than one meta row for a key, a write SHALL update the row with the lowest id,
and a read SHALL return that same row. This SHALL hold whether the read loads the row from the database
or finds it among eager-loaded metas. A meta built for the key on a saved record and not saved yet SHALL
NOT take a write from the stored row, nor be read in its place, and a write of a key the record does not
store SHALL store a row, not only set a built meta.

#### Scenario: A write reaches the row reads return

- **WHEN** a record has two rows for a key, the database returns unordered rows in reverse, and a value
  is written for the key
- **THEN** a freshly loaded record reads the written value

#### Scenario: A meta built for a key the record stores

- **WHEN** a saved post type, loaded with its metas eager-loaded or without them, builds a meta for a key
  it stores, writes the key and is saved
- **THEN** a freshly loaded post type reads the written value

#### Scenario: A meta built for a key the record stores, read from eager-loaded metas

- **WHEN** a post type loaded with its metas eager-loaded builds a meta for a key it stores and one for a
  key it does not store
- **THEN** a read of the first key returns the stored row's value, and a read of the second the built meta's

#### Scenario: A meta built for a key the record does not store

- **WHEN** a saved post type, loaded with its metas eager-loaded or without them, builds a meta for a key
  it does not store and writes the key
- **THEN** a freshly loaded post type reads the written value, before and after the post type is saved

#### Scenario: Eager-loaded and database reads agree

- **WHEN** a record with two rows for a key is read once with its metas eager-loaded and once without
- **THEN** both reads return the same row's value

### Requirement: A meta is read by the String form of its key

`get_meta` SHALL look a key up by its String form, as `set_meta` and `delete_meta` store and remove it,
whatever object names the key, so a meta written with a key that is neither a String nor a Symbol reads
back whether the record's metas are eager-loaded or read from the database.

#### Scenario: A meta written with an Integer key

- **WHEN** a post's meta is written with the key `2024` and read with the same key on a post loaded with its
  metas eager-loaded and on one loaded without them
- **THEN** both reads return the value written

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
written. A record whose creation is rolled back, whether or not it was given any, SHALL have the metas
it holds built again for its next save and SHALL read them, not a value it memoized before or while it
was created. An update SHALL write them to the rows the record stores, the first update after its
creation included, whatever another instance stored since. A post type SHALL fill its default options in
under the options set on the record before its first save and under the ones given. A copy made with `dup` SHALL carry no record of the
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

#### Scenario: The first update after a creation, over rows another instance stored

- **WHEN** a post is created, another instance of it sets a meta and an option, and the post's first update
  gives that meta in `data_metas` and another option in `data_options`
- **THEN** it holds one row for the meta and one options row, and a freshly loaded post reads the meta
  given and both options

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
