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
