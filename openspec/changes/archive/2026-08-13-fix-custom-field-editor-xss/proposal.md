# Reject dangerous custom-field values on save (M17)

## Why

The default-theme custom-field partial renders an `editor` (rich-text) value with `<%= raw value %>`,
and URI-type field values (`url`, `image`, `audio`, `video`, `file`) are emitted into href/src
positions — while nothing gates what a non-admin may store in those values. A user who can set an
editor field value could store `<script>` or an event handler and have it execute for every visitor;
a `javascript:` URL in a `url` field executes on click. Audit finding M17.

Per the project's security model (maintainer decision, 2026-08-13), the remedy is **rejection, not
transformation**: untrusted input is either stored exactly as written or refused with an error —
never sanitized, so stored content always equals authored content and rendering it verbatim
introduces nothing the author did not write. This matches the upload pipeline (scan and refuse) and
the contact-form gate (reject on save), and supersedes an earlier render-time sanitization approach.

### Triage verdict: legit

Reproduced in `spec/requests/security/custom_field_value_rejection_spec.rb` and
`spec/models/custom_field_value_rejection_spec.rb`: on unfixed code the posts controller and the
model save path store a `<script>` editor value and a `javascript:` URL for a role without
`post_content_unfiltered_html` (stash-verified failures).

## What Changes

- New shared detector `CamaleonCms::UnsafeMarkup` (`lib/camaleon_cms/unsafe_markup.rb`), mirroring
  the cama_contact_form gate (keep in parity): one Loofah parse, safe-list scrub compared against the
  parse's own reserialization (only genuine removals register), plus structural guards
  (parser-dropped markup, unterminated tags, translation markers inside tags, stray comments, a
  64KB parse bound). `data-*`/`aria-*` attributes are admitted by shape. `dangerous_uri?` wraps
  `ContentSecurity.blocked_scheme?` for URL positions.
- `CamaleonCms::CustomFieldsRelationship` validates on save, by rendered position: `editor` values
  (markup position, post-content allowlist), URI field types (scheme check). Field types rendered
  through escaping ERB carry no gate. Trust mirrors the post-content model: admins always; for a
  post's fields, a role holding `post_content_unfiltered_html` on the post type. No request context
  fails closed (the gate applies; benign values still pass). `unfiltered_value!` is the server-side
  pipeline opt-out, mirroring `Post#unfiltered_content!` (no writer, mass assignment cannot reach it).
- `AdminController` rescues the model's refusal (`RecordInvalid` for this model only) into a flash
  error naming the field, since field values save after their parent.
- The frontend partial keeps rendering `editor` values verbatim — safe because the gate refuses
  dangerous values at entry.

## Notes for upgraders

- Values **already stored** before this gate are not rewritten (nothing is ever rewritten). Run
  `rake camaleon_cms:security:scan_content` (shipped with the post-content rejection change) to list stored
  posts and field values that would fail today's gate, and clean them up by hand.

## Out of scope

- Per-save provenance for field values; historical values are handled by the scan task above.
- Gating field types whose values render escaped (no executable position).
- The `field_attrs` output bugfix in the same partial (separate commit): its values are plain-text
  attr/value labels emitted as escaped element content — platform-default ERB escaping, not
  sanitization — and that commit also fixes the value column being rendered as the label twice.
