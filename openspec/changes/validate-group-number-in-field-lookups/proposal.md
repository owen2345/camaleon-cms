# Validate the group number in the lookups of custom-field values

## Why

A custom-field value has a slug and a group number. A valid group number is nil, an Integer from 0
to 2147483647, or a String of 1 to 16 digits with such a number. Each other group number is invalid.
`set_field_value` and `set_field_values` of `CamaleonCms::CustomFieldsRead` refuse an invalid group
number (`refuse-invalid-field-group-number`). The methods that look a stored value up by its group
number did not validate it:

- `get_field_values` and `get_field_value` gave the group number to the database as it was, and the
  integer cast of Rails misread it. `'1abc'` and `true` read group 1, `false` read group 0, and
  `2.5` read group 2.
- With a loaded `custom_field_values` association, the two readers compared each row in Ruby. That
  comparison read no value for a Symbol key (`:note`), a String of digits (`'1'`) or a list of
  group numbers (`[0, 1]`). The database read the values for each of them. So one call gave two
  results, and other code that loaded the association changed the result.

## What Changes

- `get_field_values` reads no value for an invalid group number, and `get_field_value` returns its
  default. They raise no error.
- A negative Integer down to -2147483648 still reads its group. A stored value can hold such a
  number from an earlier release.
- A list (Array) reads each of its groups when each item is a valid group number or such a negative
  Integer. A list with any other item reads no value.
- With a loaded `custom_field_values` association, the two readers read the stored values that the
  database reads. This holds for a Symbol key, a String of digits, a list, and an Integer outside
  the range -2147483648 to 2147483647.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `custom-field-value-rejection`: the requirement "A custom-field value validates its group number"
  now gives the reads of `get_field_value` and `get_field_values`.

## Impact

- `app/models/concerns/camaleon_cms/custom_fields_read.rb`: `get_field_values` reads through a
  private lookup, `_cama_field_values_in_group`.
- `app/models/camaleon_cms/custom_fields_relationship.rb`: a predicate for the group numbers that
  the lookup reads.
- Specs: `spec/models/custom_field_value_group_number_spec.rb`.
- `docs/upgrading-to-2.9.5.md` tells plugin and theme developers which group numbers read values.
- Ecosystem: the change affects no surveyed consumer (`docs/ai/ecosystem.md`). Each surveyed call
  reads the default group number 0.
