# Name every malformed field_options shape

## Why

A scenario of `custom-field-value-filtering` names three malformed shapes of `field_options`. They
are a scalar param, a group that is not a set of fields and a field entry that is a list. The form
also renders for a list param, a list group and a scalar field entry. The request spec sends each of
these shapes on the post form and on the category form. The scenario does not name them.

## What Changes

- The scenario names each malformed shape of the param, of a group and of a field entry.
- The scenario says that the form renders its custom fields.
- No code changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `custom-field-value-filtering`: the scenario of a form that renders again names each malformed
  shape.

## Impact

- `spec/requests/security/custom_fields_form_malformed_field_options_spec.rb` holds the examples.
- No change for a host app, a plugin or a theme.
