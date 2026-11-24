# custom-field-value-filtering Specification

## Purpose
Keep every admin custom-field value save, the theme-settings saves included, under one allowed-slugs
permit confined to the field groups the save's form renders for the record being saved, so no role
that reaches a save can write value rows for slugs unregistered on that record or for arbitrary field
ids, and the bundled theme's custom-save path answers with a single standard response.

## Requirements

### Requirement: Theme settings saves accept only registered field slugs

Every request-parameter path that saves custom-field values from the admin theme-settings form SHALL
accept only slugs of fields registered under the theme placement scope. The paths are the
`theme_fields` payload param and the `field_options` payload that a theme's custom-save action
submits. A submitted entry for an unregistered slug or an arbitrary field id MUST be discarded and
MUST NOT create a stored value row.

#### Scenario: Unregistered slug via theme_fields is dropped

- **WHEN** a user with only the theme-settings capability posts a theme save whose
  `theme_fields` payload carries a slug not registered on the theme scope
- **THEN** no value row is stored for that slug

#### Scenario: Unregistered slug via the bundled theme's custom-save action is dropped

- **WHEN** the bundled `new` theme is active and a theme save posts its custom-save action
  with a `field_options` payload carrying an unregistered slug
- **THEN** no value row is stored for that slug

### Requirement: A value submitted for a registered theme field saves

A value submitted for a registered theme field MUST save and read back.

#### Scenario: Registered slug via theme_fields saves

- **WHEN** a theme save posts a `theme_fields` payload carrying a slug registered on the
  theme scope
- **THEN** the value is stored and readable back from the theme

### Requirement: The theme settings filter applies to every role that can reach theme settings

The filter SHALL apply to every role that can reach theme settings. This includes a
non-administrator role that has the theme-settings capability.

#### Scenario: A role with the theme-settings capability and no other capability is filtered

- **WHEN** a non-administrator role that has the theme-settings capability posts a theme save with
  an unregistered slug in the `field_options` payload
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

#### Scenario: A group that nests its fields under a numeric key preserves existing values

- **WHEN** an object has stored custom-field values and a save submits a group that holds its
  fields under a numeric key
- **THEN** the request completes normally (no 500) and the object's existing values remain
  unchanged

### Requirement: A non-hash field-options payload is ignored, not fatal

The allowed-slugs permit SHALL treat a `field_options` (or sibling `theme_fields`) payload that is
not a parameter hash — a scalar or an array — as empty, saving no value rows rather than raising.
Every admin controller sharing the permit MUST NOT let an authenticated caller turn a malformed
field-options param into a 500.

#### Scenario: Scalar field_options saves nothing and does not error

- **WHEN** a save submits `field_options` as a scalar string (or an array) while the target has
  registered fields
- **THEN** no value row is stored and the request completes normally (no 500)

#### Scenario: A form renders again with a malformed field_options

- **WHEN** a save renders its form again, after a refusal or a failed validation, while the record
  has registered fields
- **AND** the save submits a `field_options`, a group or a field entry that is a scalar or a list
- **THEN** the form renders its custom fields with no submitted value, and the request completes
  normally (no 500)

### Requirement: The bundled theme's custom save answers with the standard response

The bundled `new` theme's custom-save path SHALL complete with the theme-settings form's
standard single redirect; the theme's settings hook MUST NOT issue a second response of its own.

#### Scenario: Custom save redirects once

- **WHEN** the bundled `new` theme is active and a theme save posts its custom-save action
  with a registered field value
- **THEN** the request answers with the standard redirect to the theme-settings form and the
  value is stored

### Requirement: An admin custom-field save stores only the fields its form offers

Every admin save of custom-field values SHALL accept only slugs of fields in the groups the
corresponding form renders for the record being saved. A slug registered only on another record of
the same placement class MUST NOT create a value row on the record being saved. A slug registered on
the record's own groups MUST save and read back as before.

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

### Requirement: The form groups rule covers each admin save of custom-field values

The rule of the form groups SHALL apply to each admin save of custom-field values. The saves are
site settings, theme settings (both payloads), post type, post and draft, category, post tag, user,
widget assignment and nav menu item. Another record is another post type, another site's settings,
theme or user groups, another widget or another menu.

#### Scenario: Each admin save drops the slug of another record

- **WHEN** a save of one of the listed records submits a slug that is registered only on another
  record of the same placement class
- **THEN** no value row is stored on the record being saved

### Requirement: A post or draft save accepts the post groups of its post type

For a post or draft, the groups that the permit allows SHALL be the post groups of its post type.
The groups placed on the post itself or on its categories, which the editor also renders, are not
saved this way, as before.

#### Scenario: A group placed on the post itself is outside the permit

- **WHEN** a post save submits a slug of a group that is placed on the post itself or on its
  categories
- **THEN** the permit does not accept that slug as a post group of the post type, as before

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

A save whose own field-group lookup differs from the groups of its permit SHALL resolve each
permitted slug's field among the fields of those groups. A same-slug field outside them MUST NOT
receive the value row.

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

#### Scenario: A widget assignment resolves its slug in the groups of its permit

- **WHEN** a widget assignment is saved with a permitted slug, and the own lookup of the assignment
  finds no field group
- **THEN** the value row points at the field of the groups that the permit allows

### Requirement: The lookup of a record differs from its permit for four kinds of save

The own lookup of the record differs from the groups its permit allows in four kinds of save. The
lookup of a post type returns the groups of its posts. The lookup of a post or draft adds the groups
placed on the post and its categories. The lookup of a user keys on a site id equal to the id of the
user. The lookup of a widget assignment finds none. Each of these saves SHALL resolve each permitted
slug in the groups of its permit.

#### Scenario: A save of each kind resolves in the groups of its permit

- **WHEN** a save of one of these four kinds has a permitted slug
- **AND** a field of the same slug is outside the groups of the permit
- **THEN** the value row points at the field in the groups of the permit

### Requirement: Other callers of the model save resolve slugs through the record's own lookup

Each save outside "A save resolves each slug in the groups it permits" SHALL keep resolving slugs
through the record's own lookup. An example is a call of the model save outside the admin.
Neither lookup SHALL point a row at a field group sharing the slug.

#### Scenario: A caller of the model save outside the admin saves resolves through the own lookup

- **WHEN** a caller of the model save other than an admin save stores a value
- **THEN** the slug resolves through the own lookup of the record, as before

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

The shared permit SHALL keep the values of a permitted slug in both shapes that the admin forms
submit. Most fields submit a hash keyed by index, and the checkboxes field submits a list of
scalars. A list of scalars MUST be stored in the order submitted and read back from the saved
record. A list that holds anything other than scalars MUST NOT create a value row.

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

#### Scenario: A save with a list of non-scalars is refused

- **WHEN** a save submits a registered field's values as a list of hashes
- **THEN** the save is refused, and no value row is stored for that field

### Requirement: No admin form submits a list that holds a hash

The admin JavaScript SHALL rename the inputs `values[][attr]` and `values[][value]` of the
`field_attrs` field to `values[<index>][attr]` and `values[<index>][value]` before the form submits.
So no admin form submits a list that holds a hash.

#### Scenario: The field_attrs inputs are keyed by index on submit

- **WHEN** an admin form with a `field_attrs` field submits
- **THEN** the inputs are `values[<index>][attr]` and `values[<index>][value]`, a hash keyed by
  index, and not a list that holds a hash

### Requirement: A field with a numeric slug does not remove the other fields of its group

A custom field can have a slug of digits only, such as `2020`. A group of the submitted payload that
holds such a slug SHALL keep the entry of each slug that the permit allows. The shared permit MUST
keep the entry of a numeric slug that it allows. It MUST drop the entry of a numeric key that names no
allowed field. This SHALL hold on each Rails version that Camaleon supports.

#### Scenario: A post save stores a post type field beside a numeric slug of the post itself

- **WHEN** the post itself has a field `2020`, and the post save submits that field and a post type
  field in one group
- **THEN** the value of the post type field is stored, and the save reports no error

#### Scenario: A draft save stores a post type field beside a numeric slug of the post itself

- **WHEN** the draft save of that post submits the same two fields in one group
- **THEN** the value of the post type field is stored on the draft

#### Scenario: A registered numeric slug is stored with the fields beside it

- **WHEN** the post type has the fields `2020` and `subtitle`, and a post save submits both in one
  group
- **THEN** both values are stored

#### Scenario: A numeric key that names no field is dropped

- **WHEN** a save submits a registered field and a numeric key that names no allowed field in one
  group
- **THEN** the value of the registered field is stored, and no value row is stored for the numeric
  key

### Requirement: A field entry keeps its values beside a key that the permit does not know

The shared permit SHALL keep the `id`, the group number and the values of the entry of an allowed
slug. The permit MUST drop each other key of the entry. This includes a numeric key with a hash
value, which MUST NOT remove the values of the entry.

#### Scenario: An entry with a numeric key stores its values

- **WHEN** a save submits the entry of a registered field with its values and with a numeric key that
  holds a hash
- **THEN** the values of the field are stored

### Requirement: The shared permit reports only the unknown keys of a field entry

The shared permit SHALL NOT report a group, a slug or a top-level key that it drops as an
unpermitted parameter. The post editor posts the slugs of the post itself and of its categories in
each save, and the post save drops them. The permit SHALL report an unknown key inside the entry of
an allowed slug, as the `action_on_unpermitted_parameters` setting of the host app says.

#### Scenario: A host that raises for an unpermitted parameter gets no error for a dropped slug

- **WHEN** the host app sets `action_on_unpermitted_parameters` to `:raise`
- **AND** a save submits an allowed slug and a slug outside the scope of the permit
- **AND** the save submits a top-level key that is not a group index, and a group that is a scalar
- **THEN** the permit raises no error, and its result holds only the entry of the allowed slug

#### Scenario: A host that raises for an unpermitted parameter gets an error for an unknown key of an entry

- **WHEN** the host app sets `action_on_unpermitted_parameters` to `:raise`, and a save submits the
  entry of an allowed slug with an unknown key
- **THEN** the permit raises `ActionController::UnpermittedParameters`

### Requirement: A save with field values that the permit does not keep is refused

The shared permit keeps the `values` of an allowed slug as a hash keyed by index or as a list of
scalars. A save that submits the `values` of an allowed slug in any other shape SHALL be refused.
The stored custom-field values of the record MUST stay. A list that holds a hash or a list, and a
non-empty scalar, are such shapes.

#### Scenario: A save with a list of hashes keeps the stored values

- **WHEN** a record holds values of two fields
- **AND** a save submits valid values for one field and a list of hashes as the `values` of the other
  field
- **THEN** the save answers with the refusal, and the record holds the same values of both fields
  after the save

#### Scenario: A save with a nested list or a non-empty scalar keeps the stored values

- **WHEN** a save submits a nested list or a non-empty scalar as the `values` of an allowed slug
- **THEN** the save answers with the refusal, and the stored values of the record stay

#### Scenario: A refused post save stores nothing

- **WHEN** a post save submits a new title and a list of hashes as the `values` of a post type field
- **THEN** the save answers with the refusal, and the post keeps its title and its stored values

### Requirement: A save with a field entry that is a non-empty scalar or a list is refused

A save that submits the entry of an allowed slug as a non-empty scalar or as a list SHALL be refused
in the same way.

#### Scenario: A save with a field entry that is a non-empty scalar or a list keeps the stored values

- **WHEN** a record holds values of two fields
- **AND** a save submits valid values for one field, and a non-empty scalar or a list as the entry
  of the other field
- **THEN** the save answers with the refusal, and the record holds the same values of both fields
  after the save

#### Scenario: A category create with a list as a field entry keeps the category

- **WHEN** a category create submits a list as the entry of an allowed slug
- **THEN** the save answers with the refusal, the category is stored, and it holds no custom-field
  value

### Requirement: The refusal of a field value names the slug and answers by the kind of request

The refusal SHALL answer as the requirement "A refused admin save answers by the kind of the
request" of `custom-field-value-rejection` says. The refusal SHALL name the slug of the field.

#### Scenario: An XHR gets the refusal with a 422

- **WHEN** an XHR without the `cama_ajax_request` param submits a non-empty scalar as the `values` of
  an allowed slug
- **THEN** the answer is the refusal as text with a 422, and the stored values of the record stay

#### Scenario: The refusal names the slug

- **WHEN** a save submits a list of hashes as the `values` of an allowed slug
- **THEN** the refusal names the slug of that field

### Requirement: An entry with no values is not refused

An entry with no `values`, with `nil` or with an empty `String` holds no value, and it SHALL NOT be
refused. The form submits such an entry for a checkboxes field with no option checked. The save MUST
then remove the stored values of that field, as before.

#### Scenario: A checkboxes field with no option checked is cleared

- **WHEN** a record holds values of a checkboxes field, and a save submits the entry of that field
  with no `values`
- **THEN** the save reports no error, stores the other fields, and removes the stored values of the
  checkboxes field

#### Scenario: An empty String clears the field

- **WHEN** a save submits an empty `String` as the `values` of an allowed slug
- **THEN** the save reports no error, and removes the stored values of that field

### Requirement: A host that raises for an unpermitted parameter gets the error in place of the refusal

When the host app sets `action_on_unpermitted_parameters` to `:raise`, Rails SHALL raise
`ActionController::UnpermittedParameters` for each `values` that the permit does not keep, as
before. That error comes in place of the refusal, and in place of the removal for a `values` of
`nil` or an empty `String`. The save then removes no stored value.

#### Scenario: A host that raises gets the error for each value that the permit does not keep

- **WHEN** the host app sets `action_on_unpermitted_parameters` to `:raise`
- **AND** a save submits `values` for an allowed slug that the permit does not keep
- **AND** such `values` are `nil`, an empty `String`, a list that holds a hash or a list, or a
  non-empty scalar
- **THEN** Rails raises `ActionController::UnpermittedParameters`, in place of the refusal and in
  place of the removal
- **AND** the save removes no stored value

### Requirement: The permit does not refuse an entry under a slug that it does not allow

The permit SHALL NOT refuse an entry under a slug that it does not allow. It drops that entry, as
before.

#### Scenario: An entry under a slug that the permit does not allow is dropped

- **WHEN** a save submits an entry under a slug that the permit does not allow
- **THEN** the permit drops that entry, and the save is not refused
