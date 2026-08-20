# meta-scope-resolution Delta — fix-namespaced-user-field-scope

## ADDED Requirements

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
