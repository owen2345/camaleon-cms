## RENAMED Requirements

- FROM: `### Requirement: set_meta keeps the caller's value on the writing instance`
- TO: `### Requirement: set_meta reads back on the writing instance as a reloaded record does`

## MODIFIED Requirements

### Requirement: set_meta reads back on the writing instance as a reloaded record does

A value written with `set_meta` SHALL be returned by `get_meta` on the same instance in the form a freshly
loaded record reads it: a Hash, an Array or request parameters as the indifferent hash, or array, their
JSON parses to; a String holding JSON as the value it holds; a numeric or boolean String as the number or
the boolean; any other String as a plain String, not html_safe even when the caller's was; nil or an empty
string as a meta with no value, so the caller's default is returned. The object the caller passed SHALL be
left as passed and SHALL NOT be returned, so a change made to it after the write is not read. A record not
yet saved SHALL read a written value the same way until its first save, after which the instance reads
what it stored. When the value is the record's options, `options` and `get_option` on that instance SHALL
find an option by a String key or its Symbol twin, as a freshly loaded record does, whether the caller
passed a plain Hash, request parameters or a JSON string. The hash `options` returns SHALL share nothing
with the caller's value, its nested hashes included, and SHALL carry no default of the caller's hash, so a
missing option reads nil as after a reload. `set_meta` SHALL return the value passed, whatever form a read
returns for it, and `set_options` and `delete_option` SHALL return the options they wrote.

#### Scenario: A plugin reads back the hash it wrote

- **WHEN** a hash with Symbol keys is written with `set_meta` and a key is then added to the caller's hash
- **THEN** `get_meta` on the same instance returns an indifferent hash holding the values written, read by
  either key type, not the caller's object, and without the key added afterwards

#### Scenario: A string that stores as a number, a boolean or JSON

- **WHEN** `'2024'`, `'false'` and `'[1, 2]'` are written with `set_meta`
- **THEN** the same instance reads `2024`, `false` and `[1, 2]`, as a freshly loaded record does

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
- **AND** the option writers return the options they wrote

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

### Requirement: A meta is read by the String form of its key

`get_meta` SHALL look a key up by its String form, as `set_meta` and `delete_meta` store and remove it,
whatever object names the key, so a meta written with a key that is neither a String nor a Symbol reads
back whether the record's metas are eager-loaded or read from the database.

#### Scenario: A meta written with an Integer key

- **WHEN** a post's meta is written with the key `2024` and read with the same key on a post loaded with its
  metas eager-loaded and on one loaded without them
- **THEN** both reads return the value written

