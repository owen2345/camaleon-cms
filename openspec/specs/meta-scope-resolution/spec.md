# meta-scope-resolution Specification

## Purpose
Define how a model's `object_class` scope name — the key under which its metas, custom fields,
field groups, and stored values are read and written — is derived from its class name, and keep
the widget admin surfaces agreeing with it, so refactors cannot silently strand existing rows or
reopen the write/read mismatch that broke widget custom fields.
## Requirements
### Requirement: Scopes are the demodulized class name

Every model carrying the common relationships SHALL scope its meta and custom-field rows under
its **demodulized** class name — the 2.9.2 contract all existing installs' rows were written
under: `CamaleonCms::Post` → `Post`, `CamaleonCms::Widget::Main` → `Main`, a host `Admin::User`
→ `User`. Scope names MUST NOT carry namespace qualifiers.

#### Scenario: Top-level engine class

- **WHEN** a `CamaleonCms::Post` record builds a meta row
- **THEN** the row's `object_class` is `Post`

#### Scenario: Nested engine class

- **WHEN** a `CamaleonCms::Widget::Main` record builds a meta row
- **THEN** the row's `object_class` is `Main`

#### Scenario: Namespaced host user model reads its 2.9.2 rows

- **WHEN** a host model `Admin::User` (configured as the `user_model`) builds a meta row
- **THEN** the row's `object_class` is `User`

#### Scenario: Unnamespaced host class is unchanged

- **WHEN** a top-level host model builds a meta row
- **THEN** the row's `object_class` is the class name itself

### Requirement: Widget admin surfaces agree with the scope names

The widget admin flows that reference the widget scope by string — the assigned-widget save
(allowed field slugs lookup) and the field-group caption — SHALL use the same demodulized name
the association scope produces. A field value submitted for a group placed on a widget MUST save
and read back; it MUST NOT be silently discarded by a scope-name mismatch (the 2.8.x–2.9.2
breakage).

#### Scenario: Assigned-widget field value round-trips

- **WHEN** a widget carries a field group with a field, and the admin saves an assigned-widget
  form submitting a value for that field
- **THEN** the value is stored and readable back from the assigned widget

### Requirement: User custom-field surfaces agree with the scope names

The user custom-fields flows that reference the user scope by string — the settings form's users
placement option (where new groups are stored), the user edit page's field-group read, and the
users save's allowed-slugs filter — SHALL use the demodulized user-model name the association
scope produces (`'User'` for a host `Admin::User`, for the engine-default `CamaleonCms::User`,
and for a top-level host `User`).
A field group placed on users MUST render on the user edit page and MUST have its submitted
values accepted by the save filter; values MUST NOT be silently discarded by a scope-name
mismatch between placement, read, and save.

#### Scenario: Namespaced host user model reads groups placed under the demodulized name

- **WHEN** the configured user model is namespaced (e.g. `Admin::User`) and a field group is
  placed on users under `'User'`
- **THEN** the user edit page's field-group read finds that group

#### Scenario: Users placement option emits the demodulized name

- **WHEN** the custom-fields settings form renders with a namespaced user model configured
- **THEN** the users placement option's value carries the demodulized name (`'User'`), not the
  qualified one

#### Scenario: User field value round-trips through the admin save

- **WHEN** a field group placed on users carries a field, and an administrator saves the user
  form submitting a value for that field
- **THEN** the value is stored and readable back from that user

#### Scenario: Save filter accepts values for a non-User demodulized host model

- **WHEN** the configured user model demodulizes to a name other than `'User'`, a field group
  is placed on users under that name, and an administrator submits a value for one of its
  fields
- **THEN** the value is stored and readable back from that user

### Requirement: Legacy qualified user placements are repairable

Installs that stored user field groups under a qualified user-model name (the pre-fix placement
emission) SHALL have a repair task that re-keys those group placements to the demodulized name.
The task MUST be idempotent, MUST NOT touch rows of other placement classes or the groups'
fields, and MUST be a no-op when the configured user model is not namespaced. It SHALL report
the re-keyed count, or the no-op, on standard output.

#### Scenario: Qualified group placement is re-keyed

- **WHEN** the configured user model is `Admin::User`, a group placement is stored under
  `'Admin::User'`, and the repair task runs
- **THEN** the group's placement reads `'User'` and the group is visible on the user edit page
  again

#### Scenario: Unrelated placements are untouched

- **WHEN** the repair task runs
- **THEN** groups placed on other classes and the groups' field rows keep their stored names

#### Scenario: No-op without a namespaced user model

- **WHEN** no namespaced user model is configured and the repair task runs
- **THEN** no rows change

