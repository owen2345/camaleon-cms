# custom-field-value-filtering Delta — filter-theme-field-value-saves

## ADDED Requirements

### Requirement: Theme settings saves accept only registered field slugs

Every request-parameter path that saves custom-field values from the admin theme-settings
form — the `theme_fields` payload param and the `field_options` payload submitted through a
theme's custom-save action — SHALL accept only slugs of fields registered under the theme
placement scope, discarding submitted entries for unregistered slugs and arbitrary field ids.
A value
submitted for a registered theme field MUST save and read back; a value submitted for an
unregistered slug MUST NOT create a stored value row. The filter applies to every role that
can reach theme settings, including non-administrator roles granted the theme-settings
capability.

#### Scenario: Unregistered slug via theme_fields is dropped

- **WHEN** a user with only the theme-settings capability posts a theme save whose
  `theme_fields` payload carries a slug not registered on the theme scope
- **THEN** no value row is stored for that slug

#### Scenario: Registered slug via theme_fields saves

- **WHEN** a theme save posts a `theme_fields` payload carrying a slug registered on the
  theme scope
- **THEN** the value is stored and readable back from the theme

#### Scenario: Unregistered slug via the bundled theme's custom-save action is dropped

- **WHEN** the bundled `new` theme is active and a theme save posts its custom-save action
  with a `field_options` payload carrying an unregistered slug
- **THEN** no value row is stored for that slug

### Requirement: A submission carrying no registered slug leaves stored values intact

An admin custom-field value save whose submitted slugs are all unregistered under the target
scope SHALL leave the target's existing stored values unchanged. The allowed-slugs filter MUST
NOT hand the value writer a non-blank payload that clears every existing value while writing
nothing.

#### Scenario: All-unregistered submission preserves existing values

- **WHEN** an object has stored custom-field values and a save submits only slugs not
  registered under its scope
- **THEN** the object's existing values remain unchanged

### Requirement: The bundled theme's custom save answers with the standard response

The bundled `new` theme's custom-save path SHALL complete with the theme-settings form's
standard single redirect; the theme's settings hook MUST NOT issue a second response of its own.

#### Scenario: Custom save redirects once

- **WHEN** the bundled `new` theme is active and a theme save posts its custom-save action
  with a registered field value
- **THEN** the request answers with the standard redirect to the theme-settings form and the
  value is stored
