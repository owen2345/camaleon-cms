# custom-field-value-filtering Specification

## Purpose
Keep every admin custom-field value save, the theme-settings saves included, under one allowed-slugs
permit confined to the field groups the save's form renders for the record being saved, so no role
that reaches a save can write value rows for slugs unregistered on that record or for arbitrary field
ids, and the bundled theme's custom-save path answers with a single standard response.
## Requirements
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

### Requirement: A non-hash field-options payload is ignored, not fatal

The allowed-slugs permit SHALL treat a `field_options` (or sibling `theme_fields`) payload that is
not a parameter hash — a scalar or an array — as empty, saving no value rows rather than raising.
Every admin controller sharing the permit MUST NOT let an authenticated caller turn a malformed
field-options param into a 500.

#### Scenario: Scalar field_options saves nothing and does not error

- **WHEN** a save submits `field_options` as a scalar string (or an array) while the target has
  registered fields
- **THEN** no value row is stored and the request completes normally (no 500)

### Requirement: The bundled theme's custom save answers with the standard response

The bundled `new` theme's custom-save path SHALL complete with the theme-settings form's
standard single redirect; the theme's settings hook MUST NOT issue a second response of its own.

#### Scenario: Custom save redirects once

- **WHEN** the bundled `new` theme is active and a theme save posts its custom-save action
  with a registered field value
- **THEN** the request answers with the standard redirect to the theme-settings form and the
  value is stored

### Requirement: An admin custom-field save stores only the fields its form offers

Every admin save of custom-field values — site settings, theme settings (both payloads), post type,
post and draft, category, post tag, user, widget assignment and nav menu item — SHALL accept only
slugs of fields in the groups the corresponding form renders for the record being saved. A slug
registered only on another record of the same placement class (another post type, another site's
settings, theme or user groups, another widget, another menu) MUST NOT create a value row on the
record being saved. A slug registered on the record's own groups MUST save and read back as before.

#### Scenario: A sibling post type's slug is dropped from a post type save

- **WHEN** a field is registered on post type B and a save of post type A submits that slug
- **THEN** no value row is stored on post type A

#### Scenario: A sibling post type's slug is dropped from a post, draft, category or post tag save

- **WHEN** a field is registered for the posts, categories or tags of post type B and a save of a
  post, a draft, a category or a tag of post type A submits that slug
- **THEN** no value row is stored on the saved record

#### Scenario: Another site's slug is dropped from the site, theme and user saves

- **WHEN** a field is registered on site B's settings, theme or user groups and a save on site A
  submits that slug
- **THEN** no value row is stored on site A's record

#### Scenario: Another widget's slug is dropped from a widget assignment save

- **WHEN** a field is registered on widget B and a save of an assignment of widget A submits that slug
- **THEN** no value row is stored on the assignment

#### Scenario: A slug registered on the record saves

- **WHEN** a save submits a slug registered on the saved record's own groups, alongside a sibling
  record's slug
- **THEN** the registered slug's value is stored and readable back, and the sibling slug is dropped

### Requirement: A nav menu item save accepts the groups placed on its menu

A group placed on a nav menu through the custom-fields form (placement class `NavMenu`, the menu's
id) is what the menu item's custom-settings form renders. The menu item save SHALL accept the slugs
of that menu's groups and MUST NOT accept a slug registered only on another menu. The options of an
external menu item SHALL be permitted against the same set.

#### Scenario: A value for a field placed on the item's menu is stored

- **WHEN** a group is placed on the menu as the custom-fields form does and the item save submits a
  value for one of its fields
- **THEN** the value is stored and readable back from the item

#### Scenario: A slug registered on another menu is dropped

- **WHEN** the item save submits a slug registered only on a group placed on another menu
- **THEN** no value row is stored on the item

### Requirement: The shared permit keeps its class-wide default for callers that name no groups

A caller of the shared allow-list that passes only a placement class, as released plugins do, SHALL
keep accepting every slug registered under that class, across records and sites. Confining the
permit to one record requires the caller to pass the field groups its form renders.

#### Scenario: A class-only caller accepts a sibling record's slug

- **WHEN** a caller permits a payload naming only the placement class and the payload carries a slug
  registered on another record of that class
- **THEN** the slug is permitted

#### Scenario: A caller passing its groups drops a sibling record's slug

- **WHEN** a caller permits the same payload and passes the field groups of its own record
- **THEN** the sibling record's slug is not permitted
