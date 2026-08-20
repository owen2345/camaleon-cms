# post-editor-content-resilience Specification

## Purpose
The admin post editor must not lose server-rendered content when TinyMCE initializes. A cold-boot /
background-tab init race can blank the content field's live value before TinyMCE reads it, so the
editor comes up empty and a save overwrites the post -- even though the server rendered the content.
## Requirements
### Requirement: The editor restores server-rendered content when it initializes empty

When the admin TinyMCE editor initializes empty but the server rendered content into the textarea,
it SHALL restore that content from the textarea's preserved initial value (`defaultValue`), so a
transient init-time blanking of the live value cannot lose the post body. The restore SHALL NOT
apply to Translatable clones or to encoded multi-language values, whose per-locale decoding the
Translatable plugin owns.

#### Scenario: An editor that comes up empty is refilled from the server value

- **WHEN** the editor initializes with empty content but the textarea's `defaultValue` holds the
  server-rendered content
- **THEN** the editor is refilled with that content, so a subsequent save preserves the post body

#### Scenario: A translation clone or encoded multi-language value is left to Translatable

- **WHEN** the field is a Translatable clone or its value is an encoded multi-language string
  (leading `<!--:`)
- **THEN** the guard does not restore it, leaving per-locale decoding to the Translatable plugin

