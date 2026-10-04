## ADDED Requirements

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

## MODIFIED Requirements

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
