## ADDED Requirements

### Requirement: A save from the editor keeps the group number of each instance

The custom-field editor SHALL submit each instance of a repeatable field group with the group number
that the instance had when the form rendered. A save that the admin makes with no drag MUST NOT move
a stored value to another group number.

#### Scenario: An instance after an instance with no value

- **WHEN** a post stores the checkboxes value `mon` only with the group number 1
- **AND** an admin saves the form of the post with no change
- **THEN** the post stores `mon` with the group number 1 and no value with the group number 0

#### Scenario: The admin adds an instance with a value after an instance with no value

- **WHEN** an admin leaves the first instance of a checkboxes field empty
- **AND** the admin adds a second instance, checks `mon` in it and saves the form two times
- **THEN** the post stores `mon` with the group number 1

### Requirement: A new instance gets the next group number

A new instance SHALL get the highest group number of the instances in the editor plus 1.

#### Scenario: The admin adds an instance to a group with a gap

- **WHEN** a post stores instances with the group numbers 1 and 3
- **AND** an admin adds an instance, types a value in it and saves the form
- **THEN** the post stores the new value with the group number 4

### Requirement: A delete keeps the group numbers of the other instances

A delete of an instance SHALL remove only that instance. The other instances MUST keep their group
numbers.

#### Scenario: The admin deletes the middle instance

- **WHEN** a post stores instances with the group numbers 0, 1 and 2
- **AND** an admin deletes the instance with the group number 1 and saves the form
- **THEN** the post stores the values of the other two instances with the group numbers 0 and 2

### Requirement: A drag gives the group numbers to the instances in their new order

After a drag, the editor SHALL give the group numbers of the group, in ascending order, to the
instances in their new order.

#### Scenario: The admin drags the last instance to the top

- **WHEN** a post stores instances with the group numbers 1 and 3
- **AND** an admin drags the instance with the group number 3 to the top and saves the form
- **THEN** the post stores the value of the dragged instance with the group number 1
- **AND** the post stores the value of the other instance with the group number 3

### Requirement: The editor numbers the instances by position without valid group numbers

The editor SHALL number the instances from 0 by their position when it gets no list of group
numbers. It SHALL also do so when the list does not hold one group number for each instance. The
group numbers MUST be Integers from 0 to 2147483647 in ascending order.

#### Scenario: A stored group number below 0

- **WHEN** a post stores a value with the group number -1 from an earlier release
- **AND** the post stores a value with the group number 1
- **AND** an admin saves the form with no change
- **THEN** the save succeeds, and the post stores the two values with the group numbers 0 and 1

### Requirement: The partial gives the group numbers of the instances

`cama_form_field_group_numbers` SHALL give one group number for each instance that
`cama_form_field_values` gives, in the same order. For a GET request it SHALL give the stored group
numbers. For a form that renders again after a failed save it SHALL give the submitted group
numbers, with nil for an invalid group number.

#### Scenario: The form of a saved post

- **WHEN** a post stores values of the group with the group numbers 1 and 3
- **AND** an admin opens the form with a GET request
- **THEN** the helper gives `[1, 3]`

#### Scenario: A form that renders again after a failed save

- **WHEN** a POST request submits instances with the group numbers `'3'`, `'1'` and `'x'`
- **THEN** the helper gives `[1, 3, nil]`
