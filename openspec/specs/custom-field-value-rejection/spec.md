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
no half-applied post, and no orphan post on create. The response SHALL surface a flash error naming
the field, and the refusal SHALL NOT produce an unhandled 500.

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
each supported database. The system SHALL NOT change an invalid group number to a valid one.

- **When the validation runs.** A new value is always validated. A stored value SHALL be validated
  only when a save changes its group number. A copy (`dup`) is a new value, and it SHALL keep the
  group number as the caller gave it. So the copy of an invalid value MUST be invalid.
- **Admin saves.** An admin save that reaches the controller with an invalid group number MUST NOT
  answer with a 500. It SHALL redirect back with the error, and the record SHALL keep its stored
  values. Rails answers a param in an invalid encoding with a 400 before the controller. An absent
  or empty group number SHALL mean group 0. `cama_permitted_field_options` SHALL keep a group
  number that is a list or a hash, with its content removed, so that the save fails.
- **Calls with no values.** `set_field_value` with an empty list of values MUST get the error, and
  it SHALL validate the group number before it deletes a stored value. An entry of
  `set_field_values` with no values MUST get the error too.
- **A String that Rails cannot cast.** Rails cannot read a String in an invalid encoding, or in an
  encoding that is not ASCII-compatible (UTF-16), as an Integer. The integer cast of Rails raises an
  encoding error for an invalid encoding. For UTF-16LE or UTF-16BE, the cast returns nil, and a
  lookup raises the error. For such a group number, each write path MUST fail with the group number
  error. A lookup (`where`, `find_by`) SHALL find no row. `update_attribute` and `save(validate: false)` MUST NOT store it.
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

- **WHEN** a stored value holds a negative group number and a caller updates only its content
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
