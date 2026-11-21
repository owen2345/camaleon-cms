## ADDED Requirements

### Requirement: A save with field values that the permit does not keep is refused

The shared permit keeps the `values` of an allowed slug as a hash keyed by index or as a list of
scalars. A save that submits the `values` of an allowed slug in any other shape SHALL be refused.
The stored custom-field values of the record MUST stay. A list that holds a hash or a list, and a
non-empty scalar, are such shapes.

A save that submits the entry of an allowed slug as a non-empty scalar or as a list SHALL be refused
in the same way.

The refusal SHALL answer as the requirement "A refused admin save answers by the kind of the
request" of `custom-field-value-rejection` says. The refusal SHALL name the slug of the field.

An entry with no `values`, with `nil` or with an empty `String` holds no value, and it SHALL NOT be
refused. The form submits such an entry for a checkboxes field with no option checked. The save MUST
then remove the stored values of that field, as before.

When the host app sets `action_on_unpermitted_parameters` to `:raise`, Rails SHALL raise
`ActionController::UnpermittedParameters` for each `values` that the permit does not keep, as before.
Such `values` are `nil`, an empty `String`, a list that holds a hash or a list, and a non-empty
scalar. That error comes in place of the refusal, and in place of the removal for a `values` of `nil`
or an empty `String`. The save then removes no stored value.

The permit SHALL NOT refuse an entry under a slug that it does not allow. It drops that entry, as
before.

#### Scenario: A save with a list of hashes keeps the stored values

- **WHEN** a record holds values of two fields
- **AND** a save submits valid values for one field and a list of hashes as the `values` of the other
  field
- **THEN** the save answers with the refusal, and the record holds the same values of both fields
  after the save

#### Scenario: A save with a nested list or a non-empty scalar keeps the stored values

- **WHEN** a save submits a nested list or a non-empty scalar as the `values` of an allowed slug
- **THEN** the save answers with the refusal, and the stored values of the record stay

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

#### Scenario: An XHR gets the refusal with a 422

- **WHEN** an XHR without the `cama_ajax_request` param submits a non-empty scalar as the `values` of
  an allowed slug
- **THEN** the answer is the refusal as text with a 422, and the stored values of the record stay

#### Scenario: A refused post save stores nothing

- **WHEN** a post save submits a new title and a list of hashes as the `values` of a post type field
- **THEN** the save answers with the refusal, and the post keeps its title and its stored values

#### Scenario: A checkboxes field with no option checked is cleared

- **WHEN** a record holds values of a checkboxes field, and a save submits the entry of that field
  with no `values`
- **THEN** the save reports no error, stores the other fields, and removes the stored values of the
  checkboxes field

#### Scenario: An empty String clears the field

- **WHEN** a save submits an empty `String` as the `values` of an allowed slug
- **THEN** the save reports no error, and removes the stored values of that field

## MODIFIED Requirements

### Requirement: A permitted slug's values are kept in both shapes the admin forms submit

The shared permit SHALL keep the values of a permitted slug in both shapes that the admin forms
submit. Most fields submit a hash keyed by index, and the checkboxes field submits a list of scalars.
A list of scalars MUST be stored in the order submitted and read back from the saved
record. A list holding anything other than scalars MUST NOT create a value row.

No admin form submits a list that holds a hash. The `field_attrs` field names its inputs
`values[][attr]` and `values[][value]`. The admin JavaScript renames them to `values[<index>][attr]`
and `values[<index>][value]`, a hash keyed by index, before the form submits.

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
