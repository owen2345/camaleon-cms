## MODIFIED Requirements

### Requirement: Trusted authors and explicit pipelines bypass the gate

Admins SHALL always be able to store any value. The other trusted authors SHALL depend on the owner
of the value:

- For the fields of a post, a saver that holds `post_content_unfiltered_html` for the post type SHALL
  bypass the gate. The permission that governs the post body governs the fields of the post.
- For the fields of the current site, a saver that holds the `settings` permission SHALL bypass the gate.
  That permission allows the save of the site settings, which holds these fields.
- For the fields of a theme of the current site, a saver that holds `theme_settings` SHALL bypass
  the gate. That permission allows the save of the theme settings, which holds these fields.
- For the fields of every other owner, only an admin SHALL bypass the gate. Examples are a category,
  a post tag, a user, a nav menu item and a post type.

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

#### Scenario: A settings holder is not trusted for the fields of a theme

- **WHEN** a non-admin role that holds `settings` but not `theme_settings` saves a theme field value
  that holds a `<script>` element
- **THEN** the save is refused, and no value row is stored

#### Scenario: A settings holder is not trusted for the fields of another site

- **WHEN** a non-admin role that holds `settings` saves a field value of another site that holds a
  `<script>` element
- **THEN** the save is refused, and no value row is stored

#### Scenario: A non-admin is not trusted for the fields of another owner

- **WHEN** a non-admin role that holds `settings` and `theme_settings` saves a category field value
  that holds a `<script>` element
- **THEN** the save is refused, and no value row is stored

#### Scenario: Missing request context fails closed

- **WHEN** a save runs with no `CurrentRequest` user or site (job, rake task, console) and the value
  is dangerous
- **THEN** the save is refused, while benign values still save

#### Scenario: A pipeline opt-out stores verbatim

- **WHEN** server-side code calls `unfiltered_value!` on the value row before saving
- **THEN** the value is stored exactly as written regardless of context

## ADDED Requirements

### Requirement: A custom-field value of every kind is scanned on save for untrusted authors

The system SHALL validate every custom-field value row on save, for every field kind. The `data`
shortcode puts a stored value of any kind into a page as markup. So no kind is safe without the scan.

- For a value of any kind except `field_attrs`, content outside the post-content allowlist SHALL be
  refused. Examples are script elements, event-handler attributes, script-capable URI schemes and
  disallowed elements. Comments that are not translation markers are refused too. So is deceptive
  markup: tags that the parser drops or that stay open, and translation markers inside tags.
- For a URI-type value (`url`, `image`, `audio`, `video`, `file`), a script-capable scheme
  (`javascript:`, `vbscript:`, non-raster `data:`) SHALL also be refused.
- For a `field_attrs` value, each decoded member SHALL be held to the post-content allowlist.
- A value beyond the parse size bound SHALL be refused for every kind.

The value SHALL NOT be sanitized, escaped, or otherwise rewritten: it is stored exactly as written or
not stored at all. The gate SHALL apply on every value-write path (including `update_field_value`),
not only the admin form. The same dispatch SHALL back the `scan_content` audit task, so it reports
exactly the stored values of every kind that the gate refuses.

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

#### Scenario: Script in a text_box value is refused

- **WHEN** an untrusted author saves a `text_box` value that holds a `<script>` element
- **THEN** the save is refused with an error naming the field, and no value row is stored

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

## REMOVED Requirements

### Requirement: Dangerous custom-field values are rejected on save for untrusted authors

**Reason**: The requirement left the kinds that are not markup or URL kinds with no scan. The `data` shortcode puts their values into a page as markup.

**Migration**: The requirement "A custom-field value of every kind is scanned on save for untrusted authors" replaces it.

### Requirement: The gated field type is resolved from the slug, not a client-supplied id

**Reason**: Every field kind is gated now, so no field is "not gated". The slug still decides the rules for a value.

**Migration**: The requirement "The rules for a value are resolved from the slug, not a client-supplied id" replaces it.
