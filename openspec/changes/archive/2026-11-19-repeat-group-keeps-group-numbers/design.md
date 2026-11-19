## Context

See `proposal.md`, "Why". `get_fields_grouped` gave the stored instances of a group as a list,
without the numbers. It sorted the values by their order first (D5). So the instances came in the
order of their group numbers only when each instance had a value with the order 0. An admin save
stores such a value.

`build_custom_field_group` built the instances from that list. Its
`update_custom_group_number` handler wrote the position of each instance into its group number,
after each add, delete and drag.

A checkbox, a checkboxes field and a radio field with no choice submit no `values` key.
`set_field_values` stores no row for them. A text field stores `''` as a row. So only an instance
whose fields all submit no value leaves a gap in the group numbers. A caller of `set_field_value`
can also store a group number with a gap, for example 5 as the only instance.

## Decisions

**D1. The editor keeps the group number of each instance.** The partial gives the editor the group
numbers of the instances. The editor writes each number into its instance. Only a drag of the admin
changes the group number of an instance.

- A new instance gets the highest group number of the group plus 1, or 0 for an empty group.
- A delete removes the instance and its group number. The other instances keep their numbers.
- A drag gives the group numbers of the group, in ascending order, to the instances in their new
  order. So the instances keep the set of numbers, and the order of the numbers follows the drag.
- An instance that stores no value shows in the editor until the save. The save stores no row for
  it, so the next form does not show it. A gap in the group numbers stays.

**D2. A new helper gives the group numbers.** `cama_form_field_group_numbers` gives the numbers in
the order of `cama_form_field_values`. A GET request reads the stored numbers. A form that renders
again after a failed save reads the submitted numbers. `cama_form_field_values` keeps its return
value, because a plugin can render the partial or call the helper.

**D3. A sixth argument of `build_custom_field_group` takes the numbers.** The argument is optional.
The editor numbers the instances by their position, as before, in these cases:

- A caller passes no numbers, for example a plugin with a copy of the old partial.
- The list of numbers does not have one number for each instance.
- A number is not an Integer from 0 to 2147483647. A stored number below 0 from an earlier release
  is an example. The save refuses such a number.
- The numbers do not ascend. Two instances of a failed save with the same number are an example.

**D4. A group that is not repeatable does not change.** Its one instance keeps the group number 0
of the partial.

**D5. `get_fields_grouped` gives its groups in ascending order of the group number.** The default
scope sorts the values by their order first. So a group with a higher order came after a higher group
number, and the editor then numbered the instances by position.

The read now sorts by the group number first, and by the order in each group. The new
`get_fields_grouped_by_number` gives the same groups with their numbers, so the partial reads both
with one query.

Alternatives:

- Store a placeholder row with `''` for each field with no value. Each unchecked checkbox of each
  form then stores a row, and `get_field_values` gives `['']` in place of `[]`. A theme that tests
  `present?` or loops over the values changes its output. Rejected.
- Show each gap in the group numbers as an empty instance, and keep the numbers by position. A
  group number that code stores, for example 2147483647, makes the editor draw that many instances.
  A limit on the gaps is arbitrary. Rejected.
- Document the behavior only. A theme loses values on a normal edit. Rejected.

The maintainer chose D1 on 2026-11-19.

## Risks / Trade-offs

- [A delete of an instance no longer moves the values of the later instances to lower group
  numbers.] → A theme that reads all instances uses `get_fields_grouped` or `the_fields_grouped`,
  and it gets the same list. A theme that reads one group number keeps its value.
- [A new instance after an instance with the group number 2147483647 gets an invalid number, and the
  save refuses it.] → Only code can store that number. The limit is intended.
