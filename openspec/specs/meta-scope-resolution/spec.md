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

