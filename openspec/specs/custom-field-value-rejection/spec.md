# custom-field-value-rejection Specification

## Purpose
Keep every custom-field value safe to render in its position without ever rewriting authored
content: a value an untrusted author is not permitted to write is refused at save time with an error
naming the field, so stored values always equal authored values and the frontend may emit them
verbatim (`editor` markup) or into URL positions (`url`/media types). A custom-field value with an
invalid group number is refused too, for each author.

## Requirements

### Requirement: Trusted authors and explicit pipelines bypass the gate

Admins SHALL always be able to store any value. The other trusted authors SHALL depend on the owner
of the value:

- For the fields of a post, a saver that holds `post_content_unfiltered_html` for the post type SHALL
  bypass the gate. The permission that governs the post body governs the fields of the post.
- For the fields of an owner that is not a post, a saver that holds `settings` or `custom_fields`
  SHALL bypass the gate. This SHALL NOT apply to another site or its themes (the last item). These
  two permissions give a role the trust of an administrator. Examples are the current site, its theme,
  a category, a post tag, a user, a nav menu item and a post type.
- For the fields of a theme of the current site, a saver that holds `theme_settings` SHALL bypass
  the gate too. That permission allows the save of the theme settings, which holds these fields.
- For the fields of another site or of its theme, only an admin SHALL bypass the gate. The same
  applies to a value with no owner.

The trust check SHALL find the owner of a value by its Camaleon class. This SHALL hold also when the
host app has a top-level class of the same name, such as `Post`.

When no request context exists, the gate SHALL apply (fail closed). A trusted server-side pipeline
opts out with `CustomFieldsRelationship#unfiltered_value!`, a reader and a bang enabler with no writer.

#### Scenario: Admin stores a script editor value verbatim

- **WHEN** an admin saves an editor field value containing `<script>`
- **THEN** the value is stored exactly as written

#### Scenario: Granted non-admin role is trusted for a post's fields

- **WHEN** a non-admin role holding `post_content_unfiltered_html` for the post type saves a script
  editor value on a post of that type
- **THEN** the value is stored exactly as written

#### Scenario: A settings holder is trusted for the fields of the site

- **WHEN** a non-admin role that holds `settings` saves the site settings with a `text_box` site field
  value that holds a `<script>` element
- **THEN** the value is stored exactly as written

#### Scenario: A theme_settings holder is trusted for the fields of a theme

- **WHEN** a non-admin role that holds `theme_settings` saves the theme settings with a `text_box`
  theme field value that holds a `<script>` element
- **THEN** the value is stored exactly as written

#### Scenario: A settings or custom_fields holder is trusted for the fields of other owners

- **WHEN** a non-admin role that holds `settings` or `custom_fields` saves a theme field value and a
  category field value that hold a `<script>` element
- **THEN** each value is stored exactly as written

#### Scenario: A settings or custom_fields holder is not trusted for the fields of a post

- **WHEN** a non-admin role that holds `settings` or `custom_fields`, but not
  `post_content_unfiltered_html`, saves a post field value that holds a `<script>` element
- **THEN** the save is refused, and no value row is stored

#### Scenario: A settings holder is not trusted for the fields of another site

- **WHEN** a non-admin role that holds `settings` saves a field value of another site that holds a
  `<script>` element
- **THEN** the save is refused, and no value row is stored

#### Scenario: A theme_settings holder is not trusted for the fields of another owner

- **WHEN** a non-admin role that holds only `theme_settings` saves a site or a category field value
  that holds a `<script>` element
- **THEN** the save is refused, and no value row is stored

#### Scenario: A top-level Post model of the host app does not change the trust

- **WHEN** the host app has a top-level `Post` model
- **AND** a non-admin role that holds `settings`, but not `post_content_unfiltered_html`, saves a post
  field value that holds a `<script>` element
- **THEN** the save is refused, and no value row is stored

#### Scenario: Missing request context fails closed

- **WHEN** a save runs with no `CurrentRequest` user or site (job, rake task, console) and the value
  is dangerous
- **THEN** the save is refused, while benign values still save

#### Scenario: A pipeline opt-out stores verbatim

- **WHEN** server-side code calls `unfiltered_value!` on the value row before saving
- **THEN** the value is stored exactly as written regardless of context

### Requirement: A refused value rolls the save back and surfaces as an error

An admin post save SHALL be atomic across the parent post and its metas, field values and options:
they are written in one transaction, so a value the gate refuses rolls the parent save back with it —
no half-applied post, and no orphan post on create. The response SHALL surface the refusal naming
the field, as a refused admin save answers (the requirement "A refused admin save answers by the kind of the request"), and the refusal SHALL NOT produce an unhandled 500.

The draft save of the post editor SHALL be atomic in the same way, for a draft create and for a
draft update. A refused custom-field value, and custom-field `values` in a shape that the shared
permit does not keep, SHALL roll the whole draft save back. A refused draft create MUST store no
draft row, no meta and no link to a category or a tag. A refused draft update MUST keep the draft as
stored: its attributes, metas, categories, tags, options and custom-field values. A refused draft
create on a buffer that exists MUST keep that buffer in the same way. A refused draft save MUST
store no new tag.

#### Scenario: Posts controller surfaces the refusal atomically

- **WHEN** an untrusted author submits a post update whose editor field value contains a script
- **THEN** the response redirects back with a flash error naming the field, the value is not stored,
  and the parent post's other changes in that submission are not persisted either

#### Scenario: Value persistence does not destroy the prior value

- **WHEN** an author's new value for a field is refused (through the single-value write path)
- **THEN** the previously stored value for that field is unchanged

#### Scenario: A refused draft create stores no draft row

- **WHEN** the draft create of a new post, or the first draft create under a post, carries a
  refused value
- **THEN** the response is the refusal with a 422, and no draft row and no meta are stored

#### Scenario: A refused draft create stores no category or tag

- **WHEN** the draft create of a new post carries a category, a new tag and a refused value
- **THEN** no link to a category or a tag is stored, and no new tag is stored

#### Scenario: A draft create after refused ones stores one draft row

- **WHEN** two draft creates of a new post are refused, and a third one carries no refused value
- **THEN** the user has one draft row, and the response names its id

#### Scenario: A refused draft create on a buffer keeps the buffer as stored

- **WHEN** a user has a draft buffer under a post
- **AND** a draft create under that post carries a new title, a new meta and a refused value
- **THEN** the buffer keeps its title, its meta and its custom-field values, and it gets no
  `draft_status` option

#### Scenario: A refused draft update keeps the draft as stored

- **WHEN** a draft update carries a new title, a new meta, a new category, a new tag and a refused
  value
- **THEN** the draft keeps its title, its meta, its categories, its tags and its custom-field values,
  and no new tag is stored

### Requirement: Field-attribute values are gated on their decoded members and rendered verbatim

For `field_attrs` values — stored as JSON whose string members the frontend emits as markup — the
system SHALL parse the stored JSON and apply the markup gate to each **decoded** member of any JSON
shape (object, array, or nested), and to each key of an object, so that
markup hidden by JSON unicode-escaping (\u003c stored instead of a literal `<`) is refused exactly like literal markup;
a value that does not parse SHALL be scanned as stored. Trust, fail-closed and opt-out semantics
SHALL be those of the custom-field gate. When the stored JSON is an object the renderer SHALL emit
the stored attribute name and value verbatim (the pair's value, not the attribute name twice); a JSON
value that is not an object (array or scalar) SHALL render nothing rather than raise.

#### Scenario: Script in a pair member is refused regardless of byte encoding

- **WHEN** an untrusted author saves a field_attrs pair whose value member carries a script
  element, whether the stored JSON holds it as literal bytes or unicode-escaped
- **THEN** the save is refused and no value row is stored

#### Scenario: Benign pairs are stored and rendered byte-for-byte

- **WHEN** an untrusted author saves a pair whose members, stored JSON and Ruby text of each object
  or array member stay in the markup allowlist
- **THEN** the pair is stored exactly as written and the frontend renders the attribute name and
  the value verbatim

#### Scenario: Trusted authors store any pair

- **WHEN** an admin (or a saver holding `post_content_unfiltered_html` for the post type) saves a
  pair carrying a script member
- **THEN** the pair is stored exactly as written

#### Scenario: The value member is rendered

- **WHEN** a stored pair `{attr: "Size", value: "XL"}` is rendered
- **THEN** the output shows `Size` as the label and `XL` as the value (not the label twice)

#### Scenario: Script hidden in a JSON-array member is refused

- **WHEN** an untrusted author saves a field_attrs value that is a JSON array whose member carries a
  unicode-escaped script
- **THEN** the save is refused and no value row is stored

#### Scenario: A non-object field_attrs value renders nothing

- **WHEN** a stored field_attrs value is valid JSON but not an object (an array or scalar)
- **THEN** the partial renders no pair and does not raise

### Requirement: An unchanged pre-gate value does not block an unrelated edit

When the admin form round-trips a post's field values (delete-and-recreate), a value identical to one
already stored SHALL NOT be re-gated, so a value stored before the gate existed does not fail an
unrelated edit — mirroring the post-content gate's unchanged-content skip. A value the author
actually changes SHALL be gated.

#### Scenario: Editing another field leaves a legacy value in place

- **WHEN** a post holds a field value that predates the gate (and would fail it) and the author edits
  a different field, re-submitting the pre-gate value unchanged
- **THEN** the save succeeds and the legacy value is preserved
- **AND WHEN** the author changes that value itself
- **THEN** the gate re-runs and refuses it

### Requirement: A custom-field value validates its group number

An author can add a repeatable field group to a post several times. The group number of a
custom-field value is the index of the copy that the value belongs to, from 0.

A value SHALL be valid only when its group number is nil, an Integer from 0 to 2147483647, or a
String of 1 to 16 digits with such a number. For any other group number, the save MUST fail with
`ActiveRecord::RecordInvalid` and a message that names the field ("the group number error"), on
each supported database. The system SHALL NOT change an invalid group number to a valid one. The
writes that skip the validation (`update_attribute`, `save(validate: false)`, `update_column`,
`update_all` with a hash, `insert_all`) are the exception: they store a castable group number inside
the 4-byte range as Rails casts it, as before. For a String with no leading digit (`'abc'`),
`update_column` stores NULL.

- **When the validation runs.** A new value is always validated. A stored value SHALL be validated
  only when a save changes its group number. A copy (`dup`) is a new value, and it SHALL keep the
  group number as the caller gave it. So the copy of an invalid value MUST be invalid.
- **Admin saves.** An admin save that reaches the controller with an invalid group number MUST NOT
  answer with a 500. It SHALL answer with the error as a refused admin save answers (the requirement "A refused admin save answers by the kind of the request"), and the record SHALL keep its stored values. Rails answers a param in an invalid encoding with a 400 before the controller. An absent
  or empty group number SHALL mean group 0. `cama_permitted_field_options` SHALL keep a group
  number that is a list or a hash, with its content removed, so that the save fails.
- **Calls with no values.** `set_field_value` with an empty list of values MUST get the error, and
  it SHALL validate the group number before it deletes a stored value. An entry of
  `set_field_values` with no values MUST get the error too.
- **A call that looks the value up.** `update_field_value` MUST get the error for an invalid group
  number, and it SHALL validate the number before its lookup. Without the validation, the lookup
  finds the groups of a list (`[1]`) and no value for `'1abc'` or `true`. The caller then
  gets no error. A negative Integer is the exception: the method SHALL look it up with no
  validation. The lookup finds only a value with that number, and the method changes
  no group number. The method returns false for a value that a validation refuses, and nil for each
  other error in the lookup or the write, as before.
- **An update with a loaded association.** `update_field_value` SHALL update the stored value in
  the database. With a loaded `custom_field_values` association, it SHALL then put the saved value
  in the row with the same id that the association holds. The record then reads the new value. When
  another instance replaced the stored row, the association holds no such row, and the record reads
  the old value until it is loaded again. The method SHALL save no other change of that row.
- **Reads.** `get_field_values` SHALL read no value for an invalid group number, other than a
  negative Integer down to -2147483648 or a list. `get_field_value` SHALL return its default for
  a group number that reads no value. A negative Integer down to -2147483648 reads a stored value
  with that number. A list (Array) SHALL read each group in the list when each item is a valid
  group number or a negative Integer down to -2147483648. A list with any other item SHALL read no
  value. A list in a list (`[[1]]`) is such an item.
- **Reads with a loaded association.** Each group number SHALL read the same stored values with or
  without a loaded `custom_field_values` association. A loaded association SHALL read `:note` as
  `'note'`, `5` as `'5'`, a Date as `'2020-01-01'` and a Range key as its slugs, as the database
  does. It SHALL read each key of a list, and the keys of a list in a list. The database gives the
  values in the order of `term_order`, and a loaded association in the order of its rows. So the
  first value, which `get_field_value` returns, can differ. The values differ in these cases:
  - A loaded association reads unsaved values: the values of the rows that the record built, and
    the changed values of its rows. It reads each row under the group number and the slug that the
    row holds, also when they are not saved. It reads an unsaved invalid group number as the
    integer cast gives it (`'1abc'` as group 1).
  - A loaded association reads the rows that it holds, until it is loaded again. A write of another
    instance, or an `update_all`, changes no row that the association holds, so the association
    reads the old values.
  - On MySQL, the collation can match another spelling of a slug (`'Note'` or `'nóte'` for
    `'note'`), and a loaded association matches only the same slug.
  - The database compares the slugs in a Range key with its collation. A loaded association
    compares their bytes.
  - The database raises an error for a key that it cannot read, for example a Hash. A loaded
    association reads no value for such a key.
- **Reads of each group.** `get_fields_grouped` SHALL read the values of a Symbol key (`:note`) as
  it reads the values of the String key (`'note'`). An Integer key (`5`) SHALL read the values of
  its String (`'5'`). A Date key SHALL read the values of the slug that the connection quotes for it
  (`'2020-01-01'`). A Range key SHALL read the values of each slug in the Range. Each group
  SHALL give the values under the key as given.
- **A String that Rails cannot cast.** Rails cannot read a String in an invalid encoding, or in an
  encoding that is not ASCII-compatible (UTF-16), as an Integer. The integer cast of Rails raises an
  `ArgumentError` for an invalid encoding. For UTF-16LE or UTF-16BE, the cast returns nil, and a
  lookup raises an encoding error. For such a group number, each write path MUST fail with the group number
  error. A lookup (`where`, `find_by`) SHALL find no row. `update_attribute` and
  `save(validate: false)` MUST NOT store it.
  `update_column`, `update_all` with a hash and `insert_all` are not write paths of this
  requirement: they store NULL.
- **A slug that is not in UTF-8.** The message of the group number error SHALL hold the slug of
  the field in UTF-8. Without the conversion, a slug in an encoding that is not ASCII-compatible
  (UTF-16) raises an encoding error in place of the group number error.
- **The range of the attribute.** The group number attribute SHALL have the range of a 4-byte
  integer on each supported database, also where the column can hold a larger integer (SQLite, a
  `bigint` column).
- **The rollback.** `set_field_value` and `set_field_values` delete stored values before they
  create the new values. When a new value is invalid, that delete MUST roll back. Inside a
  transaction of the caller, the two methods SHALL use a savepoint, so the stored values stay when
  the caller rescues the error and commits. They SHALL run one statement in that transaction
  first, because Rails 7.2 and later open no savepoint before the first statement.
- **A pool with an isolation level.** Rails 8.1 permits no savepoint while the connection pool has
  a transaction isolation level. The two methods then SHALL NOT ask for a savepoint. Inside a
  transaction of the caller, they run in that transaction, and only a rollback of it restores the
  deleted values. The transaction of the two methods is on the connection pool of
  `ActiveRecord::Base`.
- **The record after a call.** After a failed call, the two methods SHALL reset the
  `custom_field_values` association of the record. The record then SHALL read its stored values,
  and its next save MUST NOT store a value of the failed call. A failed call is an exception of any
  class, a `throw` or `ActiveRecord::Rollback`. The two methods SHALL put back the unsaved values
  that the caller built before the call. A callback of a value that raises `ActiveRecord::Rollback`
  before Rails stores the value is not a failed call.
- **A loaded association.** After `set_field_value`, a loaded `custom_field_values` association
  SHALL NOT hold a value that the call deleted. The call SHALL NOT load an association that is not
  loaded.

#### Scenario: An admin save with a group number above the range

- **WHEN** an admin save submits a registered field with a group number above 2147483647
- **THEN** the response redirects back with an error that names the field, and the stored values of
  the record are unchanged

#### Scenario: An admin save with a boolean group number

- **WHEN** an admin save with a JSON body submits `true` or `false` as a group number
- **THEN** the response redirects back with an error that names the field, and the stored values of
  the record are unchanged

#### Scenario: An admin save with a group number that is a list or a hash

- **WHEN** an admin save submits a registered field with a group number that is a list, a hash or a
  list of hashes
- **THEN** the response redirects back with an error that names the field, and the stored values of
  the record are unchanged

#### Scenario: A negative group number, or a String that is not digits

- **WHEN** a save submits a group number of `-1`, `abc` or `0abc`
- **THEN** the save fails with the group number error, and no value is stored for it

#### Scenario: A String of more than 16 digits

- **WHEN** a save submits a group number String of 17 digits whose number is in the range
- **THEN** the save fails with the group number error, and no value is stored for it

#### Scenario: The largest group number is stored

- **WHEN** a save submits a group number of 2147483647
- **THEN** the value is stored under that group number

#### Scenario: A stored value with a negative group number stays writable

- **WHEN** a stored value holds a negative group number down to -2147483648
- **AND** a caller updates only its content: `row.update(value: 'new')`, or `update_field_value`
  with that number as an Integer
- **THEN** the update succeeds

#### Scenario: A group number String that Rails cannot cast

- **WHEN** `set_field_value`, `set_field_values` or a direct `custom_field_values.create!` gets a
  group number String in an invalid encoding, or in an encoding that is not ASCII-compatible
- **THEN** the caller gets the group number error, and the stored values of the record are
  unchanged

#### Scenario: A save that skips the validation, with a String that Rails cannot cast

- **WHEN** `update_attribute` or `save(validate: false)` saves a value with a group number String
  in an invalid encoding, or in an encoding that is not ASCII-compatible
- **THEN** the save returns false, the value holds the message of the group number error, and the
  stored value is unchanged

#### Scenario: A write that looks the number up first

- **WHEN** `custom_field_values.find_or_create_by!` gets a group number String in an invalid
  encoding, or in an encoding that is not ASCII-compatible
- **THEN** the lookup finds no row, the caller gets the group number error, and the stored values
  of the record are unchanged

#### Scenario: The copy of an invalid value is invalid

- **WHEN** a caller copies a value with `dup`, and the value holds an invalid group number
- **THEN** the save of the copy returns false, the copy holds the message of the group number
  error, and the save stores no row

#### Scenario: update_field_value with an invalid group number

- **WHEN** `update_field_value` gets an invalid group number other than a negative Integer, for
  example `'1abc'` or `true`
- **THEN** the caller gets the group number error, and the stored values of the record are
  unchanged

#### Scenario: update_field_value with a slug in UTF-16 and an invalid group number

- **WHEN** `update_field_value` gets a slug in UTF-16 and an invalid group number (`'1abc'`)
- **THEN** the caller gets the group number error with the slug in UTF-8, and the stored values of
  the record are unchanged

#### Scenario: update_field_value with a loaded association

- **WHEN** the `custom_field_values` association of a record is loaded, and `update_field_value`
  updates a stored value
- **THEN** the record reads the new value, also before it is loaded again

#### Scenario: update_field_value after another instance replaced the stored value

- **WHEN** the `custom_field_values` association of a record is loaded, and another instance of the
  record replaced the stored value with `set_field_value`
- **AND** `update_field_value` updates that value
- **THEN** the stored value holds the new value
- **AND** the record reads the old value until it is loaded again

#### Scenario: A reader with a group number that the integer cast misreads

- **WHEN** `get_field_values` or `get_field_value` gets `'1abc'` or `true` as the group number
- **THEN** it reads no value, and `get_field_value` returns its default

#### Scenario: A reader with an Integer outside the 4-byte range

- **WHEN** a stored value holds a group number outside the 4-byte range (SQLite, a `bigint` column)
- **AND** `get_field_values` gets that number, with or without a loaded association
- **THEN** it reads no value

#### Scenario: A reader with a String of digits and a loaded association

- **WHEN** the `custom_field_values` association of a record is loaded, and `get_field_values` gets
  `'1'` as the group number
- **THEN** it reads the values of group 1

#### Scenario: A reader with a Symbol key and a loaded association

- **WHEN** the `custom_field_values` association of a record is loaded, and `get_field_values` gets
  `:note` as the key
- **THEN** it reads the values of the slug `note`

#### Scenario: A reader with a list of keys and a loaded association

- **WHEN** the `custom_field_values` association of a record is loaded, and `get_field_values` gets
  `['note', :other]` as the key
- **THEN** it reads the values of the slugs `note` and `other`

#### Scenario: A reader with an Integer key and a loaded association

- **WHEN** the `custom_field_values` association of a record is loaded, and `get_field_values` gets
  `5` as the key
- **THEN** it reads the values of the slug `5`

#### Scenario: A reader with a Range key and a loaded association

- **WHEN** the `custom_field_values` association of a record is loaded, and `get_field_values` gets
  `'n'..'o'` as the key
- **THEN** it reads the values of the slug `note`, and no value of the slug `other`

#### Scenario: A reader with a list in a list and a loaded association

- **WHEN** the `custom_field_values` association of a record is loaded, and `get_field_values` gets
  `[['note', 'other']]` as the key
- **THEN** it reads the values of the slugs `note` and `other`

#### Scenario: get_fields_grouped with a Symbol key

- **WHEN** `get_fields_grouped` gets `[:note]` as the list of keys
- **THEN** each group gives the values of the slug `note` under the key `:note`

#### Scenario: get_fields_grouped with an Integer key

- **WHEN** `get_fields_grouped` gets `[5]` as the list of keys
- **THEN** each group gives the values of the slug `5` under the key `5`

#### Scenario: get_fields_grouped with a Range key

- **WHEN** `get_fields_grouped` gets `['n'..'o']` as the list of keys
- **THEN** each group gives the values of the slug `note` under the Range

#### Scenario: A reader with a list of group numbers

- **WHEN** `get_field_values` gets `[0, 1]` as the group number, with or without a loaded
  association
- **THEN** it reads the values of group 0 and of group 1

#### Scenario: A reader with a list that holds an invalid group number

- **WHEN** `get_field_values` gets `[1, '1abc']` as the group number
- **THEN** it reads no value

#### Scenario: An empty list of values with an invalid group number

- **WHEN** `set_field_value` gets an empty list of values and an invalid group number
- **THEN** the caller gets the group number error, and the stored values of the record are
  unchanged

#### Scenario: An entry with no values and an invalid group number

- **WHEN** `set_field_values` or an admin save gets an entry with no values and an invalid group
  number
- **THEN** the caller gets the group number error, and the stored values of the record are
  unchanged

#### Scenario: A failed call inside a transaction of the caller keeps the stored values

- **WHEN** the pool has no isolation level, and a caller runs `set_field_value` or
  `set_field_values` inside its own transaction with an invalid group number, rescues the error
  inside that transaction and commits
- **THEN** the stored values of the record are unchanged

#### Scenario: A failed call that is the first statement of a transaction rolls back to a savepoint

- **WHEN** the pool has no isolation level, a caller opens a transaction, and `set_field_value` or
  `set_field_values` is its first statement and fails after its delete
- **THEN** the method rolls back to a savepoint of its own, and Rails does not restart the
  transaction of the caller

#### Scenario: A transaction of the caller with a pool isolation level

- **WHEN** a caller on Rails 8.1 runs `set_field_value` or `set_field_values` inside a joinable
  `Model.transaction` that starts under `ActiveRecord.with_transaction_isolation_level`
- **THEN** the method opens no savepoint, and the call stores its values

#### Scenario: A loaded association reads the new values after set_field_value

- **WHEN** the `custom_field_values` association of a record is loaded, and `set_field_value` stores a
  new value for a group that holds a stored value
- **THEN** the record reads the new value and not the deleted value, and the association stays
  loaded

#### Scenario: The record reads the stored values after a failed call

- **WHEN** `set_field_value` or `set_field_values` raises an error, and the caller rescues it and
  goes on with the same record
- **THEN** the record reads the stored values, and its next save stores no value of the failed call

#### Scenario: The unsaved values of the caller stay after a failed call

- **WHEN** a caller builds an unsaved value on the `custom_field_values` association, and
  `set_field_value` or `set_field_values` then raises an error
- **THEN** the association holds that value, and the next save of the record stores it

### Requirement: set_field_values reads its payload by String or Symbol keys

`set_field_values` SHALL read a plain Hash payload by a String key or its Symbol twin alike. This
holds for the `id`, `group_number` and `values` of each entry. A plain
Hash with String keys, for example a `JSON.parse` result, MUST store the values of each entry and
validate its group number. The same payload with Symbol keys or with indifferent access gives the
same result.

The method SHALL NOT change the keys of the Hash of the caller. Request parameters SHALL store their
values as before. A plain Hash with a String key and its Symbol twin at one level MUST raise
`ArgumentError` before the delete. The record then keeps its stored values.

#### Scenario: A JSON.parse result stores its values

- **WHEN** a record holds a value and `set_field_values` gets a plain Hash with String keys whose
  entry holds values
- **THEN** the record holds the values of the entry, under the group number of the entry

#### Scenario: An entry with String keys validates its group number

- **WHEN** `set_field_values` gets a plain Hash with String keys whose entry holds an invalid group
  number
- **THEN** the call raises `ActiveRecord::RecordInvalid` with the group number error, and the record
  keeps its stored values

#### Scenario: A String key and its Symbol twin are refused

- **WHEN** `set_field_values` gets a plain Hash that holds `:note` and `'note'` at one level
- **THEN** the call raises `ArgumentError`, and the record keeps its stored values

#### Scenario: The Hash of the caller keeps its keys

- **WHEN** `set_field_values` gets a plain Hash with String keys
- **THEN** after the call, the Hash holds the same keys and the same nested plain Hashes

#### Scenario: Request parameters store their values

- **WHEN** `set_field_values` gets unpermitted request parameters with an entry that holds values
- **THEN** the record holds the values of the entry

### Requirement: set_field_value reads its args by String or Symbol keys

`set_field_value` SHALL read its args by a String key or its Symbol twin alike. This holds for
`field_id`, `order`, `group_number` and `clear`. Args with a String key and its Symbol twin MUST raise
`ArgumentError` before the delete. The record then keeps its stored values.

#### Scenario: A group number with a String key

- **WHEN** a record holds a value in group 0 and `set_field_value` gets `{ 'group_number' => 1 }`
- **THEN** the record holds the new value in group 1, and group 0 keeps its value

#### Scenario: The clear option with a String key

- **WHEN** `set_field_value` gets `{ 'clear' => false }`
- **THEN** the record keeps its stored values of the field and adds the new value

#### Scenario: A String key and its Symbol twin in the args are refused

- **WHEN** `set_field_value` gets `{ clear: true, 'clear' => false }`
- **THEN** the call raises `ArgumentError`, and the record keeps its stored values

### Requirement: A refused admin save answers by the kind of the request

The admin panel refuses a save in these cases:

- a custom-field value with unsafe or too large content, an invalid group number, or a slug that
  names no custom field
- a post type option that names no post decorator
- a meta or options container that is not a set of fields
- custom-field `values`, or a field entry, in a shape that the shared permit cannot read

Each refusal SHALL answer in the same way, by the kind of the request:

- A submitted form SHALL get a redirect back, with the message as a flash error.
- An XHR that carries the `cama_ajax_request` param (an admin page that `camaleon_admin_ajax` loads
  in place) SHALL get the same redirect and flash.
- Any other XHR SHALL get the message as plain text with a 422, and no flash.

A refused save SHALL store nothing of the refused value. A refusal while the admin panel serves a
GET or HEAD request is no submitted save and SHALL be raised, not answered.

#### Scenario: The nav menu item settings modal shows the refusal

- **WHEN** a user who is not an administrator saves the settings of a nav menu item by XHR
- **AND** an editor value holds a script
- **THEN** the response is a 422 with the refusal as text, no flash is set, and the value is not
  stored
- **AND** the modal stays open and shows the refusal

#### Scenario: A submitted form keeps the flash

- **WHEN** the same save is a submitted form, or an XHR with `cama_ajax_request`
- **THEN** the response redirects back with the refusal in the flash

#### Scenario: The draft save of the post editor

- **WHEN** a draft save by XHR carries a refused value
- **THEN** the response is a 422 with the refusal as text
- **AND** the post editor shows the refusal and keeps the post on the form, as for a refused meta or
  option

#### Scenario: An error page with a 422 is no refusal

- **WHEN** a draft save or a nav menu item settings save gets an error page with a 422, for example
  of a CSRF failure
- **THEN** the post editor or the modal shows its generic failure message, not the body of the page

#### Scenario: A container that is not a set of fields, by XHR

- **WHEN** a category save by XHR carries `meta[]=x`
- **THEN** the response is a 422 with the message as text, and no option is stored

### Requirement: A custom-field value of every kind is scanned on save for untrusted authors

The system SHALL validate every custom-field value row on save, for every field kind. The `data`
shortcode puts a stored value of any kind into a page as markup. So no kind is safe without the scan.

- For a value of any kind, content outside the post-content allowlist SHALL be refused. Examples are script elements, event-handler attributes, script-capable URI schemes and
  disallowed elements. Comments that are not translation markers are refused too. So is deceptive
  markup: tags that the parser drops or that stay open, and translation markers inside tags.
- For a URI-type value (`url`, `image`, `audio`, `video`, `file`), a script-capable scheme
  (`javascript:`, `vbscript:`, non-raster `data:`) SHALL also be refused.
- For a URI-type value, a quote (`"` or `'`), an angle bracket, a backtick and whitespace before
  another character SHALL also be refused. A `data` shortcode inside a tag puts the value into an
  attribute, and each of these characters ends the attribute. A URL can encode them, such as `%27` for `'`. Whitespace
  at the end of the value SHALL pass: no character of the value follows it. The translation markers
  of a translated value SHALL pass, because the shortcode shows one translation without them.
- For a URI-type value, the scheme rule and the character rule SHALL also read each text that
  `String#translate` shows. That text can keep a marker, or join a scheme across one.
- For a value of any kind that parses as JSON, each key and decoded member SHALL be held to the
  allowlist too. `the_json_field` parses a value of any kind. The scan SHALL also parse each
  translation of the value, because the `field_attrs` template translates the value before it parses
  it. The scan SHALL include each member of a key that occurs twice in an object. The parse keeps
  only the last of them, but the stored JSON keeps each one.
- For such a value, the `field_attrs` template and `the_json_field` show a member of the object with
  `to_s`. So a member that is an object or an array SHALL also be held to the allowlist as its Ruby
  text. That text writes each quote of a String as `\"`.
- A `field_attrs` pair that code stores as a Hash keeps `<` and writes each attribute quote as `\"`.
  So the scan of the stored value can refuse a tag with an attribute in such a pair, such as a link
  (intended). The `to_json` form of the pair, which escapes `<`, SHALL pass.
- A value beyond the parse size bound SHALL be refused for every kind.

The value SHALL NOT be sanitized, escaped, or otherwise rewritten: it is stored exactly as written or
not stored at all. The gate SHALL apply on every value-write path (including `update_field_value`),
not only the admin form. The same dispatch SHALL back the `scan_content` audit task, so it reports
exactly the stored values of every kind that the gate refuses.

A value of another kind gets no rule for a position inside a tag. Only an admin or a holder of
`content_shortcodes` can place a shortcode, and that role chooses the position (intended).

#### Scenario: Untrusted author's script editor value is refused

- **WHEN** a role without `post_content_unfiltered_html` saves an editor field value containing a
  `<script>` element
- **THEN** the save is refused with an error naming the field, and no value row is stored

#### Scenario: Untrusted author's legitimate rich text is stored unchanged

- **WHEN** the same role saves an editor value containing tables and formatting within the
  post-content allowlist
- **THEN** the value is stored byte-for-byte as written

#### Scenario: Script-capable URL in a URI field is refused

- **WHEN** an untrusted author saves a `url`-type field value of `javascript:alert(1)`
- **THEN** the save is refused and no value row is stored

#### Scenario: Markup in a URI field is refused

- **WHEN** an untrusted author saves a `url`-type field value of `https://example.com/"><script>alert(1)</script>`
- **THEN** the save is refused and no value row is stored

#### Scenario: A quote in a URL value is refused

- **WHEN** an administrator puts `<img src="[data field='photo']">` in the content of a post
- **AND** an untrusted author saves the `image` value `x" onerror="alert(1)` in the field `photo` of
  that post
- **THEN** the save is refused, and the page of the post holds no event handler of the author

#### Scenario: A leading space in a URL value is refused

- **WHEN** an administrator puts `<img src=https://cdn.example.test/[data field='photo']>`, with no
  quotes, in the content of a post
- **AND** an untrusted author saves the `image` value ` onerror=alert(1)` in the field `photo` of
  that post
- **THEN** the save is refused, and the page of the post holds no event handler of the author

#### Scenario: A URL value with whitespace at its end is stored unchanged

- **WHEN** an untrusted author saves a `url`-type value of `https://example.com/page` followed by a
  space or a line break
- **THEN** the value is stored byte-for-byte as written

#### Scenario: A translated URL value is stored unchanged

- **WHEN** an untrusted author saves the translated `url`-type value
  `<!--:en-->https://example.com/en<!--:--><!--:es-->https://example.com/es<!--:-->`
- **THEN** the value is stored byte-for-byte as written

#### Scenario: A script URL that a translation joins is refused

- **WHEN** an untrusted author saves a `url`-type value of `<!--:-->java<!--:en-->script:alert(1)`,
  a line break and `<!--:en-->`
- **THEN** the save is refused, because `translate` shows `javascript:alert(1)`, and no value row is
  stored

#### Scenario: A marker that the shortcode shows in a URL value is refused

- **WHEN** an untrusted author saves an `image`-type value of `https://example.com/x<!--:-->y`
- **THEN** the save is refused, because the shortcode shows the marker, and its `>` ends an attribute
  with no quotes
- **AND** no value row is stored

#### Scenario: An encoded URL is stored unchanged

- **WHEN** an untrusted author saves a `url`-type value of `https://example.com/a%20b?q=%22x%22`
- **THEN** the value is stored byte-for-byte as written

#### Scenario: A quote in a text_box value is stored unchanged

- **WHEN** an untrusted author saves a `text_box` value such as `She said "don't" twice`
- **THEN** the value is stored byte-for-byte as written

#### Scenario: A member that a duplicate key hides is refused

- **WHEN** an untrusted author saves the `field_attrs` value `{"attr":"<script>alert(1)</script>","attr":"Color"}`
- **THEN** the save is refused, and no value row is stored

#### Scenario: A script in a JSON comment is refused

- **WHEN** an untrusted author saves the `field_attrs` value `{"attr":"Color"} /* <script>alert(1)</script> */`
- **THEN** the save is refused, and no value row is stored

#### Scenario: An escaped quote that ends an attribute in the stored JSON is refused

- **WHEN** an untrusted author saves the `field_attrs` value `{"attr":"a","value":"<img src=x title=\"a onerror=alert(1);//\">"}`
- **THEN** the save is refused, and no value row is stored

#### Scenario: An object member whose Ruby text ends an attribute is refused

- **WHEN** an untrusted author saves the `to_json` form of
  `{ attr: 'a', value: { x: '<img src=x title="a onerror=alert(1);//">' } }` as a `field_attrs` value
- **THEN** the save is refused, because the template of the field shows the member as
  `{"x" => "<img src=x title=\"a onerror=alert(1);//\">"}`, and no value row is stored

#### Scenario: A pair that code stores as a Hash with a quoted attribute is refused

- **WHEN** code saves the pair `{ attr: 'Link', value: '<a href="https://example.com/">Shop</a>' }`
  as a Hash for an untrusted author
- **THEN** the save is refused, because the stored JSON writes each quote of the attribute as `\"`
- **AND WHEN** the code saves the `to_json` form of the pair, which escapes `<`
- **THEN** the pair is stored exactly as written

#### Scenario: An escaped script member after a quote in a comment is refused

- **WHEN** an untrusted author saves the `field_attrs` value `{/* " */"value":"\u003cscript\u003ealert(1)\u003c/script\u003e"}`
- **THEN** the save is refused, and no value row is stored

#### Scenario: A member that a duplicate key hides after a quote in a comment is refused

- **WHEN** an untrusted author saves the `field_attrs` value `{/* " */"value":S,"value":"x"}`, where
  `S` is the `to_json` form of a String that holds a `<script>` element
- **THEN** the save is refused, and no value row is stored

#### Scenario: An escaped script in a translation of the JSON is refused

- **WHEN** an untrusted author saves the `field_attrs` value `<!--:en-->{"attr":"a","value":"\u003cscript\u003ealert(1)\u003c/script\u003e"}<!--:-->`
- **THEN** the save is refused, and no value row is stored

#### Scenario: Script in a text_box value is refused

- **WHEN** an untrusted author saves a `text_box` value that holds a `<script>` element
- **THEN** the save is refused with an error naming the field, and no value row is stored

#### Scenario: An escaped script in a JSON member of a text_box value is refused

- **WHEN** an untrusted author saves, as a `text_box` value, the `to_json` form of
  `{ label: '<script>alert(1)</script>' }`, which escapes `<`
- **THEN** the save is refused, because `the_json_field` shows the decoded member, and no value row
  is stored

#### Scenario: A plain text_box value is stored unchanged

- **WHEN** an untrusted author saves a `text_box` value such as `a < b & c` or `<b>bold</b>`
- **THEN** the value is stored byte-for-byte as written

#### Scenario: The data shortcode shows no script of an untrusted author

- **WHEN** an administrator puts `[data field='note']` in the content of a post
- **AND** an editor without `post_content_unfiltered_html` saves a `<script>` in the `text_box` field
  `note` of that post
- **THEN** the save is refused, and the page of the post holds no script of the editor

#### Scenario: update_field_value routes through the gate

- **WHEN** an untrusted author writes a dangerous value through `update_field_value`
- **THEN** the gate refuses it and the value is not stored (the API SHALL NOT bypass validations)

### Requirement: The rules for a value are resolved from the slug, not a client-supplied id

`set_field_values` SHALL resolve the `custom_field_id` of each value row from the trusted field slug.
That is the field that the object registers under the slug, not the client-supplied `id`. The gate selects
the rules for a value from the `field_key` of its field. So a forged `id` that names a field of
another kind MUST NOT change the rules for a value written under a slug. An example is a `text_box`
id on a `url` slug, which skips the URI rule.

When the slug names no field on the object, the caller-supplied `id` MAY stand (trusted internal
callers). Permitted browser payloads always name registered slugs.

#### Scenario: A forged id of another kind does not change the rules

- **WHEN** an untrusted author submits a value for a `url` slug carrying the `id` of a `text_box`
  field, with `javascript:alert(1)` as the value
- **THEN** the value is gated as a `url` value (its field resolved from the slug) and refused,
  storing nothing

#### Scenario: The stored row names the slug's field

- **WHEN** a value is saved for a slug while a different field's `id` is submitted alongside it
- **THEN** the stored row's `custom_field_id` is the id of the field the slug names
