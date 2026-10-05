# custom-field-value-rejection Specification

## Purpose
Keep every custom-field value safe to render in its position without ever rewriting authored
content: a value an untrusted author is not permitted to write is refused at save time with an error
naming the field, so stored values always equal authored values and the frontend may emit them
verbatim (`editor` markup) or into URL positions (`url`/media types).

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

### Requirement: A value row refuses a group number outside the range of the column

A custom-field value row SHALL accept a group number only when it is nil or an integer from 0 to
2147483647, given as an Integer or as a text of ASCII digits. The row MUST refuse any other group
number (a larger number, a negative number, a boolean, a text that is not digits, a file) with an
error that names the field, on each write path and on each supported database. The row SHALL NOT
change the number to a valid one. A new row is always checked. A stored row SHALL be checked only
when its group number changes. An admin save that submits a refused group number MUST NOT answer with
a 500: it SHALL redirect back with the error and leave the stored values of the record unchanged. An
absent or empty group number in an admin save SHALL mean group 0.

In an admin save, a group number that is a list or a hash MUST get the same refusal. An empty list
is a list. `cama_permitted_field_options` SHALL give that shape to the row, with no content. It
SHALL NOT drop the number, because `set_field_values` reads an absent number as group 0.

A group number text with a broken encoding, or in an encoding that is not ASCII-compatible, SHALL
get the same refusal on each write path. The integer cast of Rails raises its own error for that
text, and that error MUST NOT replace the refusal. A save that skips the validation MUST NOT store
a group number for that text: it SHALL stop with the same refusal. A lookup with that text SHALL
find no row, so a write that looks the number up first SHALL get the same refusal.

A save that skips the validation (`update_attribute`, `save(validate: false)`) is a write path of
this requirement for that text only. For another refused group number, such a save runs no check
of the row. It stores what the integer cast of the type gives (-1 stays -1, and `abc` becomes 0), or
it raises an error for a value that the type cannot store.

A write that skips the validation and the callbacks (for example `update_column`, `update_all`,
`insert_all`) is not a write path of this requirement. Such a write stores no group number (NULL) for that text.

The type of the group number SHALL have the 4-byte range on each supported database, also where
the column holds a wider integer (SQLite, a `bigint` column). There, a lookup with a number above
2147483647 or below -2147483648 finds no row, and a write that skips the validation raises
`ActiveModel::RangeError` for that number. `update_all` with an SQL text skips the type and stores
the number.

A copy of a row (`dup`) SHALL keep the group number as the caller gave it to the original row. The
copy of a row with a refused group number MUST get the same refusal.

A copy is a new row, so the row SHALL check its group number. The copy of a stored row that holds
a negative number MUST get the same refusal. So MUST the copy of a stored row that holds a number
above 2147483647 in a wider column.

`set_field_value` SHALL check the group number before it deletes a stored value. A call with an
empty list of values builds no row, and that call MUST get the same refusal.

`set_field_value` and `set_field_values` delete stored values before they create the rows. A refusal
of a row MUST roll that delete back. Inside a transaction of the caller, the writers SHALL open a
savepoint, so the rollback also holds when the caller rescues the refusal and commits. The next
paragraph gives the exception for a pool with an isolation level.

While the pool has an isolation level, Rails refuses a savepoint. On Rails 8.1,
`ActiveRecord.with_transaction_isolation_level` gives the pool a level inside each transaction that
a model class or a record save opens. While the pool has a level and a joinable transaction of the
caller is open, the writers SHALL NOT open a savepoint. They SHALL run inside that transaction. A
failed call then rolls back nothing, unless the transaction of the caller rolls back. A caller that
rescues the refusal and commits loses the stored values that the call deleted. The rows that the
call stored before the refusal stay.

The rollback leaves the rows of the failed call in the `custom_field_values` association of the
record. After an error of a writer, the writer SHALL reset that association. The record then SHALL
read the stored values, and its next save MUST NOT store a row of the failed call. An exception that
is not a `StandardError` is such an error. So are a `throw` out of the call and a rollback of the
call with `ActiveRecord::Rollback`. A timeout of the caller stops the call in one of the first two
ways.

The reset drops each unsaved row of the association, so the writer SHALL put back the unsaved rows
that the caller built before the call.

A callback of a value row that raises `ActiveRecord::Rollback` before Rails stores the row is not
an error of a writer. Rails ends the save of that row with no error. The writer then goes on, and
the unsaved row stays in the association.

#### Scenario: A group number above the range is refused in an admin save

- **WHEN** an admin save submits a registered field with a group number above 2147483647
- **THEN** the response redirects back with an error that names the field, and the stored values of
  the record are unchanged

#### Scenario: A boolean group number is refused in an admin save

- **WHEN** an admin save with a JSON body submits `true` or `false` as a group number
- **THEN** the response redirects back with an error that names the field, and the stored values of
  the record are unchanged

#### Scenario: A group number sent as a list or a hash is refused in an admin save

- **WHEN** an admin save submits a registered field with a group number that is a list, a hash or a
  list of hashes
- **THEN** the response redirects back with an error that names the field, and the stored values of
  the record are unchanged

#### Scenario: A negative group number or a text that is not digits is refused

- **WHEN** a save submits a group number of `-1`, `abc` or `0abc`
- **THEN** the save is refused and no value row is stored for it

#### Scenario: The largest group number is stored

- **WHEN** a save submits a group number of 2147483647
- **THEN** the value is stored under that group number

#### Scenario: A stored row with a negative group number stays writable

- **WHEN** a stored row holds a negative group number and a caller updates only its value
- **THEN** the update succeeds

#### Scenario: A group number text that the integer cast cannot read is refused

- **WHEN** `set_field_value`, `set_field_values` or a direct `custom_field_values.create!` gets a
  group number text with a broken encoding, or in an encoding that is not ASCII-compatible
- **THEN** the caller gets the refusal that names the field, and the stored values of the record
  are unchanged

#### Scenario: A save that skips the validation stops for a text that the integer cast cannot read

- **WHEN** `update_attribute` or `save(validate: false)` saves a row with a group number text with a
  broken encoding, or in an encoding that is not ASCII-compatible
- **THEN** the save returns false, the row holds the refusal that names the field, and the stored
  row is unchanged

#### Scenario: A write that looks the number up first is refused

- **WHEN** `custom_field_values.find_or_create_by!` gets a group number text with a broken
  encoding, or in an encoding that is not ASCII-compatible
- **THEN** the lookup finds no row, the caller gets the refusal that names the field, and the
  stored values of the record are unchanged

#### Scenario: A copy of a row with a refused group number is refused

- **WHEN** a caller copies a row with `dup`, and the row holds a group number that the row refuses
- **THEN** the save of the copy returns false, the copy holds the refusal that names the field, and
  the save stores no row

#### Scenario: An empty list with a refused group number is refused

- **WHEN** `set_field_value` gets an empty list of values and a group number that a row refuses
- **THEN** the caller gets the refusal that names the field, and the stored values of the record
  are unchanged

#### Scenario: A refusal inside a transaction of the caller keeps the stored values

- **WHEN** the pool has no isolation level, and a caller runs `set_field_value` or
  `set_field_values` inside its own transaction with a group number that the row refuses, rescues
  the refusal inside that transaction and commits
- **THEN** the stored values of the record are unchanged

#### Scenario: The writers join a transaction of the caller that has a pool isolation level

- **WHEN** a caller on Rails 8.1 runs `set_field_value` or `set_field_values` inside a joinable
  `Model.transaction` that starts under `ActiveRecord.with_transaction_isolation_level`
- **THEN** the writer opens no savepoint, and the call stores its values

#### Scenario: The record reads the stored values after a failed call

- **WHEN** `set_field_value` or `set_field_values` raises an error, and the caller rescues it and
  goes on with the same record
- **THEN** the record reads the stored values, and its next save stores no row of the failed call

#### Scenario: The rows that the caller built stay after a failed call

- **WHEN** a caller builds an unsaved row on the `custom_field_values` association, and
  `set_field_value` or `set_field_values` then raises an error
- **THEN** the association holds that row, and the next save of the record stores it
