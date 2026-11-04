# Read a plain Hash with String keys in set_field_values

## Why

`CamaleonCms::CustomFieldsRead#set_field_values` deletes every stored value of the record, then
stores the values of its payload. It reads each entry by Symbol keys: `values[:values]`,
`values[:group_number]` and `values[:id]`. A plain Hash with String keys, for example a `JSON.parse`
result or the sample in the comment of the method, gives nil for each read. The method then skips
each entry. The call returns with no error, deletes every stored value of the record, stores nothing
and never validates the group number. A payload with indifferent access, such as the request
parameters of an admin save, is not in this case.

## What Changes

- `set_field_values` reads a plain Hash with indifferent access, so a String key and its Symbol twin
  name the same entry. The Hash of the caller keeps its keys.
- The group number of an entry with String keys is validated, as for an entry with Symbol keys.
- No change for request parameters, or for a Hash with indifferent access.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `custom-field-value-rejection`: `set_field_values` reads its payload by String or Symbol keys, and
  validates the group number of each entry.

## Impact

- `app/models/concerns/camaleon_cms/custom_fields_read.rb` (`set_field_values`).
- Specs: a model spec with the plain Hash, the `JSON.parse` result, the group number of such an
  entry, and request parameters.
- `docs/upgrading-to-2.9.5.md` tells plugin developers that such a call now stores its values.
- Ecosystem: no surveyed consumer passes a plain Hash with String keys (`docs/ai/ecosystem.md`).
