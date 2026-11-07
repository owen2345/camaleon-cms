# custom-field-value-rejection Specification

## Purpose
Keep every custom-field value safe to render in its position without ever rewriting authored
content: a value an untrusted author is not permitted to write is refused at save time with an error
naming the field, so stored values always equal authored values and the frontend may emit them
verbatim (`editor` markup) or into URL positions (`url`/media types). A custom-field value with an
invalid group number is refused too, for each author.

## Requirements

### Requirement: Dangerous custom-field values are rejected on save for untrusted authors

The system SHALL validate every custom-field value row on save according to its rendered position.
For `editor` values (rendered as markup), content containing anything outside the post-content
allowlist — script elements, event-handler attributes, script-capable URI schemes, disallowed
elements, non-translation-marker comments, structurally deceptive markup (tags the parser drops or
that stay open, translation markers inside tags), or values beyond the parse size bound — SHALL be
refused. For URI-type values (`url`, `image`, `audio`, `video`, `file`), a script-capable scheme
(`javascript:`, `vbscript:`, non-raster `data:`) SHALL be refused. The value SHALL NOT be sanitized,
escaped, or otherwise rewritten: it is stored exactly as written or not stored at all. Field types
whose values render through escaping ERB as element content SHALL NOT be gated. The gate SHALL apply
on every value-write path (including `update_field_value`), not only the admin form. The same
per-field-type dispatch SHALL back the `scan_content` audit task, so it reports exactly the stored
values the gate would refuse (editor, `field_attrs`, and URI types).

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

#### Scenario: Escaped positions carry no gate

- **WHEN** an untrusted author saves a `text_box` value containing markup
- **THEN** the value is stored as written (its renderer escapes it as element content)

#### Scenario: update_field_value routes through the gate

- **WHEN** an untrusted author writes a dangerous value through `update_field_value`
- **THEN** the gate refuses it and the value is not stored (the API SHALL NOT bypass validations)

### Requirement: Trusted authors and explicit pipelines bypass the gate

Admins SHALL always be able to store any value. For fields attached to a post, a saver holding
`post_content_unfiltered_html` for the post type SHALL bypass the gate (the capability that governs
the post body governs the body's fields). Fields of non-post objects SHALL be admin-only for
unfiltered values. When no request context exists the gate SHALL apply (fail closed), with
`CustomFieldsRelationship#unfiltered_value!` — a reader plus bang enabler with no writer — as the
explicit opt-out for trusted server-side pipelines.

#### Scenario: Admin stores a script editor value verbatim

- **WHEN** an admin saves an editor field value containing `<script>`
- **THEN** the value is stored exactly as written

#### Scenario: Granted non-admin role is trusted for a post's fields

- **WHEN** a non-admin role holding `post_content_unfiltered_html` for the post type saves a script
  editor value on a post of that type
- **THEN** the value is stored exactly as written

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

#### Scenario: Posts controller surfaces the refusal atomically

- **WHEN** an untrusted author submits a post update whose editor field value contains a script
- **THEN** the response redirects back with a flash error naming the field, the value is not stored,
  and the parent post's other changes in that submission are not persisted either

#### Scenario: Value persistence does not destroy the prior value

- **WHEN** an author's new value for a field is refused (through the single-value write path)
- **THEN** the previously stored value for that field is unchanged

### Requirement: Field-attribute values are gated on their decoded members and rendered verbatim

For `field_attrs` values — stored as JSON whose string members the frontend emits as markup — the
system SHALL parse the stored JSON and apply the markup gate to each **decoded** member of any JSON
shape (object, array, or nested), so that
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

- **WHEN** an untrusted author saves a pair whose members stay within the markup allowlist
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

### Requirement: The gated field type is resolved from the slug, not a client-supplied id

`set_field_values` SHALL resolve each value row's `custom_field_id` from the trusted field slug — the
field registered under that slug on the object — not from the client-supplied `id`. Because the gate
selects a value's rendered position from its field's `field_key`, a forged `id` naming a non-gated
field MUST NOT let a value written under a gated slug (`editor`, URI types, `field_attrs`) skip the
gate. When the slug names no field on the object the caller-supplied `id` MAY stand (trusted internal
callers); permitted browser payloads always name registered slugs.

#### Scenario: A forged non-gated id does not bypass the gate

- **WHEN** an untrusted author submits a value for a gated `editor` slug carrying the `id` of a
  different, non-gated `text_box` field, with dangerous markup as the value
- **THEN** the value is gated as an `editor` value (its field resolved from the slug) and refused,
  storing nothing

#### Scenario: The stored row names the slug's field

- **WHEN** a value is saved for a slug while a different field's `id` is submitted alongside it
- **THEN** the stored row's `custom_field_id` is the id of the field the slug names

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
  number, and it SHALL validate the number before its lookup. The lookup reads the number through
  the integer cast (`'1abc'` is group 1). A negative Integer is the exception: the method SHALL look
  it up with no validation. The lookup finds only a value with that number, and the method changes
  no group number. The method returns false for a value that a validation refuses, and nil for each
  other error, as before.
  The method SHALL update the stored value in the database. With a loaded `custom_field_values`
  association, it SHALL then put the saved value in the row with the same id that the association
  holds. The record then reads the new value. When another instance replaced the stored row, the
  association holds no such row, and the record reads the old value until it is loaded again. The
  method SHALL save no other change of that row.
- **Reads.** `get_field_values` SHALL read no value for an invalid group number, other than a
  negative Integer down to -2147483648 or a list. `get_field_value` SHALL return its default for
  such a number. A negative Integer down to -2147483648 reads a stored value with that number. A
  list (Array) of group numbers that `get_field_values` reads SHALL read the values of each group in
  the list. A list with any other group number SHALL read no value. Each group number SHALL read
  the same stored values with or without a loaded `custom_field_values` association, for a String
  key and for a Symbol key. There are two exceptions. A loaded association also reads the values
  that the record built and did not save. On MySQL, the database can match a slug with other case
  (`'Note'` for `'note'`), and a loaded association matches only the same slug.
- **A String that Rails cannot cast.** Rails cannot read a String in an invalid encoding, or in an
  encoding that is not ASCII-compatible (UTF-16), as an Integer. The integer cast of Rails raises an
  `ArgumentError` for an invalid encoding. For UTF-16LE or UTF-16BE, the cast returns nil, and a
  lookup raises an encoding error. For such a group number, each write path MUST fail with the group number
  error. A lookup (`where`, `find_by`) SHALL find no row. `update_attribute` and
  `save(validate: false)` MUST NOT store it.
  `update_column`, `update_all` with a hash and `insert_all` are not write paths of this
  requirement: they store NULL.
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

- **WHEN** `update_field_value` gets an invalid group number, for example `'1abc'` or `true`
- **THEN** the caller gets the group number error, and the stored values of the record are
  unchanged

#### Scenario: update_field_value with a loaded association

- **WHEN** the `custom_field_values` association of a record is loaded, and `update_field_value`
  updates a stored value
- **THEN** the record reads the new value, also before it is loaded again

#### Scenario: update_field_value after another instance replaced the stored value

- **WHEN** the `custom_field_values` association of a record is loaded, and another instance of the
  record replaced the stored value with `set_field_value`
- **AND** `update_field_value` updates that value
- **THEN** the stored value holds the new value

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

Each refusal SHALL answer in the same way, by the kind of the request:

- A submitted form SHALL get a redirect back, with the message as a flash error.
- An XHR that carries the `cama_ajax_request` param (an admin page that `camaleon_admin_ajax` loads
  in place) SHALL get the same redirect and flash.
- Any other XHR SHALL get the message as plain text with a 422, and no flash.

A refused save SHALL store nothing of the refused value. A refusal while the admin panel serves a
GET or HEAD request is no submitted save and SHALL be raised, not answered.

#### Scenario: The nav menu item settings modal shows the refusal

- **WHEN** a user who is not an administrator saves the settings of a nav menu item by XHR, with an
  editor value that holds a script
- **THEN** the response is a 422 with the refusal as text, no flash is set, the value is not stored,
  and the modal stays open and shows the refusal

#### Scenario: A submitted form keeps the flash

- **WHEN** the same save is a submitted form, or an XHR with `cama_ajax_request`
- **THEN** the response redirects back with the refusal in the flash

#### Scenario: The draft save of the post editor

- **WHEN** a draft save by XHR carries a refused value
- **THEN** the response is a 422 with the refusal as text, and the post editor shows the refusal and
  keeps the post on the form, as for a refused meta or option

#### Scenario: An error page with a 422 is no refusal

- **WHEN** a draft save or a nav menu item settings save gets an error page with a 422, for example
  of a CSRF failure
- **THEN** the post editor or the modal shows its generic failure message, not the body of the page

#### Scenario: A container that is not a set of fields, by XHR

- **WHEN** a category save by XHR carries `meta[]=x`
- **THEN** the response is a 422 with the message as text, and no option is stored
