## ADDED Requirements

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
