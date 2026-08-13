# custom-field-value-rejection

## Purpose

Keep every custom-field value safe to render in its position without ever rewriting authored
content: a value an untrusted author is not permitted to write is refused at save time with an error
naming the field, so stored values always equal authored values and the frontend may emit them
verbatim (`editor` markup) or into URL positions (`url`/media types).

## ADDED Requirements

### Requirement: Dangerous custom-field values are rejected on save for untrusted authors

The system SHALL validate every custom-field value row on save according to its rendered position.
For `editor` values (rendered as markup), content containing anything outside the post-content
allowlist — script elements, event-handler attributes, script-capable URI schemes, disallowed
elements, non-translation-marker comments, structurally deceptive markup (tags the parser drops or
that stay open, translation markers inside tags), or values beyond the parse size bound — SHALL be
refused. For URI-type values (`url`, `image`, `audio`, `video`, `file`), a script-capable scheme
(`javascript:`, `vbscript:`, non-raster `data:`) SHALL be refused. The value SHALL NOT be sanitized,
escaped, or otherwise rewritten: it is stored exactly as written or not stored at all. Field types
whose values render through escaping ERB as element content SHALL NOT be gated.

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

### Requirement: A refused value surfaces as an error, not a failure

When a custom-field value is refused during an admin save, the response SHALL surface a flash error
naming the field (the parent object's own save is unaffected); the refusal SHALL NOT produce an
unhandled 500.

#### Scenario: Posts controller surfaces the refusal

- **WHEN** an untrusted author submits a post update whose editor field value contains a script
- **THEN** the response redirects back with a flash error naming the field, and the value is not
  stored
