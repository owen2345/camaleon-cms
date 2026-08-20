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

