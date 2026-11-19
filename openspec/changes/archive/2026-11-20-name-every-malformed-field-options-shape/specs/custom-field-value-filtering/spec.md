## MODIFIED Requirements

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
