# Keep the group numbers of a repeatable field group in the editor

## Why

An admin can add a repeatable field group to a post several times. Each copy of the group is an
instance, and its values have the group number of the instance. A theme reads the values of an
instance with `get_field_values('days', 1)`.

The custom-field editor gave each instance the number of its position. An instance whose fields store
no value has no row, for example a checkboxes field with no option checked. The editor then showed
fewer instances, and the next save moved the values of a later instance to a lower group number. The
theme then read no value.

## What Changes

- The custom-fields partial gives the editor the group number of each instance that it shows.
- The editor keeps the group number of each instance. A new instance gets the highest group number
  of the group plus 1. A deleted instance takes only its own group number with it.
- A drag gives the group numbers of the group to the instances in their new order.
- The editor numbers the instances by their position, as before, when it gets no group numbers or
  invalid group numbers.

## Capabilities

### New Capabilities

- `custom-field-repeat-group-numbers`: a save from the editor keeps the group number of each instance
  of a repeatable field group.

### Modified Capabilities

None.

## Impact

- `CustomFieldsHelper`, the custom-fields partial and `build_custom_field_group` in
  `_custom_fields.js`.
- A delete of an instance no longer moves the values of the later instances to lower group numbers.
- `set_field_values` and the stored data do not change. `get_fields_grouped` gives its groups in
  ascending order of the group number. The new `get_fields_grouped_by_number` gives the same groups
  with their group numbers.
