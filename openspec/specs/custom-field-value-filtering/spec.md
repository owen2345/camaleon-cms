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
For a post or draft those are its post type's post groups: the groups placed on the post itself or on
its categories, which the editor also renders, are not saved this way, as before.

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

### Requirement: A permitted value is stored under its slug's own field

The shared permit SHALL carry, for each permitted slug, the id of one of that slug's fields in the groups
it permits, keeping the submitted id only when it names such a field. A value row saved from a permitted
payload MUST NOT point at a field the slug does not name, so the value gate checks it by its own field
type.

#### Scenario: A forged text-box id cannot carry an editor value past the gate

- **WHEN** a role the value gate applies to saves a markup value for an editor field of its own user
  profile, naming a text-box field's id
- **THEN** the value is refused as the editor field's value, and no row is stored

### Requirement: A save resolves each slug in the groups it permits

A save whose record's own field-group lookup differs from the groups its permit allows — a post type
(whose lookup returns its posts' groups), a post or draft (whose lookup adds the groups placed on the
post and its categories), a user (whose lookup keys on a site id equal to the user's) and a widget
assignment (whose lookup finds none) — SHALL resolve each permitted slug's field among the fields of
those groups. A same-slug field outside them MUST NOT receive the value row. Other callers of the model
save keep resolving slugs through the record's own lookup. Neither lookup SHALL point a row at a field
group sharing the slug.

#### Scenario: A post type's own field wins over its posts' field of the same slug

- **WHEN** a post type has its own field and a posts' field under the same slug and its save submits
  that slug
- **THEN** the value row points at the post type's own field

#### Scenario: A user's field wins over the same slug on a site sharing the user's id

- **WHEN** another site whose id equals the user's id holds a user field under the same slug and the
  user's save submits that slug
- **THEN** the value row points at the current site's field

#### Scenario: A post's value lands under its post type's field

- **WHEN** a group placed on the post holds a field under the same slug as a post type's post field,
  ordered first, and the post or its draft is saved with that slug
- **THEN** the value row points at the post type's field

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

### Requirement: A permitted slug's values are kept in both shapes the admin forms submit

The shared permit SHALL keep the values of a permitted slug whether they are submitted as a hash keyed
by index, as the admin forms submit most fields, or as a list of scalars, as the checkboxes field
submits them. A list of scalars MUST be stored in the order submitted and read back from the saved
record. A list holding anything other than scalars MUST NOT create a value row.

#### Scenario: A checkboxes field's checked options are stored

- **WHEN** an admin save submits a registered checkboxes field's values as a list of scalars
- **THEN** each value is stored in the order submitted and readable back from the saved record

#### Scenario: A save keeps a stored checkboxes value that is submitted again

- **WHEN** a record holds a checkboxes value and its form is saved with the same options checked
- **THEN** the record holds the same values after the save

#### Scenario: Both shapes are stored from one save

- **WHEN** a save submits one field's values keyed by index and another field's values as a list of
  scalars
- **THEN** both fields' values are stored

#### Scenario: A list of non-scalars is dropped

- **WHEN** a save submits a registered field's values as a list of hashes
- **THEN** no value row is stored for that field
