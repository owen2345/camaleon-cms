## ADDED Requirements

### Requirement: A value row refuses a group number outside the range of the column

A custom-field value row SHALL accept a group number only when it is nil or an integer from 0 to
2147483647, given as an Integer or as a text of ASCII digits. The row MUST refuse any other group
number (a larger number, a negative number, a boolean, a text that is not digits, a file) with an
error that names the field, on each write path and on each supported database. The row SHALL NOT
change the number to a valid one. A new row is always checked. A stored row SHALL be checked only
when its group number changes. An admin save that submits a refused group number MUST NOT answer with
a 500: it SHALL redirect back with the error and leave the stored values of the record unchanged. An
absent or empty group number in an admin save SHALL mean group 0.

A group number text with a broken encoding, or in an encoding that is not ASCII-compatible, SHALL
get the same refusal on each write path. The integer cast of Rails raises its own error for that
text, and that error MUST NOT replace the refusal.

#### Scenario: A group number above the range is refused in an admin save

- **WHEN** an admin save submits a registered field with a group number above 2147483647
- **THEN** the response redirects back with an error that names the field, and the stored values of
  the record are unchanged

#### Scenario: A boolean group number is refused in an admin save

- **WHEN** an admin save with a JSON body submits `true` or `false` as a group number
- **THEN** the response redirects back with an error that names the field, and the stored values of
  the record are unchanged

#### Scenario: A negative group number or a text that is not digits is refused

- **WHEN** a save submits a group number of `-1`, `abc` or `0abc`
- **THEN** the save is refused and no value row is stored for it

#### Scenario: The largest group number is stored

- **WHEN** a save submits a group number of 2147483647
- **THEN** the value is stored under that group number

#### Scenario: A stored row with a negative group number stays writable

- **WHEN** a stored row holds a negative group number and a caller updates only its value
- **THEN** the update succeeds

#### Scenario: A group number text that the integer cast cannot read is refused

- **WHEN** `set_field_value`, `set_field_values` or a direct `custom_field_values.create!` gets a
  group number text with a broken encoding, or in an encoding that is not ASCII-compatible
- **THEN** the caller gets the refusal that names the field, and the stored values of the record
  are unchanged
